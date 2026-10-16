import 'dart:math' as math;

/// Music helpers: frequency ↔ note name ↔ cents (A4 = 440 Hz).
class Note {
  Note._();

  static const double a4Hz = 440.0;
  static const List<String> names = [
    'C',
    'C#',
    'D',
    'D#',
    'E',
    'F',
    'F#',
    'G',
    'G#',
    'A',
    'A#',
    'B',
  ];

  /// MIDI note number for a frequency (A4 = 69).
  static double midiFromFrequency(double hz) {
    return 69 + 12 * (math.log(hz / a4Hz) / math.ln2);
  }

  static double frequencyFromMidi(double midi) {
    return a4Hz * math.pow(2, (midi - 69) / 12);
  }

  /// Cents deviation of [hz] relative to [refHz].
  static double centsBetween(double hz, double refHz) {
    if (hz <= 0 || refHz <= 0) return 0;
    return 1200 * (math.log(hz / refHz) / math.ln2);
  }

  static String nameFromMidi(int midi) {
    final name = names[midi % 12];
    final octave = (midi ~/ 12) - 1;
    return '$name$octave';
  }

  static String nearestNoteName(double hz) {
    if (hz <= 0) return '--';
    final midi = midiFromFrequency(hz).round();
    return nameFromMidi(midi);
  }
}
