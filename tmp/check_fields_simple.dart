import 'package:flutter/foundation.dart';
import 'package:mvp_odoo/services/odoo_service.dart';

void main() async {
  final odoo = OdooService.instance;
  try {
    // If fieldExists works, we can just check the core ones
    final fields = [
      'wage',
      'state',
      'contract_type_id',
      'employee_type_id',
      'pay_category_id',
      'pay_category',
    ];
    for (var f in fields) {
      final exists = await odoo.fieldExists(model: 'hr.contract', fieldName: f);
      debugPrint('FIELD $f: $exists');
    }
  } catch (e) {
    debugPrint('ERROR: $e');
  }
}
