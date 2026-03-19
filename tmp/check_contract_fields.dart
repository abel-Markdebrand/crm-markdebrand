import 'package:mvp_odoo/services/odoo_service.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final odoo = OdooService.instance;
  try {
    final fields = await odoo.callKw(
      model: 'hr.contract',
      method: 'fields_get',
      args: [],
      kwargs: {
        'attributes': ['string', 'type', 'selection'],
      },
    );
    debugPrint('FIELDS_START');
    debugPrint(fields.toString());
    debugPrint('FIELDS_END');
  } catch (e) {
    debugPrint('ERROR: $e');
  }
}
