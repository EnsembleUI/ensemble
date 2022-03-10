import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:ensemble/util/utils.dart';
import 'package:yaml/yaml.dart';
import 'package:http/http.dart' as http;

class HttpUtils {

  static Future<Map<String, dynamic>> invokeApi(YamlMap api, {Map<String, dynamic>? dataMap}) async {
    // process parameter expressions
    Map<String, dynamic> params = {};
    if (api['parameters'] is YamlMap) {
      (api['parameters'] as YamlMap).forEach((key, value) {
        if (value != null) {
          params[key.toString()] = Utils.evalExpression(value, dataMap);
        }
      });
    }

    String url = Utils.evalExpression(api['uri'].toString(), dataMap);
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
      log("POST $url\nParams: " + params.toString());
    }

    Completer<Map<String, dynamic>> completer = Completer();
    final response = await (!isPost ?
    http.get(Uri.parse(url)) :
    http.post(Uri.parse(url), body: params));

    if (response.statusCode == 200) {
      // TODO: what if result is an Array json
      Map<String, dynamic> result = json.decode(response.body);
      completer.complete(result);
    } else {
      completer.completeError("Unable to reach API");
    }
    return completer.future;
  }

}