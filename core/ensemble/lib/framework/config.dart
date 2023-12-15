import 'package:ensemble/ensemble.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';

/// App Configuration
class AppConfig with Invokable {
  @override
  Map<String, Function> getters() {
    return {
      //'baseUrl': () => Ensemble().getConfig()?.getUserAppConfig()?.baseUrl
      'baseUrl': () =>
          Ensemble().getConfig()?.definitionProvider.getAppConfig()?.baseUrl
    };
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

// Environment Configuration
class EnvConfig with Invokable {
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
