import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Basic metronome with BPM, time signature, and accented first beat.
class MetronomeEngine extends ChangeNotifier {
  MetronomeEngine();

  static const _strongAsset = 'sounds/click_strong.wav';
  static const _weakAsset = 'sounds/click_weak.wav';

  /// Rotate players so a beat never waits for the previous click to finish.
  final List<AudioPlayer> _players = [];
  int _playerIndex = 0;

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
    // 强制外放 + 媒体音量，避免小米把声音路由到听筒（几乎听不见）
    android: const AudioContextAndroid(
      isSpeakerphoneOn: true,
      stayAwake: false,
      contentType: AndroidContentType.music,
      usageType: AndroidUsageType.media,
      audioFocus: AndroidAudioFocus.gainTransientMayDuck,
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

      for (var i = 0; i < 4; i++) {
        final p = AudioPlayer(playerId: 'metro_$i');
        await p.setAudioContext(_audioContext);
        // mediaPlayer 对 Asset WAV 更稳；lowLatency 在部分小米机上会没声
        await p.setPlayerMode(PlayerMode.mediaPlayer);
        await p.setReleaseMode(ReleaseMode.stop);
        _players.add(p);
      }

      _ready = true;
      _lastError = null;
      notifyListeners();
    } catch (e, st) {
      _lastError = e.toString();
      debugPrint('Metronome init failed: $e\n$st');
      notifyListeners();
      rethrow;
    }
  }

  void setBpm(int value) {
    _bpm = value.clamp(40, 208);
    if (_running) {
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
    if (!_ready) {
      await init();
    }
    _running = true;
    _beatIndex = 0;
    _currentBeat = 0;
    _clock
      ..reset()
      ..start();
    _nextBeatUs = 0;
    notifyListeners();
    _onDeadline();
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _clock.stop();
    _running = false;
    _beatIndex = 0;
    _currentBeat = 0;
    for (final p in _players) {
      unawaited(p.stop());
    }
    notifyListeners();
  }

  int get _intervalUs => (60 * 1000000 / _bpm).round();

  void _armTimer() {
    _timer?.cancel();
    if (!_running) return;
    final delayUs = _nextBeatUs - _clock.elapsedMicroseconds;
    if (delayUs <= 0) {
      scheduleMicrotask(_onDeadline);
      return;
    }
    _timer = Timer(Duration(microseconds: delayUs), _onDeadline);
  }

  void _onDeadline() {
    if (!_running) return;

    final now = _clock.elapsedMicroseconds;
    final interval = _intervalUs;

    var skipped = 0;
    while (_nextBeatUs + interval <= now) {
      _nextBeatUs += interval;
      _beatIndex = (_beatIndex + 1) % _beatsPerBar;
      skipped++;
      if (skipped > 8) break;
    }

    final isStrong = _beatIndex == 0;
    _currentBeat = _beatIndex + 1;
    _beatIndex = (_beatIndex + 1) % _beatsPerBar;
    _nextBeatUs += interval;
    _tick++;
    notifyListeners();

    unawaited(_playClick(isStrong));
    _armTimer();
  }

  Future<void> _playClick(bool strong) async {
    if (_players.isEmpty) return;
    final player = _players[_playerIndex % _players.length];
    _playerIndex++;
    final asset = strong ? _strongAsset : _weakAsset;
    final volume = strong ? 1.0 : 0.8;
    try {
      await player.stop();
      await player.play(AssetSource(asset), volume: volume, ctx: _audioContext);
    } catch (e) {
      _lastError = e.toString();
      debugPrint('Metronome click failed: $e');
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final p in _players) {
      p.dispose();
    }
    _players.clear();
    super.dispose();
  }
}
