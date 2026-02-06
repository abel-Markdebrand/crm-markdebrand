import 'package:odoo_rpc/odoo_rpc.dart';

void main() async {
  final client = OdooClient('http://147.93.40.102:8071');
  final passwords = ['admin', '123456', '123123', 'admin123', 'odoo', 'master'];

  for (var pass in passwords) {
    try {
      print("Trying password: $pass");
      await client.authenticate('testmdb', 'admin', pass);
      print("SUCCESS! Password is: $pass");

      // Proceed with search
      final res = await client.callKw({
        'model': 'ir.module.module',
        'method': 'search_read',
        'args': [],
        'kwargs': {
          'domain': [
            ['state', '=', 'installed'],
            '|',
            ['shortdesc', 'ilike', 'phone'],
            ['name', 'ilike', 'phone'],
          ],
          'fields': ['name', 'shortdesc', 'summary'],
        },
      });

      print("--- Modules matching 'phone' ---");
      for (var m in res) {
        print("Name: ${m['name']}, Desc: ${m['shortdesc']}");
      }

      return; // Exit on success
    } catch (e) {
      print("Failed with $pass");
    }
  }
}
