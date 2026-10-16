import 'note.dart';

/// One string in standard guitar tuning.
class GuitarString {
  const GuitarString({
    required this.number,
    required this.noteName,
    required this.midi,
  });

  /// 1 = high E, 6 = low E.
  final int number;
  final String noteName;
  final int midi;

  double get frequency => Note.frequencyFromMidi(midi.toDouble());

  String get label => '$number 弦 $noteName';
}

/// Standard guitar tuning: E2 A2 D3 G3 B3 E4.
class GuitarTuning {
  GuitarTuning._();

  static const List<GuitarString> standard = [
    GuitarString(number: 6, noteName: 'E2', midi: 40),
    GuitarString(number: 5, noteName: 'A2', midi: 45),
    GuitarString(number: 4, noteName: 'D3', midi: 50),
    GuitarString(number: 3, noteName: 'G3', midi: 55),
    GuitarString(number: 2, noteName: 'B3', midi: 59),
    GuitarString(number: 1, noteName: 'E4', midi: 64),
  ];

  /// Guitar often rings at 2×/3× the fundamental. Prefer the octave that
  /// sits closest to an open string.
  static double preferFundamental(double hz) {
    var best = hz;
    var bestCents = _distanceToNearest(hz);
    for (final divisor in [2.0, 3.0, 4.0]) {
      final f = hz / divisor;
      if (f < 70 || f > 420) continue;
      final cents = _distanceToNearest(f);
      if (cents + 12 < bestCents) {
        best = f;
        bestCents = cents;
      }
    }
    return best;
  }

  static double _distanceToNearest(double hz) {
    var best = double.infinity;
    for (final s in standard) {
      final abs = Note.centsBetween(hz, s.frequency).abs();
      if (abs < best) best = abs;
    }
    return best;
  }

  /// Closest string to [hz] by absolute cents distance.
  static GuitarString nearest(double hz) {
    GuitarString best = standard.first;
    var bestAbs = double.infinity;
    for (final s in standard) {
      final abs = Note.centsBetween(hz, s.frequency).abs();
      if (abs < bestAbs) {
        bestAbs = abs;
        best = s;
      }
    }
    return best;
  }

  static GuitarString byNumber(int number) {
    return standard.firstWhere((s) => s.number == number);
  }
}
