import 'dart:convert';
import 'package:http/http.dart' as http;
import 'invokablepromises.dart';
import 'invokable.dart';

class JSResponse with Invokable {
  JSResponse(this._resp);
  final http.Response _resp;

  @override
  Map<String, Function> getters() => {
        'ok': () => _resp.statusCode >= 200 && _resp.statusCode < 300,
        'status': () => _resp.statusCode,
      };

  @override
  Map<String, Function> methods() => {
        'text': () => _resp.body,
        'json': () => jsonDecode(_resp.body),
      };

  @override
  Map<String, Function> setters() => {};
}

class Fetch {
  static JSPromise fetch(dynamic input, [dynamic init]) {
    String url = input?.toString() ?? '';
    String method = 'GET';
    Map<String, String> headers = {};
    dynamic body;

    if (init is Map) {
      if (init['method'] != null) method = init['method'].toString();
      if (init['headers'] is Map) {
        headers = Map<String, String>.fromEntries((init['headers'] as Map)
            .entries
            .map((e) => MapEntry(e.key.toString(), e.value.toString())));
      }
      if (init['body'] != null) {
        body = init['body'];
        if (body is Map) {
          body = jsonEncode(body);
          headers.putIfAbsent(
              'Content-Type', () => 'application/json; charset=utf-8');
        }
      }
    }

    Future<http.Response> fut;
    switch (method.toUpperCase()) {
      case 'POST':
        fut = http.post(Uri.parse(url), headers: headers, body: body);
        break;
      case 'PUT':
        fut = http.put(Uri.parse(url), headers: headers, body: body);
        break;
      case 'PATCH':
        fut = http.patch(Uri.parse(url), headers: headers, body: body);
        break;
      case 'DELETE':
        fut = http.delete(Uri.parse(url), headers: headers, body: body);
        break;
      default:
        fut = http.get(Uri.parse(url), headers: headers);
    }

    return JSPromise.fromFuture(
        fut.then((resp) => JSResponse(resp)).catchError((e) => throw e));
  }
}
