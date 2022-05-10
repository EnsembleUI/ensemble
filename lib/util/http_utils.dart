import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/util/utils.dart';
import 'package:yaml/yaml.dart';
import 'package:http/http.dart' as http;

class HttpUtils {

  static Future<http.Response> invokeApi(YamlMap api, DataContext eContext, {Map<String, dynamic>? inputParams}) async {

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
    if (api['body'] is YamlMap) {
      try {
        bodyPayload = eContext.eval(json.encode(api['body']));

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
    dynamic test = api['parameters'];
    if (api['parameters'] is YamlList && inputParams != null) {
      for (var param in api['parameters']) {
        if (inputParams[param] != null) {
          params[param] = inputParams[param];
        }
      }
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
      log("$method $url\nBody: $bodyPayload\nParams: "+params.toString());
    }

    dynamic body = bodyPayload ?? params;

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

    log('${response.statusCode}: ${response.body}');
    if (response.statusCode >= 200 && response.statusCode <= 299) {
      completer.complete(response);
    } else {
      completer.completeError("Unable to reach API");
    }
    return completer.future;
  }

}