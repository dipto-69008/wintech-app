import 'package:flutter_test/flutter_test.dart';
import 'package:orient_app/main.dart';

void main() {
  testWidgets('Orient ERP smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const OrientErpApp(initialDarkMode: false));
    await tester.pump();
  });
}
