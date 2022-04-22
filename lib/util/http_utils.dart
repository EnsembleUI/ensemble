import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:ensemble/framework/context.dart';
import 'package:ensemble/util/utils.dart';
import 'package:yaml/yaml.dart';
import 'package:http/http.dart' as http;

class HttpUtils {

  static Future<http.Response> invokeApi(YamlMap api, {EnsembleContext? eContext}) async {
    // headers
    Map<String, String> headers = {};
    if (api['headers'] is YamlMap) {
      for (String key  in api['headers'].keys) {
        String? value = api['headers'][key];
        if (value != null) {
          headers[key] = await eContext?.eval(value);
        }
      }
      /*
      await api['headers'].forEach((key, value) async {
        if (value != null) {
          headers[key.toString()] = await eContext?.eval(value);
        }
      });*/
    }
    // for now support body as JSON (or Yaml) only
    // here it's converted to YAML already
    String? bodyPayload;
    if (api['body'] is YamlMap) {
      String rawPayload = json.encode(api['body']);
      bodyPayload = eContext != null ? await eContext.eval(rawPayload) :  rawPayload;
      // set Content-Type as json but don't override user's value if exists
      if (headers['Content-Type'] == null) {
        headers['Content-Type'] = 'application/json';
      }
    }
    // process parameter expressions
    Map<String, dynamic> params = {};
    if (api['parameters'] is YamlMap) {
      (api['parameters'] as YamlMap).forEach((key, value) {
        if (value != null) {
          params[key.toString()] = eContext?.eval(value) ?? value;
        }
      });
    }

    String url = await eContext?.eval(api['uri'].toString()) ?? api['uri'].toString();
    bool isPost = api['method'] == 'POST';

    // GET
    if (!isPost) {
      if (params.isNotEmpty) {
        String urlParams = '?';
        params.forEach((key, value) {
          urlParams += "&$key=$value";
        });
        url += urlParams;
      }
      log("GET $url");
    } else {
      log("POST $url\nBody: $bodyPayload\nParams: "+params.toString());
    }

    Completer<http.Response> completer = Completer();
    final http.Response response = await (!isPost ?
      http.get(Uri.parse(url), headers: headers) :
      http.post(Uri.parse(url), headers: headers, body: bodyPayload ?? params));

    if (response.statusCode == 200) {
      completer.complete(response);
    } else {
      completer.completeError("Unable to reach API");
    }
    return completer.future;
  }

}