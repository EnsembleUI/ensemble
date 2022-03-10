import 'dart:async';
import 'package:yaml/yaml.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

abstract class DefinitionProvider {
  DefinitionProvider(this.pageName);
  final String pageName;

  Future<YamlMap> getDefinition();
}

class RemoteDefinitionProvider extends DefinitionProvider {
  RemoteDefinitionProvider(
    pageName,
    this.apiKey,
  ): super(pageName);

  final String apiKey;

  @override
  Future<YamlMap> getDefinition() async {
    Completer<YamlMap> completer = Completer();
    http.Response response = await http.get(
        Uri.parse('https://ensemble-s3.s3.us-west-1.amazonaws.com/ensemble/definitions/$pageName.yaml'));
    if (response.statusCode == 200) {

      completer.complete(loadYaml(response.body));
    } else {
      completer.completeError("Error processing page");
    }
    return completer.future;
  }



}

class LocalDefinitionProvider extends DefinitionProvider {
  LocalDefinitionProvider(
    pageName,
    this.path,
  ): super(pageName);

  final String path;

  @override
  Future<YamlMap> getDefinition() async {
    String formattedPath = path.endsWith('/') ? path : path + '/';
    var pageStr = await rootBundle.loadString('$formattedPath$pageName.yaml', cache: false);
    return loadYaml(pageStr);
  }


}


class ConfigError extends Error {
  ConfigError(this.message);
  final String message;

  @override
  String toString() => 'Config Error: $message';
}