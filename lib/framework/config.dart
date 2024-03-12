import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/app_info.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/theme_manager.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';

/// App Configuration
class AppConfig with Invokable {
  BuildContext context;
  String? appId;

  AppConfig(this.context, this.appId);

  static const String useMockResponse = 'useMockResponse';
  static const String theme = 'theme';

  String get themeKey => '${appId ?? ''}_$theme';

  String get useMockResponseKey => '${appId ?? ''}_$useMockResponse';

  @override
  Map<String, Function> getters() {
    return {
      'baseUrl': () =>
          Ensemble().getConfig()?.definitionProvider.getAppConfig()?.baseUrl,
      'useMockResponse': () =>
          EnsembleStorage(context).getProperty(useMockResponseKey) ?? false,
      'theme': () => EnsembleThemeManager().currentThemeName,
      'themes': () => EnsembleThemeManager().getThemeNames(),
    };
  }

  void exitApp() {
    EnsembleStorage(context).setProperty(useMockResponseKey, false);
  }

  String? getSavedTheme() {
    return EnsembleStorage(context).getProperty(themeKey);
  }

  @override
  Map<String, Function> methods() {
    return {
      'saveTheme': (String theme) {
        EnsembleStorage(context).setProperty(themeKey, theme);
      },
      'getSavedTheme': () => getSavedTheme(),
      'removeSavedTheme': () => EnsembleStorage(context).delete(themeKey),
    };
  }

  bool isMockResponse() {
    return EnsembleStorage(context).getProperty(useMockResponseKey) ?? false;
  }

  @override
  Map<String, Function> setters() {
    return {
      'useMockResponse': (bool value) {
        EnsembleStorage(context).setProperty(useMockResponseKey, value);
      },
      'theme': (String theme) {
        EnsembleThemeManager().setTheme(theme);
      }
    };
  }
}

class EnvConfig with Invokable {
  static final EnvConfig _instance = EnvConfig._internal();

  EnvConfig._internal();

  factory EnvConfig() {
    return _instance;
  }

  // To enable test mode, we need to add --dart-define="testmode=true"
  bool get isTestMode {
    final envString = const String.fromEnvironment("testmode").toLowerCase();
    return envString == "true";
  }

  // ignore since we override getProperty
  @override
  Map<String, Function> getters() {
    throw UnimplementedError();
  }

  @override
  getProperty(prop) {
    if (prop is String) {
      Map<String, dynamic>? envOverrides = Ensemble().getConfig()?.envOverrides;
      Map<String, dynamic>? envVariables = Ensemble()
          .getConfig()
          ?.definitionProvider
          .getAppConfig()
          ?.envVariables;

      // get environment variables from overrides first (emsemble-config.yaml),
      // then fallback to custom defined ones
      return resolveEnvVariable(envOverrides, prop) ??
          resolveEnvVariable(envVariables, prop);
    }
    return null;
  }

  /// environment variables are special i.e. null is probably meant to be empty string.
  /// Here we account for it by looking for the presence of the key
  dynamic resolveEnvVariable(Map<String, dynamic>? map, String key) {
    if (map != null) {
      return map[key] ?? (map.containsKey(key) ? '' : null);
    }
    return null;
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {};
  }
}
