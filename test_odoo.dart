import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  final url = 'https://app.prismahexagon.com/jsonrpc';
  final db = 'test19';
  final user = 'admin';
  final apiKey = '310af0e42590d120613b006ff1144072069dc262';

  try {
    final authBody = {
      "jsonrpc": "2.0",
      "method": "call",
      "params": {
        "service": "common",
        "method": "authenticate",
        "args": [db, user, apiKey, {}],
      },
      "id": 1,
    };

    final authRes = await http.post(
      Uri.parse(url),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(authBody),
    );
    final authDecoded = jsonDecode(authRes.body);
    final uid = authDecoded['result'];
    stdout.writeln('Authenticated UID: $uid');

    final fieldsBody = {
      "jsonrpc": "2.0",
      "method": "call",
      "params": {
        "service": "object",
        "method": "execute_kw",
        "args": [
          db,
          uid,
          apiKey,
          'project.task',
          'fields_get',
          [],
          {
            'attributes': ['string', 'type'],
          },
        ],
      },
      "id": 2,
    };

    final fieldsRes = await http.post(
      Uri.parse(url),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(fieldsBody),
    );
    final fieldsDecoded = jsonDecode(fieldsRes.body);
    final f = fieldsDecoded['result'] as Map<String, dynamic>;

    for (var key in f.keys) {
      final name = key.toString().toLowerCase();
      final string = f[key]['string']?.toString().toLowerCase() ?? '';
      if (name.contains('user') ||
          name.contains('assign') ||
          string.contains('user') ||
          string.contains('assign')) {
        stdout.writeln('Field: $key -> ${f[key]["string"]} (${f[key]["type"]})');
      }
    }

    final tasksBody = {
      "jsonrpc": "2.0",
      "method": "call",
      "params": {
        "service": "object",
        "method": "execute_kw",
        "args": [
          db,
          uid,
          apiKey,
          'project.task',
          'search_read',
          [[]],
          {'limit': 5, 'order': 'id desc'},
        ],
      },
      "id": 3,
    };

    final tasksRes = await http.post(
      Uri.parse(url),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(tasksBody),
    );
    final tasksDecoded = jsonDecode(tasksRes.body);
    final tasks = tasksDecoded['result'] as List<dynamic>;

    for (var t in tasks) {
      stdout.writeln('Task ID: ${t["id"]} - ${t["name"]}');
      for (var key in f.keys) {
        final name = key.toString().toLowerCase();
        if (name.contains('user') || name.contains('assign')) {
          stdout.writeln('  $key: ${t[key]}');
        }
      }
    }
  } catch (e) {
    stderr.writeln(e);
  }
}
