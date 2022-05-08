import 'dart:convert';
import 'dart:async';
import 'package:ensemble/ensemble.dart';
import 'package:yaml/yaml.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

abstract class DefinitionProvider {
  Future<YamlMap> getDefinition(String pageId);
}

class LocalDefinitionProvider extends DefinitionProvider {
  LocalDefinitionProvider(this.path);
  final String path;

  @override
  Future<YamlMap> getDefinition(String pageId) async {
    String formattedPath = path.endsWith('/') ? path : path + '/';
    var pageStr = await rootBundle.loadString('$formattedPath$pageId.yaml', cache: false);
    return loadYaml(pageStr);
  }
}



class RemoteDefinitionProvider extends DefinitionProvider {
  // TODO: we can fetch the whole App bundle here
  RemoteDefinitionProvider(this.path);
  final String path;

  @override
  Future<YamlMap> getDefinition(String pageId) async {
    String formattedPath = path.endsWith('/') ? path : path + '/';
    Completer<YamlMap> completer = Completer();
    http.Response response = await http.get(
        Uri.parse('$formattedPath$pageId.yaml'));
    if (response.statusCode == 200) {
      completer.complete(loadYaml(response.body));
    } else {
      completer.completeError("Error processing page");
    }
    return completer.future;
  }
}

class EnsembleDefinitionProvider extends DefinitionProvider {
  EnsembleDefinitionProvider(this.appKey);
  final String appKey;

  @override
  Future<YamlMap> getDefinition(String pageId) async {
    Completer<YamlMap> completer = Completer();
    http.Response response = await http.get(
        Uri.parse('https://pz0mwfkp5m.execute-api.us-east-1.amazonaws.com/dev/app?id=$appKey'));
    if (response.statusCode == 200) {
      Map<String, dynamic> result = json.decode(response.body);
      if (result[appKey] != null
          && result[appKey]['screens'] is List
          && (result[appKey]['screens'] as List).isNotEmpty) {
        List<dynamic> screens = result[appKey]['screens'];

        for (dynamic screen in screens) {
          // if loading App without specifying page, load the root page
          if (pageId == Ensemble.ensembleRootPagePlaceholder) {
            if (screen['is_home']) {
              completer.complete(loadYaml(screen['content']));
              return completer.future;
            }
          } else if (screen['id'] == pageId || screen['name'] == pageId) {
            completer.complete(loadYaml(screen['content']));
            return completer.future;
          }
        }
      }
    }
    // error
    print("error processing page");
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