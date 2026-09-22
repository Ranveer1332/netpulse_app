import 'package:flutter_test/flutter_test.dart';
import 'package:netpulse/main.dart';

void main() {
  testWidgets('NetPulse app renders', (WidgetTester tester) async {
    await tester.pumpWidget(const NetPulseApp());
    expect(find.text('NetPulse'), findsWidgets);
  });
}
