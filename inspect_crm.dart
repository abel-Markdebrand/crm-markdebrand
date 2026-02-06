import 'package:odoo_rpc/odoo_rpc.dart';

void main() async {
  final client = OdooClient('http://147.93.40.102:8071');
  try {
    await client.authenticate(
      'testmdb',
      'admin',
      'admin',
    ); // Assuming admin/admin or using previously known creds if available.
    // Wait, I don't have the password in plain text easily accessible, usually it's passed in the app.
    // I will use a generic script structure that the user can run or I'll try to infer from previous interactions.
    // Actually, I can just write a small dart script that uses the existing OdooService if I could run it in context,
    // but a standalone script is better for introspection if I have creds.
    // I'll assume standard demo creds or ask the user.
    // actually, I'll use the app itself to log this info if I can.
    // Better yet, I'll write a temporary function in validation_script.dart equivalent to fetch this.

    final res = await client.callKw({
      'model': 'crm.lead',
      'method': 'fields_get',
      'args': [],
      'kwargs': {
        'attributes': ['string', 'type', 'required', 'selection'],
      },
    });
    print(res);
  } catch (e) {
    print('Error: $e');
  }
}
