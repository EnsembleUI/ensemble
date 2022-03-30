import 'dart:convert';
import 'dart:async';
import 'package:ensemble/ensemble.dart';
import 'package:yaml/yaml.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

abstract class DefinitionProvider {
  Future<YamlMap> getDefinition();
}

class LocalDefinitionProvider extends DefinitionProvider {
  LocalDefinitionProvider(this.path, this.pageName);
  final String path;
  final String pageName;

  @override
  Future<YamlMap> getDefinition() async {
    String formattedPath = path.endsWith('/') ? path : path + '/';
    var pageStr = await rootBundle.loadString('$formattedPath$pageName.yaml', cache: false);
    return loadYaml(pageStr);
  }
}



class RemoteDefinitionProvider extends DefinitionProvider {
  RemoteDefinitionProvider(this.path, this.pageName);
  final String path;
  final String pageName;

  @override
  Future<YamlMap> getDefinition() async {
    String formattedPath = path.endsWith('/') ? path : path + '/';
    Completer<YamlMap> completer = Completer();
    http.Response response = await http.get(
        Uri.parse('$formattedPath$pageName.yaml'));
    if (response.statusCode == 200) {
      completer.complete(loadYaml(response.body));
    } else {
      completer.completeError("Error processing page");
    }
    return completer.future;
  }
}

class EnsembleDefinitionProvider extends DefinitionProvider {
  EnsembleDefinitionProvider(this.appKey, this.pageId);
  final String appKey;
  final String pageId;

  @override
  Future<YamlMap> getDefinition() async {
    Completer<YamlMap> completer = Completer();
    http.Response response = await http.get(
        Uri.parse('https://pz0mwfkp5m.execute-api.us-east-1.amazonaws.com/dev/app'));
    if (response.statusCode == 200) {
      Map<String, dynamic> result = json.decode(response.body);
      if (result[appKey] != null
          && result[appKey]['screens'] is List
          && (result[appKey]['screens'] as List).isNotEmpty) {
        List<dynamic> screens = result[appKey]['screens'];
        if (pageId != Ensemble.MY_APP_PLACEHOLDER_PAGE) {
          for (dynamic screen in screens) {
            if (screen['id'] == pageId || screen['name'] == pageId) {
              completer.complete(loadYaml(screen['content']));
              return completer.future;
            }
          }
        }
        // return first page as default if pageName is not specified or not found
        completer.complete(loadYaml(screens[0]['content']));
        return completer.future;
      }
    }
    // error
    completer.completeError("Error processing page");
    return completer.future;
  }

}




class ConfigError extends Error {
  ConfigError(this.message);
  final String message;

  @override
  String toString() => 'Config Error: $message';
}