import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/util/utils.dart';
import 'package:yaml/yaml.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' as foundation;

class HttpUtils {

  static Future<http.Response> invokeApi(YamlMap api, DataContext eContext) async {
    // headers
    Map<String, String> headers = {};
    if (api['headers'] is YamlMap) {
      (api['headers'] as YamlMap).forEach((key, value) {
        if (value != null) {
          headers[key.toString()] = eContext.eval(value);
        }
      });
    }
    // Support JSON (or Yaml) body only.
    // Here it's converted to YAML already
    String? bodyPayload;
    if (api['body'] != null) {
      try {
        bodyPayload = json.encode(eContext.eval(api['body']));

        // set Content-Type as json but don't override user's value if exists
        if (headers['Content-Type'] == null) {
          headers['Content-Type'] = 'application/json';
        }
      } on FormatException catch (_, e) {
        log("Only JSON data supported: " + e.toString());
      }
    }

    // query parameter
    Map<String, dynamic> params = {};
    if (api['parameters'] is YamlMap) {
      api['parameters'].forEach((key, value) {
        params[key] = eContext.eval(value) ?? '';
      });
    }

    String url = eContext.eval(api['uri'].toString());
    String method = api['method']?.toString().toUpperCase() ?? 'GET';

    // params should be appended to the URL for GET and DELETE
    if (method == 'GET' || method == 'DELETE') {
      if (params.isNotEmpty) {
        StringBuffer urlParams = StringBuffer(url.contains('?') ? '' : '?');
        params.forEach((key, value) {
          urlParams.write('&$key=$value');
        });
        url += urlParams.toString();
      }
      log("$method $url");
    } else {
      log("$method $url");
      //log("$method $url\nBody: $bodyPayload\nParams: "+params.toString());
    }

    dynamic body = bodyPayload ?? params;
    if (foundation.kDebugMode) {
      log("Body(debug only): $body");
    }

    Completer<http.Response> completer = Completer();
    http.Response? response;
    switch (method) {
      case 'POST':
        response = await http.post(Uri.parse(url), headers: headers, body: body);
        break;
      case 'PUT':
        response = await http.put(Uri.parse(url), headers: headers, body: body);
        break;
      case 'PATCH':
        response = await http.patch(Uri.parse(url), headers: headers, body: body);
        break;
      case 'DELETE':
        response = await http.delete(Uri.parse(url), headers: headers);
        break;
      case 'GET':
      default:
        response = await http.get(Uri.parse(url), headers: headers);
        break;
    }

    log('Response: ${response.statusCode}');
    if (response.statusCode >= 200 && response.statusCode <= 299) {
      completer.complete(response);
      if (foundation.kDebugMode) {
        //log("Response(debug only): ${response.body}");
      }
    } else {
      completer.completeError("Unable to reach API");
    }
    return completer.future;
  }

}

/// a wrapper class around the http Response
class Response {
  Map<String, dynamic>? body;
  Map<String, String>? headers;

  Response(http.Response response) {
    try {
      body = json.decode(response.body);
    } on FormatException catch (_, e) {
      log('Warning - Only JSON response is supported');
    }
    headers = response.headers;
  }
}