import 'dart:ui';

import 'package:ensemble/action/action_scope_util.dart';
import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/definition_providers/provider.dart';
import 'package:ensemble/framework/definition_providers/screen_selector_security.dart';
import 'package:ensemble/framework/widget/screen.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_i18n/loaders/decoders/yaml_decode_strategy.dart';
import 'package:yaml/yaml.dart';
import 'dart:convert';

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
    final screen = screenId ?? screenName ?? appHome;
    if (!isSafeRemoteScreenSelector(screen)) {
      return ScreenDefinition(YamlMap());
    }
    // Note: Web with local definition caches even if we disable browser cache
    // so you may need to re-run the app on definition changes
    var pageStr = await _loadLocalAssetString('${path}screens/$screen.yaml');
    if (pageStr.isEmpty) {
      return ScreenDefinition(YamlMap());
    }
    return ScreenDefinition(loadYaml(pageStr));
  }

  @override
  Future<AppBundle> getAppBundle({bool? bypassCache = false}) async {
    try {
      final configString =
          await _loadLocalAssetString('${path}config/appConfig.json');
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

    final theme = await _readFile('theme.yaml');
    final resources = await getCombinedAppBundle();
    return AppBundle(
      theme: theme,
      resources:
          resources, // get the combined app bundle for local scripts and widgets
    );
  }

  Future<YamlMap?> _readFile(String file) async {
    try {
      var value = await _loadLocalAssetString(path + file);
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
    Map actions = {};

    try {
      // Get the manifest content
      final manifestContent =
          await _loadLocalAssetString(path + '.manifest.json');
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
                // Store the full YAML to preserve Import declarations
                widgets[widgetItem["name"]] = widgetContent;
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
              final scriptContent = await _loadLocalAssetString(
                  "${path}scripts/${script["name"]}.js");
              code[script["name"]] = scriptContent;
            } catch (e) {
              // ignore error
            }
          }
        }
      } catch (e) {
        debugPrint('Error processing scripts: $e');
      }

      // Process App Actions (reusable global Actions)
      try {
        if (manifestMap['actions'] != null) {
          final List<Map<String, dynamic>> actionsList =
              List<Map<String, dynamic>>.from(manifestMap['actions']);

          for (var actionItem in actionsList) {
            try {
              final String actionName = actionItem["name"];
              final dynamic actionContent =
                  await _readFile("actions/$actionName.yaml");

              if (actionContent is! Map) {
                debugPrint(
                    'Content in action $actionName is not a Map/YamlMap (${actionContent.runtimeType})');
                continue;
              }

              final YamlMap? actionDefinition =
                  ActionScopeUtil.mergeActionFileContent(actionContent);
              if (actionDefinition == null) {
                debugPrint('Action root in $actionName is not a Map/YamlMap');
                continue;
              }

              actions[actionName] = actionDefinition;
            } catch (e) {
              // ignore error loading individual action
            }
          }
        }
      } catch (e) {
        debugPrint('Error processing actions: $e');
      }

      output[ResourceArtifactEntry.Widgets.name] = widgets;
      output[ResourceArtifactEntry.Scripts.name] = code;
      if (actions.isNotEmpty) {
        output[ResourceArtifactEntry.Actions.name] = actions;
      }

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
    return appHome; // For local provider, appHome is the home screen name
  }

  @override
  Future<DefinitionProvider> init() async {
    return this;
  }
}

Future<String> _loadLocalAssetString(String key) async {
  final data = await rootBundle.load(key);
  return utf8.decode(data.buffer.asUint8List());
}
