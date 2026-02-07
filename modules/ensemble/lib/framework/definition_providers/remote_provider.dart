import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/definition_providers/provider.dart';
import 'package:ensemble/framework/widget/screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_i18n/loaders/decoders/yaml_decode_strategy.dart';
import 'package:http/http.dart' as http;
import 'package:yaml/yaml.dart';

class RemoteDefinitionProvider extends FileDefinitionProvider {
  // TODO: we can fetch the whole App bundle here
  RemoteDefinitionProvider(
    super.path,
    super.appHome, {
    super.i18nProps,
    super.initialForcedLocale,
    this.cacheEnabled = false,
  });

  final bool cacheEnabled;
  static Map<String, dynamic> cache = {};

  @override
  FileTranslationLoader getTranslationLoader(I18nProps i18nProps,
          {Locale? forcedLocale}) =>
      NetworkFileTranslationLoader(
          useCountryCode: false,
          fallbackFile: i18nProps.fallbackLanguage ?? 'en',
          baseUri: Uri.parse(i18nProps.path),
          forcedLocale: forcedLocale ?? initialForcedLocale,
          decodeStrategies: [YamlDecodeStrategy()]);

  @override
  Future<ScreenDefinition> getDefinition(
      {String? screenId, String? screenName}) async {
    String screen = screenId ?? screenName ?? appHome;

    Completer<ScreenDefinition> completer = Completer();
    dynamic res = cache[screen];
    if (res != null) {
      completer.complete(res);
      return completer.future;
    }
    http.Response response = await http.get(Uri.parse('${path}screens/${screen}.yaml'));
    if (response.statusCode == 200) {
      dynamic res = ScreenDefinition(loadYaml(response.body));
      if (cacheEnabled) {
        cache[screen] = res;
      }
      completer.complete(res);
    } else {
      completer.complete(ScreenDefinition(YamlMap()));
    }
    return completer.future;
  }

  @override
  Future<AppBundle> getAppBundle({bool? bypassCache = false}) async {
    dynamic env = await _readFileAsString('config/appConfig.json');
    if(env == null){
    env = await _readYamlFile('appConfig.yaml');
    }
    else{ 
        env = json.decode(env);
    }
    if (env != null) {
      appConfig = UserAppConfig(
        baseUrl: path,
        envVariables: env as Map<String, dynamic>,
      );
    }
    YamlMap? theme = await _readYamlFile('theme.yaml');
    if(theme == null) {
      theme = await _readYamlFile('theme.ensemble');
    }
    Map<dynamic, dynamic>? resources = await getCombinedAppBundle();
    if (resources == null) {
      resources = await _readYamlFile('resources.ensemble');
    }
    return AppBundle(
        theme: theme,
        resources: resources);
  }

  Future<YamlMap?> _readYamlFile(String file) async {
    try {
      http.Response response = await http.get(Uri.parse(path + file));
      if (response.statusCode == 200) {
        return loadYaml(response.body);
      }
    } catch (error) {
      // ignore
    }
    return null;
  }

  Future<String?> _readFileAsString(String file) async {
    try {
      http.Response response = await http.get(Uri.parse(path + file));
      if (response.statusCode == 200) {
        return response.body;
      }
    } catch (error) {
      // ignore
    }
    return null;
  }

  Future<Map?> getCombinedAppBundle() async {
    Map code = {};
    Map output = {};
    Map widgets = {};

    try {
      // Get the manifest content
      final manifestContent =
          await http.get(Uri.parse(path + '.manifest.json'));
      final Map<String, dynamic> manifestMap = json.decode(manifestContent.body);

      // Process App Widgets
      try {
        if (manifestMap['widgets'] != null) {
          final List<Map<String, dynamic>> widgetsList =
              List<Map<String, dynamic>>.from(manifestMap['widgets']);

          for (var widgetItem in widgetsList) {
            try {
              // Load the widget content in YamlMap
              final widgetContent =
                  await _readYamlFile("widgets/${widgetItem["name"]}.yaml");
              if (widgetContent is YamlMap) {
                widgets[widgetItem["name"]] = widgetContent["Widget"];
              } else {
                debugPrint('Content in ${widgetItem["name"]} is not a YamlMap');
              }
            } catch (e) {
              // ignore error
            }
          }
        }
      } catch (e) {
        debugPrint('Error processing widgets: $e');
      }

      // Process App Scripts
      try {
        if (manifestMap['scripts'] != null) {
          final List<Map<String, dynamic>> scriptsList =
              List<Map<String, dynamic>>.from(manifestMap['scripts']);

          for (var script in scriptsList) {
            try {
              // Load the script content in string
              final scriptContent = await http.get(Uri.parse("${path}scripts/${script["name"]}.js"));
              code[script["name"]] = scriptContent.body;
            } catch (e) {
              // ignore error
            }
          }
        }
      } catch (e) {
        debugPrint('Error processing scripts: $e');
      }

      output[ResourceArtifactEntry.Widgets.name] = widgets;
      output[ResourceArtifactEntry.Scripts.name] = code;

      return output;
    } catch (e) {
      return null;
    }
  }

  @override
  UserAppConfig? getAppConfig() {
    return appConfig;
  }

  @override
  void onAppLifecycleStateChanged(AppLifecycleState state) {
    // no-op
  }

  @override
  String? getHomeScreenName() {
    return appHome; // For remote provider, appHome is the home screen name
  }

  @override
  Future<DefinitionProvider> init() async {
    return this;
  }
}
