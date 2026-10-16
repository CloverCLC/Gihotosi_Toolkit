import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Basic metronome with BPM, time signature, and accented first beat.
class MetronomeEngine extends ChangeNotifier {
  MetronomeEngine();

  static const _strongAsset = 'sounds/click_strong.wav';
  static const _weakAsset = 'sounds/click_weak.wav';

  final List<AudioPlayer> _strong = [];
  final List<AudioPlayer> _weak = [];
  int _strongIndex = 0;
  int _weakIndex = 0;

  int _bpm = 100;
  int get bpm => _bpm;

  int _beatsPerBar = 4;
  int get beatsPerBar => _beatsPerBar;

  bool _running = false;
  bool get running => _running;

  int _currentBeat = 0;
  int get currentBeat => _currentBeat;

  int _beatIndex = 0;
  int _tick = 0;
  int get tick => _tick;

  Timer? _timer;
  final Stopwatch _clock = Stopwatch();
  int _nextBeatUs = 0;

  bool _ready = false;
  bool get ready => _ready;
  String? _lastError;
  String? get lastError => _lastError;

  static final AudioContext _audioContext = AudioContext(
    android: const AudioContextAndroid(
      isSpeakerphoneOn: true,
      stayAwake: false,
      contentType: AndroidContentType.music,
      usageType: AndroidUsageType.media,
      audioFocus: AndroidAudioFocus.gain,
    ),
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.playback,
      options: const {AVAudioSessionOptions.mixWithOthers},
    ),
  );

  Future<void> init() async {
    if (_ready) return;
    try {
      await AudioPlayer.global.setAudioContext(_audioContext);
      await _preparePool(_strong, _strongAsset, 1);
      await _preparePool(_weak, _weakAsset, 0.8);
      _ready = true;
      _lastError = null;
      notifyListeners();
    } catch (e, st) {
      _lastError = e.toString();
      debugPrint('Metronome init failed: $e\n$st');
      notifyListeners();
    }
  }

  Future<void> _preparePool(
    List<AudioPlayer> pool,
    String asset,
    double volume,
  ) async {
    for (var i = 0; i < 6; i++) {
      final player = AudioPlayer();
      await player.setAudioContext(_audioContext);
      // SoundPool：触发开销小且稳定。高速下 MediaPlayer 的 seek 延迟会忽长忽短。
      await player.setPlayerMode(PlayerMode.lowLatency);
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setVolume(volume);
      await player.setSource(AssetSource(asset));
      pool.add(player);
    }
  }

  void setBpm(int value) {
    _bpm = value.clamp(20, 250);
    if (_running) {
      _nextBeatUs = _clock.elapsedMicroseconds + _intervalUs;
      _armTimer();
    }
    notifyListeners();
  }

  void setBeatsPerBar(int value) {
    if (value != 2 && value != 3 && value != 4) return;
    _beatsPerBar = value;
    _beatIndex = 0;
    _currentBeat = 0;
    notifyListeners();
  }

  Future<void> start() async {
    if (_running) return;
    if (!_ready) await init();
    if (!_ready) return;
    _running = true;
    _beatIndex = 0;
    _currentBeat = 0;
    _clock
      ..reset()
      ..start();
    _nextBeatUs = 0;
    notifyListeners();
    _onTick();
    _armTimer();
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _clock.stop();
    _running = false;
    _beatIndex = 0;
    _currentBeat = 0;
    for (final player in [..._strong, ..._weak]) {
      unawaited(player.stop());
    }
    notifyListeners();
  }

  int get _intervalUs => (60 * 1000000 / _bpm).round();

  void _armTimer() {
    _timer?.cancel();
    if (!_running) return;
    // 4ms 轮询比单次 Timer 在高 BPM 下更稳，触发误差被限制在几毫秒内。
    _timer = Timer.periodic(const Duration(milliseconds: 4), (_) => _onTick());
  }

  void _onTick() {
    if (!_running) return;
    final now = _clock.elapsedMicroseconds;
    if (now < _nextBeatUs) return;

    final interval = _intervalUs;
    while (now >= _nextBeatUs + interval) {
      _nextBeatUs += interval;
      _beatIndex = (_beatIndex + 1) % _beatsPerBar;
    }

    final isStrong = _beatIndex == 0;
    _currentBeat = _beatIndex + 1;
    _beatIndex = (_beatIndex + 1) % _beatsPerBar;
    _nextBeatUs += interval;

    unawaited(_playClick(isStrong));
    _tick++;
    notifyListeners();
  }

  Future<void> _playClick(bool strong) async {
    final pool = strong ? _strong : _weak;
    if (pool.isEmpty) return;
    final index = strong ? _strongIndex++ : _weakIndex++;
    final player = pool[index % pool.length];
    try {
      // lowLatency 不支持任意 seek。stop 清掉上一次播放，resume 立刻重触发。
      await player.stop();
      await player.resume();
      if (_lastError != null) {
        _lastError = null;
        notifyListeners();
      }
    } catch (e) {
      _lastError = e.toString();
      debugPrint('Metronome click failed: $e');
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final player in [..._strong, ..._weak]) {
      player.dispose();
    }
    _strong.clear();
    _weak.clear();
    super.dispose();
  }
}
