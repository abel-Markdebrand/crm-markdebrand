import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mvp_odoo/services/odoo_service.dart';

void main() {
  test('Fetch hr.job fields', () async {
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

    stdout.writeln('----- HR.JOB FIELDS -----');
    if (fields is Map) {
      fields.forEach((k, v) {
        stdout.writeln('$k: ${v['string']} (${v['type']}) ${v['relation'] ?? ""}');
      });
    }
  });
}
