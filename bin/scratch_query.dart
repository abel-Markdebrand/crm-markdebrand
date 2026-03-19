import 'dart:io';
import 'package:odoo_rpc/odoo_rpc.dart';

void main() async {
  final client = OdooClient('https://odoo-markdebrand.informatiquecr.com');
  try {
    await client.authenticate(
      'odoo-markdebrand',
      'abelcardenas1200@gmail.com',
      '1234',
    );

    final fields = await client.callKw({
      'model': 'hr.job',
      'method': 'fields_get',
      'args': [],
      'kwargs': {
        'attributes': ['string', 'type', 'relation'],
      },
    });

    stdout.writeln('----- HR.JOB FIELDS -----');
    if (fields is Map) {
      fields.forEach((k, v) {
        if (k.contains('type') ||
            k.contains('skil') ||
            k.contains('deg') ||
            k.contains('web') ||
            k.contains('sum') ||
            k.contains('desc')) {
          stdout.writeln('$k: ${v['string']} (${v['type']}) ${v['relation'] ?? ""}');
        }
      });
    }
  } catch (e) {
    stdout.writeln('Error: $e');
  } finally {
    client.close();
  }
}
