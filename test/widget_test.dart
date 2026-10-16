import 'package:flutter_test/flutter_test.dart';
import 'package:guitar_tools/app.dart';

void main() {
  testWidgets('app shows tuner tab', (tester) async {
    await tester.pumpWidget(const GuitarToolsApp());
    expect(find.text('吉他调音器'), findsOneWidget);
    expect(find.text('调音器'), findsOneWidget);
  });
}
