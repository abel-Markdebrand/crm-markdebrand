import 'package:flutter/material.dart';
import 'package:mvp_odoo/services/odoo_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    OdooService.instance.init('https://odoo-markdebrand.informatiquecr.com');
    await OdooService.instance.authenticate(
      'odoo-markdebrand',
      'abelcardenas1200@gmail.com',
      '1234',
    );
    final loggedIn = true;
    debugPrint('Logged in: $loggedIn');

    if (loggedIn) {
      final fields = await OdooService.instance.callKw(
        model: 'hr.job',
        method: 'fields_get',
        args: [],
        kwargs: {
          'attributes': ['string', 'help', 'type'],
        },
      );
      debugPrint('Fields for hr.job:');
      if (fields is Map) {
        fields.forEach((k, v) {
          debugPrint('$k');
        });
      }
    }
  } catch (e) {
    debugPrint('Error: $e');
  }
}
