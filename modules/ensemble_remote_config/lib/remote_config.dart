library ensemble_remote_config;

import 'package:ensemble/framework/stub/remote_config.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// Remote Config service used by Ensemble.
///
/// This module is responsible for:
/// - Fetching and activating Remote Config
/// - Providing `getValue`, `getAllValues`, `getInfo`, and `refresh` methods for the core Ensemble runtime
class RemoteConfigService {
  static final RemoteConfigService _instance = RemoteConfigService._internal();
  RemoteConfigService._internal();
  factory RemoteConfigService() => _instance;

  FirebaseRemoteConfig? _remoteConfig;

  /// Initialize Remote Config
  Future<void> ensureInitialized() async {
    if (_remoteConfig != null) return;

    final config = FirebaseRemoteConfig.instance;
    await config.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ),
    );
    _remoteConfig = config;
  }

  /// Optionally register a map of default values with Firebase Remote Config.
  ///
  /// This is entirely optional – most apps will rely on per‑call defaults in
  /// expressions – but it can be useful for centralizing defaults in Dart.
  Future<void> setDefaults(Map<String, dynamic> defaults) async {
    await ensureInitialized();
    await _remoteConfig?.setDefaults(defaults);
  }

  /// Fetch and activate latest Remote Config values
  ///
  /// Errors are swallowed; if anything fails we simply keep using defaults.
  Future<void> fetchAndActivate() async {
    await ensureInitialized();
    if (_remoteConfig == null) return;
    try {
      await _remoteConfig!.fetchAndActivate();
      if (kDebugMode) {
        debugPrint('[RemoteConfig] Initialized');
      }
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('[RemoteConfig] fetchAndActivate failed: $e\n$stack');
      }
    }
  }

  /// Get a Remote Config value
  dynamic getValue(String key, dynamic defaultValue) {
    if (_remoteConfig == null) {
      if (kDebugMode) {
        debugPrint(
            '[RemoteConfig] getValue("$key"): not initialized, using default');
      }
      return defaultValue;
    }
    try {
      // When the caller provides a typed default, prefer the Firebase typed
      // getters so we respect the parameter's declared type in RC.
      if (defaultValue is bool) {
        final v = _remoteConfig!.getBool(key);
        return v;
      }
      if (defaultValue is int) {
        final v = _remoteConfig!.getInt(key);
        return v;
      }
      if (defaultValue is double || defaultValue is num) {
        final v = _remoteConfig!.getDouble(key);
        return v;
      }

      // Fallback: work with the raw string value.
      final raw = _remoteConfig!.getString(key);
      if (raw.isEmpty) {
        if (kDebugMode) {
          debugPrint('[RemoteConfig] getValue("$key"): empty, using default');
        }
        return defaultValue;
      }

      dynamic converted = raw;

      // If no explicit default is provided, infer minimally from the string.
      if (defaultValue == null) {
        // No explicit default type: infer minimally from the string.
        final trimmed = raw.trim();
        final lower = trimmed.toLowerCase();

        if (lower == 'true') {
          converted = true;
        } else if (lower == 'false') {
          converted = false;
        } else {
          final asNum = num.tryParse(trimmed);
          if (asNum != null) {
            converted = asNum;
          }
        }
      }
      return converted;
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('[RemoteConfig] getValue("$key") failed: $e\n$stack');
      }
      return defaultValue;
    }
  }
}

extension RemoteConfigServiceDebug on RemoteConfigService {
  /// Snapshot of all RC values, using the same typing rules as [getValue]
  /// with a `null` default.
  Map<String, dynamic> getAllValues() {
    final config = _remoteConfig;
    if (config == null) return const {};

    final all = config.getAll();
    final result = <String, dynamic>{};
    all.forEach((key, _) {
      result[key] = getValue(key, null);
    });
    return result;
  }

  /// Debug information about the current RC state.
  Map<String, dynamic> getInfo() {
    final config = _remoteConfig;
    if (config == null) {
      return const {
        'initialized': false,
      };
    }
    return {
      'initialized': true,
      'lastFetchStatus': config.lastFetchStatus.toString().split('.').last,
      'lastFetchTime': config.lastFetchTime.toIso8601String(),
      'minimumFetchIntervalSeconds':
          config.settings.minimumFetchInterval.inSeconds,
      'fetchTimeoutSeconds': config.settings.fetchTimeout.inSeconds,
    };
  }
}

/// Implementation of [RemoteConfig] for use when the module is enabled
/// via [EnsembleModules]. Register with GetIt in the starter's init.
///
/// When registered, initializes and fetches Remote Config in the background;
/// [getValue] uses cached values (or defaults until fetch completes).
class RemoteConfigImpl implements RemoteConfig {
  RemoteConfigImpl() {
    RemoteConfigService().fetchAndActivate();
  }

  @override
  dynamic getValue(String key, dynamic defaultValue) =>
      RemoteConfigService().getValue(key, defaultValue);

  @override
  Map<String, dynamic> getAllValues() => RemoteConfigService().getAllValues();

  @override
  Map<String, dynamic> getInfo() => RemoteConfigService().getInfo();

  @override
  Future<void> refresh() => RemoteConfigService().fetchAndActivate();

  @override
  Future<void> setDefaults(Map<String, dynamic> defaults) =>
      RemoteConfigService().setDefaults(defaults);
}
