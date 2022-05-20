import 'dart:convert';
import 'dart:async';
import 'package:ensemble/ensemble.dart';
import 'package:yaml/yaml.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' as foundation;

abstract class DefinitionProvider {
  Future<YamlMap> getDefinition({String? screenId});
}

class LocalDefinitionProvider extends DefinitionProvider {
  LocalDefinitionProvider(this.path, this.appHome);
  final String path;
  final String appHome;

  @override
  Future<YamlMap> getDefinition({String? screenId}) async {
    // Note: Web with local definition caches even if we disable browser cache
    // so you may need to re-run the app on definition changes
    var pageStr = await rootBundle.loadString(
        '$path${screenId ?? appHome}.yaml',
        cache: foundation.kReleaseMode);
    return loadYaml(pageStr);
  }
}



class RemoteDefinitionProvider extends DefinitionProvider {
  // TODO: we can fetch the whole App bundle here
  RemoteDefinitionProvider(this.path, this.appHome);
  final String path;
  final String appHome;

  @override
  Future<YamlMap> getDefinition({String? screenId}) async {
    String screen = screenId ?? appHome;

    Completer<YamlMap> completer = Completer();
    http.Response response = await http.get(
        Uri.parse('$path$screen.yaml'));
    if (response.statusCode == 200) {
      completer.complete(loadYaml(response.body));
    } else {
      completer.completeError("Error loading Remote screen $screen");
    }
    return completer.future;
  }
}

class EnsembleDefinitionProvider extends DefinitionProvider {
  EnsembleDefinitionProvider(this.url, this.appId);
  final String url;
  final String appId;

  @override
  Future<YamlMap> getDefinition({String? screenId}) async {
    Completer<YamlMap> completer = Completer();
    http.Response response = await http.get(
        Uri.parse('$url?id=$appId'));
    if (response.statusCode == 200) {
      Map<String, dynamic> result = json.decode(response.body);
      if (result[appId] != null
          && result[appId]['screens'] is List
          && (result[appId]['screens'] as List).isNotEmpty) {
        List<dynamic> screens = result[appId]['screens'];

        for (dynamic screen in screens) {
          // if loading App without specifying page, load the root page
          if (screenId == null) {
            if (screen['is_home']) {
              completer.complete(loadYaml(screen['content']));
              return completer.future;
            }
          } else if (screen['id'] == screenId || screen['name'] == screenId) {
            completer.complete(loadYaml(screen['content']));
            return completer.future;
          }
        }
      }
    }
    completer.completeError("Error loading Ensemble page: ${screenId ?? 'Home'}");
    return completer.future;
  }

}




