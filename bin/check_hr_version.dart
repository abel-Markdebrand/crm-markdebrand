import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  // Use the same credentials as bin/test_fields.dart
  final url = 'https://odoo-markdebrand.informatiquecr.com/jsonrpc';
  final db = 'odoo-markdebrand';
  final username = 'abelcardenas1200@gmail.com';
  final password = '1234';

  final client = HttpClient();

  try {
    // 1. Authenticate
    final authBody = {
      'jsonrpc': '2.0',
      'method': 'call',
      'id': 1,
      'params': {
        'service': 'common',
        'method': 'authenticate',
        'args': [db, username, password, {}],
      },
    };

    final authReq = await client.postUrl(Uri.parse(url));
    authReq.headers.contentType = ContentType.json;
    authReq.write(jsonEncode(authBody));
    final authRes = await authReq.close();
    final authResBody = await utf8.decodeStream(authRes);
    final authJson = jsonDecode(authResBody);
    final uid = authJson['result'];

    if (uid == null) {
      stdout.writeln('Auth failed');
      return;
    }

    // 2. fields_get for hr.version
    final fieldsBody = {
      'jsonrpc': '2.0',
      'method': 'call',
      'id': 2,
      'params': {
        'service': 'object',
        'method': 'execute_kw',
        'args': [
          db,
          uid,
          password,
          'hr.version',
          'fields_get',
          [],
          {
            'attributes': ['string', 'type', 'relation'],
          },
        ],
      },
    };

    final fieldsReq = await client.postUrl(Uri.parse(url));
    fieldsReq.headers.contentType = ContentType.json;
    fieldsReq.write(jsonEncode(fieldsBody));
    final fieldsRes = await fieldsReq.close();
    final fieldsResBody = await utf8.decodeStream(fieldsRes);
    final fieldsJson = jsonDecode(fieldsResBody);

    final result = fieldsJson['result'];
    stdout.writeln('--- hr.version FIELDS ---');
    if (result is Map) {
      result.forEach((k, v) {
        stdout.writeln('$k: ${v['string']} (${v['type']}) ${v['relation'] ?? ""}');
      });
    } else {
      stdout.writeln('Error getting fields: ${fieldsJson['error']}');
    }
  } catch (e) {
    stderr.writeln('Error: $e');
  } finally {
    client.close();
  }
}
