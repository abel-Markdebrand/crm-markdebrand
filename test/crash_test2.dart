import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_odoo/main.dart';
import 'package:mvp_odoo/screens/setup_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App renders SetupScreen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(find.byType(SetupScreen), findsOneWidget);
  });
}
