import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_odoo/main.dart';
import 'package:mvp_odoo/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App renders LoginScreen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'odoo_url': 'https://example.com',
      'odoo_db': 'testdb',
      'is_setup_completed': true,
    });
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
