// Secrets Configuration

import 'package:ensemble/framework/storage_manager.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../ensemble.dart';

class SecretsStore with Invokable {
  static final SecretsStore _instance = SecretsStore._internal();
  SecretsStore._internal();
  factory SecretsStore() {
    return _instance;
  }
  bool _initialized = false;
  final Map<String, String> secretCache = {};

  /// read all the secrets from server and local overrides
  Future<void> initialize() async {
    if (!_initialized) {
      // add from remote
      var secrets =
          Ensemble().getConfig()?.definitionProvider.getSecrets() ?? {};

      // add local overrides
      try {
        await dotenv.load();
        secrets.addAll(dotenv.env);
      } catch (_) {}

      for (var entry in secrets.entries) {
        _cacheSecret(entry.key, entry.value);
      }

      _initialized = true;
    }
  }

  @override
  Map<String, Function> getters() {
    throw UnimplementedError();
  }

  @override
  getProperty(prop) {
    if (prop is! String) {
      return null;
    }

    // Check cached value
    var secret = secretCache[prop];

    // Resolve from dotenv
    if (secret == null) {
      var secretOverride = dotenv.env[prop];
      if (secretOverride != null && secretOverride.isNotEmpty) {
        secret = secretOverride;
      }
    }

    // Resolve from remote value
    if (secret == null) {
      var remoteSecrets =
          Ensemble().getConfig()?.definitionProvider.getSecrets();
      if (remoteSecrets != null) {
        secret = remoteSecrets[prop];
      }
    }
    if (secret != null) {
      _cacheSecret(prop, secret);
    }
    return secret;
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {};
  }

  _cacheSecret(String key, dynamic value) {
    secretCache[key] = value;
    StorageManager().writeSecurely(key: key, value: value.toString());
  }
}
