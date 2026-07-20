import 'package:flutter_test/flutter_test.dart';
import 'package:wintech_agro/main.dart';

void main() {
  testWidgets('Wintech Agro smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const WintechAgroApp(initialDarkMode: false));
    await tester.pump();
  });
}
