import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  String url = "https://app.prismahexagon.com/jsonrpc";
  String db = "test19";
  String user = "admin";
  String apiKey = "310af0e42590d120613b006ff1144072069dc262";

  // 1. Authenticate
  stdout.writeln("Authenticating...");
  var authBody = {
    "jsonrpc": "2.0",
    "method": "call",
    "params": {
      "service": "common",
      "method": "authenticate",
      "args": [db, user, apiKey, {}],
    },
    "id": 1,
  };

  var authRes = await http.post(
    Uri.parse(url),
    headers: {"Content-Type": "application/json"},
    body: jsonEncode(authBody),
  );

  var authData = jsonDecode(authRes.body);
  var authResult = authData['result'];
  stdout.writeln("Auth Result: $authResult");
  stdout.writeln("Auth Type: ${authResult.runtimeType}");

  // We'll hardcode uid = 2 (admin) if boolean
  int uid = authResult is int ? authResult : 2;
  stdout.writeln("Calculated UID: $uid");

  // 2. Check CRM Access
  stdout.writeln("Checking CRM Access (crm.lead)...");
  var crmBody = {
    "jsonrpc": "2.0",
    "method": "call",
    "params": {
      "service": "object",
      "method": "execute_kw",
      "args": [
        db,
        uid,
        apiKey,
        "crm.lead",
        "check_access_rights",
        ["read"],
        {"raise_exception": false},
      ],
    },
    "id": 2,
  };

  var crmRes = await http.post(
    Uri.parse(url),
    headers: {"Content-Type": "application/json"},
    body: jsonEncode(crmBody),
  );

  stdout.writeln("CRM Response:");
  stdout.writeln(crmRes.body);

  exit(0);
}
