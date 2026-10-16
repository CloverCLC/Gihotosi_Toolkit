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

  AudioRecorder _recorder = AudioRecorder();
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
  int _session = 0;

  bool _permissionDenied = false;
  bool get permissionDenied => _permissionDenied;

  int? _lockedStringNumber;
  int? get lockedStringNumber => _lockedStringNumber;

  TunerReading? _reading;
  TunerReading? get reading => _reading;

  double? _smoothHz;
  int _octaveStreak = 0;

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
    final epoch = ++_session;
    if (!await ensurePermission()) return;
    if (epoch != _session) return;
    _running = true;
    _smoothHz = null;
    _octaveStreak = 0;
    await _openStream(epoch);
    if (epoch != _session || !_running) return;
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(milliseconds: 50), (_) {
      unawaited(_onTick());
    });
    notifyListeners();
  }

  Future<void> _openStream(int epoch) async {
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
    if (epoch != _session || !_running) {
      await _releaseMic();
      return;
    }
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
    _session++;
    _running = false;
    _tick?.cancel();
    _tick = null;
    _silenceTimer?.cancel();
    await _subscription?.cancel();
    _subscription = null;
    await _releaseMic();
    _filled = 0;
    _write = 0;
    _smoothHz = null;
    _octaveStreak = 0;
    _reading = null;
    notifyListeners();
  }

  Future<void> _releaseMic() async {
    final recorder = _recorder;
    _recorder = AudioRecorder();
    try {
      await recorder.cancel();
    } catch (_) {}
    try {
      await recorder.dispose();
    } catch (_) {}
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
      await _releaseMic();
      if (!_running) return;
      await _openStream(_session);
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

    final locked = _lockedStringNumber == null
        ? null
        : GuitarTuning.byNumber(_lockedStringNumber!);
    if (locked != null) {
      hz = GuitarTuning.foldToward(hz, locked.frequency);
    }
    if (hz < 70 || hz > 500) return;

    final stable = _smooth(hz);
    if (stable == null) return;

    final string = locked ?? GuitarTuning.nearest(stable);
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
        _smoothHz = null;
        _octaveStreak = 0;
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

  /// Tracks the measured pitch. Single-frame octave flips are ignored so the
  /// readout does not hop between a few fixed harmonics.
  double? _smooth(double hz) {
    final prev = _smoothHz;
    if (prev == null) {
      _smoothHz = hz;
      return hz;
    }
    final ratio = hz / prev;
    if (ratio > 1.4 || ratio < 1 / 1.4) {
      _octaveStreak++;
      if (_octaveStreak < 5) return prev;
      _smoothHz = hz;
      _octaveStreak = 0;
      return hz;
    }
    _octaveStreak = 0;
    final next = prev * 0.72 + hz * 0.28;
    _smoothHz = next;
    return next;
  }

  @override
  void dispose() {
    unawaited(stop());
    super.dispose();
  }
}
