import 'package:flutter/widgets.dart';
import 'package:mvp_odoo/services/odoo_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  OdooService.instance.init('https://odoo-markdebrand.informatiquecr.com');
  await OdooService.instance.authenticate(
    'odoo-markdebrand',
    'abelcardenas1200@gmail.com',
    '1234',
  );

  final fields = await OdooService.instance.callKw(
    model: 'hr.job',
    method: 'fields_get',
    args: [],
    kwargs: {
      'attributes': ['string', 'type', 'relation'],
    },
  );

  debugPrint('----- HR.JOB FIELDS -----');
  if (fields is Map) {
    fields.forEach((k, v) {
      if (k.contains('type') ||
          k.contains('skil') ||
          k.contains('deg') ||
          k.contains('web') ||
          k.contains('sum') ||
          k.contains('desc')) {
        debugPrint('$k: ${v['string']} (${v['type']}) ${v['relation'] ?? ""}');
      }
    });
  }
}
