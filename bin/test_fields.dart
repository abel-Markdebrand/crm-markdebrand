import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final url = 'https://odoo-markdebrand.informatiquecr.com/jsonrpc';
  final db = 'odoo-markdebrand';
  final username = 'abelcardenas1200@gmail.com';
  final password = '1234';

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

  final client = HttpClient();

  try {
    final authReq = await client.postUrl(Uri.parse(url));
    authReq.headers.contentType = ContentType.json;
    authReq.write(jsonEncode(authBody));
    final authRes = await authReq.close();

    final authResBody = await utf8.decodeStream(authRes);
    final authJson = jsonDecode(authResBody);

    final uid = authJson['result'];
    stdout.writeln('UID: $uid');

    if (uid == null) {
      stdout.writeln('Auth failed');
      return;
    }

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
          'hr.job',
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
    stdout.writeln('--- hr.job FIELDS ---');
    if (result is Map) {
      result.forEach((k, v) {
        if (k.contains('appli') ||
            k.contains('count') ||
            k.contains('emp') ||
            k.contains('user') ||
            k.contains('alias') ||
            k.contains('recruit') ||
            k.contains('interv')) {
          stdout.writeln('$k: ${v['string']} (${v['type']}) ${v['relation'] ?? ""}');
        }
      });
    } else {
      stdout.writeln('Error getting fields: ${fieldsJson['error']}');
    }
  } finally {
    client.close();
  }
}
