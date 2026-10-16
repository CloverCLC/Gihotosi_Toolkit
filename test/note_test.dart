import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_tools/core/music/guitar_tuning.dart';
import 'package:guitar_tools/core/music/note.dart';

void main() {
  test('A4 is 440 Hz', () {
    expect(Note.frequencyFromMidi(69), closeTo(440, 0.01));
    expect(Note.nearestNoteName(440), 'A4');
  });

  test('standard low E is near 82.4 Hz', () {
    final e2 = GuitarTuning.standard.first;
    expect(e2.frequency, closeTo(82.41, 0.05));
    expect(GuitarTuning.nearest(82.4).number, 6);
  });

  test('cents zero when equal', () {
    expect(Note.centsBetween(110, 110), closeTo(0, 0.01));
  });

  test('second harmonic folds only toward the locked string', () {
    final e2 = GuitarTuning.byNumber(6).frequency;
    expect(GuitarTuning.foldToward(e2 * 2, e2), closeTo(e2, 0.2));
    final a3 = 220.0;
    expect(GuitarTuning.foldToward(a3, e2), closeTo(a3, 0.01));
  });
}
