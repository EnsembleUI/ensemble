import 'dart:io';
import 'dart:ui';

import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/definition_providers/provider.dart';
import 'package:ensemble/framework/widget/screen.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_i18n/loaders/decoders/yaml_decode_strategy.dart';
import 'package:yaml/yaml.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' as foundation;

/**
 * Store all the definitions and assets locally together with the App
 */
class LocalDefinitionProvider extends FileDefinitionProvider {
  LocalDefinitionProvider(super.path, super.appHome,
      {super.i18nProps, super.initialForcedLocale});

  @override
  FileTranslationLoader getTranslationLoader(I18nProps i18nProps,
          {Locale? forcedLocale}) =>
      FileTranslationLoader(
        useCountryCode: false,
        fallbackFile: i18nProps.fallbackLanguage ?? 'en',
        basePath: i18nProps.path,
        // use the forcedLocale passed in at the App level, then use the forcedLocale in the config
        forcedLocale: forcedLocale ?? initialForcedLocale,
        decodeStrategies: [YamlDecodeStrategy()],
      );

  @override
  Future<ScreenDefinition> getDefinition(
      {String? screenId, String? screenName}) async {
    // Note: Web with local definition caches even if we disable browser cache
    // so you may need to re-run the app on definition changes
    var pageStr = await rootBundle
        .loadString('${path}screen/${screenId ?? screenName ?? appHome}.yaml');
    if (pageStr.isEmpty) {
      return ScreenDefinition(YamlMap());
    }
    return ScreenDefinition(loadYaml(pageStr));
  }

  @override
  Future<AppBundle> getAppBundle({bool? bypassCache = false}) async {
    final configString =
        await rootBundle.loadString('${path}/config/appConfig.json');
    final Map<String, dynamic> appConfigMap = json.decode(configString);
    if (appConfigMap.isNotEmpty) {
      appConfig = UserAppConfig(
          baseUrl: appConfigMap["baseUrl"],
          useBrowserUrl: Utils.optionalBool(appConfigMap['useBrowserUrl']),
          envVariables: appConfigMap["envVariables"]);
    }

    Map? combinedAppBundle = await getCombinedAppBundle(); // get the combined app bundle for local scripts, widgets and theme
    return AppBundle(
      theme: combinedAppBundle?["theme"],
      resources: combinedAppBundle?['resources'],
    );
  }

  Future<YamlMap?> _readFile(String file) async {
    try {
      var value = await rootBundle.loadString(path + file);
      return loadYaml(value);
    } catch (error) {
      // ignore error
    }
    return null;
  }

  Future<Map?> getCombinedAppBundle() async {
    Map code = {};
    Map resources = {};
    Map output = {};
    Map widgets = {};
    YamlMap? theme;

    try {
      // Get the manifest content
      final manifestContent =
          await rootBundle.loadString(path + '.manifest.json');
      final Map<String, dynamic> manifestMap = json.decode(manifestContent);

      try {
        if (manifestMap['widgets'] != null) {
          final List<Map<String, dynamic>> widgetsList =
              List<Map<String, dynamic>>.from(manifestMap['widgets']);

          for (var widgetItem in widgetsList) {
            // Changed to for loop since we need async
            try {
              final widgetContent = await _readFile(
                  "${widgetItem["type"]}/${widgetItem["name"]}.yaml");
              if (widgetContent is YamlMap) {
                widgets[widgetItem["name"]] = widgetContent["Widget"];
              } else {
                debugPrint('Content in ${widgetItem["name"]} is not a YamlMap');
              }
            } catch (e) {
              debugPrint('Error reading widget file ${widgetItem["name"]}: $e');
            }
          }
        }
      } catch (e) {
        debugPrint('Error processing widgets: $e');
      }

      // Process script files
      try {
        if (manifestMap['scripts'] != null) {
          final List<Map<String, dynamic>> scriptsList =
              List<Map<String, dynamic>>.from(manifestMap['scripts']);

          for (var script in scriptsList) {
            try {
              final content = await rootBundle.loadString(
                  "${path}${script["type"]}/${script["name"]}.yaml");
              code[script["name"]] = content;
            } catch (e) {
              debugPrint('Error reading script file $script: $e');
            }
          }
        }
      } catch (e) {
        debugPrint('Error processing scripts: $e');
      }

      if (manifestMap['theme'] != null) {
        Map<String, dynamic> themeMap = manifestMap["theme"];
        theme = await _readFile("${themeMap["type"]}/${themeMap["id"]}.yaml");
      }

      resources[ResourceArtifactEntry.Widgets.name] = widgets;
      resources[ResourceArtifactEntry.Scripts.name] = code;
      output["resources"] = resources;
      output["theme"] = theme;

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
  Future<DefinitionProvider> init() async {
    return this;
  }
}
