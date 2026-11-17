/// Firebase Remote Config implementation for Ensemble apps.
library remote_config;

import 'package:ensemble/framework/config.dart';
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

  /// The fetch in flight, shared by concurrent [fetchAndActivate] calls.
  Future<void>? _fetching;

  /// Apply settings from environment variables (if present), falling back
  /// to sensible defaults. This can be called multiple times; it will
  /// re-read the env on each invocation.
  ///
  /// On iOS, `setConfigSettings` recreates the SDK's URL session, which
  /// cancels any fetch in flight (NSURLErrorDomain -999), including one the
  /// host app started on the same shared instance. So settings are only
  /// written when they actually change.
  Future<void> _applySettingsFromEnv(FirebaseRemoteConfig config) async {
    // Environment variables:
    // - remote_config_fetch_timeout (seconds)
    // - remote_config_minimum_fetch_interval (seconds)
    Duration _durationFromEnv(String key, Duration fallback) {
      final dynamic value = EnvConfig().getProperty(key);
      if (value == null || (value is String && value.isEmpty)) {
        return fallback;
      }
      if (value is num) {
        return Duration(seconds: value.toInt());
      }
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) {
          return Duration(seconds: parsed);
        }
      }
      return fallback;
    }

    final fetchTimeout = _durationFromEnv(
        'remote_config_fetch_timeout', const Duration(seconds: 10));
    final minimumFetchInterval = _durationFromEnv(
        'remote_config_minimum_fetch_interval', const Duration(hours: 1));

    final current = config.settings;
    if (current.fetchTimeout == fetchTimeout &&
        current.minimumFetchInterval == minimumFetchInterval) {
      return;
    }
    await config.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: fetchTimeout,
        minimumFetchInterval: minimumFetchInterval,
      ),
    );
  }

  /// Initialize Remote Config
  Future<void> ensureInitialized() async {
    if (_remoteConfig != null) return;

    final config = FirebaseRemoteConfig.instance;
    await _applySettingsFromEnv(config);
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
  /// Calls made while a fetch is in flight wait for that fetch instead of
  /// starting another one.
  Future<void> fetchAndActivate() {
    return _fetching ??= _fetchAndActivate().whenComplete(() {
      _fetching = null;
    });
  }

  Future<void> _fetchAndActivate() async {
    await ensureInitialized();
    if (_remoteConfig == null) return;
    // Re-apply settings on each fetch so that environment overrides
    // (which may load after first init) are honored.
    await _applySettingsFromEnv(_remoteConfig!);
    if (await _tryFetchAndActivate(_remoteConfig!)) return;
    // A failed fetch at startup is most often one that was cancelled when
    // something else (e.g. the host app) changed the config settings on iOS.
    // One retry recovers it; a real network failure just fails again.
    await Future.delayed(const Duration(seconds: 1));
    await _tryFetchAndActivate(_remoteConfig!);
  }

  /// Whether the fetch succeeded.
  Future<bool> _tryFetchAndActivate(FirebaseRemoteConfig config) async {
    try {
      await config.fetchAndActivate();
      if (config.lastFetchStatus == RemoteConfigFetchStatus.failure) {
        if (kDebugMode) {
          debugPrint('[RemoteConfig] fetchAndActivate failed');
        }
        return false;
      }
      if (kDebugMode) {
        debugPrint('[RemoteConfig] Initialized');
      }
      return true;
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('[RemoteConfig] fetchAndActivate failed: $e\n$stack');
      }
      return false;
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

/// Implementation of [RemoteConfig] for use when the module is enabled.
///
/// Register with GetIt in the project's init.
///
/// When registered, initializes and fetches Remote Config in the background;
/// [getValue] uses cached values (or defaults until fetch completes).
class RemoteConfigImpl implements RemoteConfig {
  RemoteConfigImpl() {
    RemoteConfigService().fetchAndActivate();
  }

  // Get a Remote Config value
  @override
  dynamic getValue(String key, dynamic defaultValue) =>
      RemoteConfigService().getValue(key, defaultValue);

  // Return all currently known values, using the same typing rules as [getValue] with a `null` default (i.e. minimal inference).
  @override
  Map<String, dynamic> getAllValues() => RemoteConfigService().getAllValues();

  // Debug information about the current RC state.
  @override
  Map<String, dynamic> getInfo() => RemoteConfigService().getInfo();

  // Manually trigger a refresh/fetch of Remote Config values.
  @override
  Future<void> refresh() => RemoteConfigService().fetchAndActivate();

  // Optionally register a map of default values.
  @override
  Future<void> setDefaults(Map<String, dynamic> defaults) =>
      RemoteConfigService().setDefaults(defaults);
}
