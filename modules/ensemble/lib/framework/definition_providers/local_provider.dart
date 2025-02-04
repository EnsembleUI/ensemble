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
        .loadString('${path}screens/${screenId ?? screenName ?? appHome}.yaml');
    if (pageStr.isEmpty) {
      return ScreenDefinition(YamlMap());
    }
    return ScreenDefinition(loadYaml(pageStr));
  }

  @override
  Future<AppBundle> getAppBundle({bool? bypassCache = false}) async {
    try {
      final configString =
          await rootBundle.loadString('${path}/config/appConfig.json');
      final Map<String, dynamic> appConfigMap = json.decode(configString);
      if (appConfigMap.isNotEmpty) {
        appConfig = UserAppConfig(
            baseUrl: appConfigMap["baseUrl"],
            useBrowserUrl: Utils.optionalBool(appConfigMap['useBrowserUrl']),
            envVariables: appConfigMap["envVariables"]);
      }
    } catch (e) {
      // ignore error
    }

    return AppBundle(
      theme: await _readFile('theme.yaml'),
      resources: await getCombinedAppBundle(), // get the combined app bundle for local scripts and widgets
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
    Map output = {};
    Map widgets = {};

    try {
      // Get the manifest content
      final manifestContent =
          await rootBundle.loadString(path + '.manifest.json');
      final Map<String, dynamic> manifestMap = json.decode(manifestContent);

      // Process App Widgets
      try {
        if (manifestMap['widgets'] != null) {
          final List<Map<String, dynamic>> widgetsList =
              List<Map<String, dynamic>>.from(manifestMap['widgets']);

          for (var widgetItem in widgetsList) {
            try {
              // Load the widget content in YamlMap
              final widgetContent =
                  await _readFile("widgets/${widgetItem["name"]}.yaml");
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
              final scriptContent = await rootBundle
                  .loadString("${path}scripts/${script["name"]}.yaml");
              code[script["name"]] = scriptContent;
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
  Future<DefinitionProvider> init() async {
    return this;
  }
}
