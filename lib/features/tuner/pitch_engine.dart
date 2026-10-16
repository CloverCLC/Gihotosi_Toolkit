import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pitch_detector_dart/pitch_detector.dart';
import 'package:record/record.dart';

import '../../core/music/guitar_tuning.dart';
import '../../core/music/note.dart';

/// Live pitch reading mapped to a guitar string.
class TunerReading {
  const TunerReading({
    required this.frequency,
    required this.string,
    required this.cents,
    required this.inTune,
  });

  final double frequency;
  final GuitarString string;
  final double cents;
  final bool inTune;
}

/// Captures mic PCM and runs YIN pitch detection.
class PitchEngine extends ChangeNotifier {
  PitchEngine();

  static const int _sampleRate = 48000;

  /// 85 ms @ 48 kHz, then halved to 24 kHz so low E still fits in YIN
  /// without blocking the UI on a 4096-sample search.
  static const int _windowSamples = 4096;
  static const int _analysisRate = 24000;
  static const int _analysisSamples = _windowSamples ~/ 2;
  static const double _minRms = 0.004;
  static const double _inTuneCents = 5.0;

  final AudioRecorder _recorder = AudioRecorder();
  final PitchDetector _detector = PitchDetector(
    audioSampleRate: _analysisRate.toDouble(),
    bufferSize: _analysisSamples,
  );

  /// One second ring. The mic callback only writes here and returns.
  final Float32List _ring = Float32List(48000);
  int _write = 0;
  int _filled = 0;

  StreamSubscription<Uint8List>? _subscription;
  Timer? _tick;
  Timer? _silenceTimer;
  bool _detecting = false;
  DateTime _lastPcm = DateTime.fromMillisecondsSinceEpoch(0);
  bool _restarting = false;

  bool _running = false;
  bool get running => _running;

  bool _permissionDenied = false;
  bool get permissionDenied => _permissionDenied;

  int? _lockedStringNumber;
  int? get lockedStringNumber => _lockedStringNumber;

  TunerReading? _reading;
  TunerReading? get reading => _reading;

  final List<double> _recentHz = [];

  void setLockedString(int? number) {
    _lockedStringNumber = number;
    notifyListeners();
  }

  Future<bool> ensurePermission() async {
    var status = await Permission.microphone.status;
    if (status.isGranted) {
      _permissionDenied = false;
      return true;
    }
    status = await Permission.microphone.request();
    if (status.isGranted) {
      _permissionDenied = false;
      return true;
    }
    _permissionDenied = true;
    notifyListeners();
    return false;
  }

  Future<void> start() async {
    if (_running) return;
    if (!await ensurePermission()) return;
    await _openStream();
    _running = true;
    _recentHz.clear();
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(milliseconds: 50), (_) {
      unawaited(_onTick());
    });
    notifyListeners();
  }

  Future<void> _openStream() async {
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _sampleRate,
        numChannels: 1,
        autoGain: false,
        echoCancel: false,
        noiseSuppress: false,
        streamBufferSize: 2048,
      ),
    );
    _write = 0;
    _filled = 0;
    _lastPcm = DateTime.now();
    _subscription = stream.listen(
      _appendPcm,
      onError: (_) {
        unawaited(_recoverStream());
      },
    );
  }

  Future<void> stop() async {
    _tick?.cancel();
    _tick = null;
    _silenceTimer?.cancel();
    await _subscription?.cancel();
    _subscription = null;
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
    _filled = 0;
    _write = 0;
    _recentHz.clear();
    _running = false;
    _reading = null;
    notifyListeners();
  }

  void _appendPcm(Uint8List chunk) {
    if (chunk.length < 2) return;
    final data = ByteData.sublistView(chunk);
    final n = chunk.length ~/ 2;
    for (var i = 0; i < n; i++) {
      _ring[_write] = data.getInt16(i * 2, Endian.little) / 32768.0;
      _write++;
      if (_write == _ring.length) _write = 0;
    }
    _filled = math.min(_ring.length, _filled + n);
    _lastPcm = DateTime.now();
  }

  Future<void> _onTick() async {
    if (!_running || _detecting) return;
    if (DateTime.now().difference(_lastPcm) > const Duration(seconds: 2)) {
      await _recoverStream();
      return;
    }
    if (_filled < _windowSamples) return;

    final frame = _latestDecimated();
    _detecting = true;
    try {
      await _detect(frame);
    } finally {
      _detecting = false;
    }
  }

  Future<void> _recoverStream() async {
    if (!_running || _restarting) return;
    _restarting = true;
    try {
      await _subscription?.cancel();
      _subscription = null;
      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }
      await _openStream();
    } catch (e) {
      debugPrint('tuner stream restart failed: $e');
    } finally {
      _restarting = false;
    }
  }

  List<double> _latestDecimated() {
    final start = (_write - _windowSamples + _ring.length) % _ring.length;
    final out = List<double>.filled(_analysisSamples, 0);
    var sum = 0.0;
    for (var i = 0; i < _analysisSamples; i++) {
      final a = _ring[(start + i * 2) % _ring.length];
      final b = _ring[(start + i * 2 + 1) % _ring.length];
      final s = (a + b) * 0.5;
      out[i] = s;
      sum += s;
    }
    final mean = sum / out.length;
    for (var i = 0; i < out.length; i++) {
      out[i] -= mean;
    }
    return out;
  }

  Future<void> _detect(List<double> floats) async {
    final rms = _rms(floats);
    if (rms < _minRms) {
      _armSilenceClear();
      return;
    }

    final result = await _detector.getPitchFromFloatBuffer(floats);
    final minProb = result.pitch > 0 && result.pitch < 140 ? 0.55 : 0.7;
    if (!result.pitched || result.probability < minProb) {
      _armSilenceClear();
      return;
    }

    var hz = result.pitch;
    if (hz < 55 || hz > 1400) return;
    hz = GuitarTuning.preferFundamental(hz);
    if (hz < 70 || hz > 450) return;

    if (_recentHz.isNotEmpty && (hz - _recentHz.last).abs() / _recentHz.last > 0.08) {
      _recentHz.clear();
    }
    _recentHz.add(hz);
    if (_recentHz.length > 3) _recentHz.removeAt(0);
    final stable = _median(_recentHz);

    final string = _lockedStringNumber != null
        ? GuitarTuning.byNumber(_lockedStringNumber!)
        : GuitarTuning.nearest(stable);
    final cents = Note.centsBetween(stable, string.frequency);

    _silenceTimer?.cancel();
    _silenceTimer = null;
    _reading = TunerReading(
      frequency: stable,
      string: string,
      cents: cents,
      inTune: cents.abs() <= _inTuneCents,
    );
    notifyListeners();
  }

  void _armSilenceClear() {
    _silenceTimer ??= Timer(const Duration(milliseconds: 450), () {
      _silenceTimer = null;
      if (_reading != null) {
        _reading = null;
        _recentHz.clear();
        notifyListeners();
      }
    });
  }

  static double _rms(List<double> samples) {
    var sum = 0.0;
    for (final s in samples) {
      sum += s * s;
    }
    return math.sqrt(sum / samples.length);
  }

  static double _median(List<double> values) {
    final sorted = List<double>.from(values)..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid];
    return (sorted[mid - 1] + sorted[mid]) / 2;
  }

  @override
  void dispose() {
    unawaited(stop());
    _recorder.dispose();
    super.dispose();
  }
}
