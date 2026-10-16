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

  /// If [hz] is the 2nd or 3rd harmonic of [targetHz], return the fundamental.
  /// Otherwise keep the measured pitch. Does not snap to other strings.
  static double foldToward(double hz, double targetHz) {
    var best = hz;
    var bestCents = Note.centsBetween(hz, targetHz).abs();
    for (final divisor in [2.0, 3.0]) {
      final f = hz / divisor;
      if (f < 60) continue;
      final cents = Note.centsBetween(f, targetHz).abs();
      if (cents <= 30 && cents < bestCents) {
        best = f;
        bestCents = cents;
      }
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
