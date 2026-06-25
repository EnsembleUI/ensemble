import 'dart:io';
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
    final screen = screenId ?? screenName ?? appHome;
    if (!isSafeRemoteScreenSelector(screen)) {
      return ScreenDefinition(YamlMap());
    }
    // Note: Web with local definition caches even if we disable browser cache
    // so you may need to re-run the app on definition changes
    var pageStr = await rootBundle.loadString('${path}screens/$screen.yaml');
    if (pageStr.isEmpty) {
      return ScreenDefinition(YamlMap());
    }
    return ScreenDefinition(loadYaml(pageStr));
  }

  @override
  Future<AppBundle> getAppBundle({bool? bypassCache = false}) async {
    // #region agent log
    _agentDebugLog('H2B', 'local_provider.dart:57', 'getAppBundle start',
        {'path': path, 'appHome': appHome});
    // #endregion
    try {
      final configString =
          await rootBundle.loadString('${path}config/appConfig.json');
      // #region agent log
      _agentDebugLog('H2B', 'local_provider.dart:62', 'appConfig loaded', {
        'path': '${path}config/appConfig.json',
        'length': configString.length
      });
      // #endregion
      final Map<String, dynamic> appConfigMap = json.decode(configString);
      if (appConfigMap.isNotEmpty) {
        appConfig = UserAppConfig(
            baseUrl: appConfigMap["baseUrl"],
            useBrowserUrl: Utils.optionalBool(appConfigMap['useBrowserUrl']),
            envVariables: appConfigMap["envVariables"]);
      }
    } catch (e) {
      // #region agent log
      _agentDebugLog(
          'H2B',
          'local_provider.dart:72',
          'appConfig missing or invalid',
          {'path': '${path}config/appConfig.json', 'error': e.toString()});
      // #endregion
      // ignore error
    }

    // #region agent log
    _agentDebugLog('H2C', 'local_provider.dart:77',
        'before theme and combined bundle', {'path': path});
    // #endregion
    final theme = await _readFile('theme.yaml');
    // #region agent log
    _agentDebugLog('H2C', 'local_provider.dart:82', 'theme read complete',
        {'hasTheme': theme != null});
    // #endregion
    final resources = await getCombinedAppBundle();
    // #region agent log
    _agentDebugLog(
        'H2C', 'local_provider.dart:87', 'combined bundle complete', {
      'hasResources': resources != null,
      'resourceKeys': resources?.keys.map((e) => e.toString()).toList()
    });
    // #endregion
    return AppBundle(
      theme: theme,
      resources:
          resources, // get the combined app bundle for local scripts and widgets
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
    Map actions = {};

    try {
      // #region agent log
      _agentDebugLog('H2D', 'local_provider.dart:103', 'before manifest load',
          {'path': path + '.manifest.json'});
      // #endregion
      // Get the manifest content
      final manifestContent =
          await rootBundle.loadString(path + '.manifest.json');
      final Map<String, dynamic> manifestMap = json.decode(manifestContent);
      // #region agent log
      _agentDebugLog('H2D', 'local_provider.dart:110', 'manifest loaded', {
        'length': manifestContent.length,
        'widgetCount': (manifestMap['widgets'] as List?)?.length ?? 0,
        'scriptCount': (manifestMap['scripts'] as List?)?.length ?? 0,
        'actionCount': (manifestMap['actions'] as List?)?.length ?? 0,
      });
      // #endregion

      // Process App Widgets
      try {
        if (manifestMap['widgets'] != null) {
          final List<Map<String, dynamic>> widgetsList =
              List<Map<String, dynamic>>.from(manifestMap['widgets']);

          for (var widgetItem in widgetsList) {
            try {
              // #region agent log
              _agentDebugLog(
                  'H2E',
                  'local_provider.dart:124',
                  'before widget load',
                  {'name': widgetItem["name"]?.toString()});
              // #endregion
              // Load the widget content in YamlMap
              final widgetContent =
                  await _readFile("widgets/${widgetItem["name"]}.yaml");
              // #region agent log
              _agentDebugLog(
                  'H2E', 'local_provider.dart:130', 'after widget load', {
                'name': widgetItem["name"]?.toString(),
                'isYamlMap': widgetContent is YamlMap
              });
              // #endregion
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
              // #region agent log
              _agentDebugLog('H2F', 'local_provider.dart:154',
                  'before script load', {'name': script["name"]?.toString()});
              // #endregion
              // Load the script content in string
              final scriptContent = await rootBundle
                  .loadString("${path}scripts/${script["name"]}.js");
              code[script["name"]] = scriptContent;
              // #region agent log
              _agentDebugLog(
                  'H2F', 'local_provider.dart:161', 'after script load', {
                'name': script["name"]?.toString(),
                'length': scriptContent.length
              });
              // #endregion
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
              // #region agent log
              _agentDebugLog('H2G', 'local_provider.dart:182',
                  'before action load', {'name': actionName});
              // #endregion
              final dynamic actionContent =
                  await _readFile("actions/$actionName.yaml");
              // #region agent log
              _agentDebugLog(
                  'H2G',
                  'local_provider.dart:187',
                  'after action load',
                  {'name': actionName, 'isMap': actionContent is Map});
              // #endregion

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

      // #region agent log
      _agentDebugLog(
          'H2D', 'local_provider.dart:220', 'getCombinedAppBundle returning', {
        'widgets': widgets.length,
        'scripts': code.length,
        'actions': actions.length
      });
      // #endregion
      return output;
    } catch (e) {
      // #region agent log
      _agentDebugLog('H2D', 'local_provider.dart:224',
          'getCombinedAppBundle failed', {'error': e.toString()});
      // #endregion
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

// #region agent log
void _agentDebugLog(
  String hypothesisId,
  String location,
  String message,
  Map<String, Object?> data,
) {
  final payload = <String, Object?>{
    'sessionId': 'cab532',
    'id': 'log_${DateTime.now().microsecondsSinceEpoch}',
    'timestamp': DateTime.now().millisecondsSinceEpoch,
    'runId': 'timeout-analysis-2',
    'hypothesisId': hypothesisId,
    'location': location,
    'message': message,
    'data': data,
  };
  try {
    File(
        '/Users/sharjeelyunus/Desktop/Ensemble/ensemble/.cursor/debug-cab532.log')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('${jsonEncode(payload)}\n', mode: FileMode.append);
  } catch (_) {}
}
// #endregion
