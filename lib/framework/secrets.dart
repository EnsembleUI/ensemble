// Environment Configuration
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../ensemble.dart';

class SecretsStore with Invokable {
  // ignore since we override getProperty
  @override
  Map<String, Function> getters() {
    throw UnimplementedError();
  }

  @override
  getProperty(prop) {
    if (prop is String) {
      var secretOverride = dotenv.env[prop];
      if (secretOverride != null && secretOverride.isNotEmpty) {
        return secretOverride;
      }
      var remoteSecrets =
          Ensemble().getConfig()?.definitionProvider.getSecrets();
      if (remoteSecrets != null) {
        return remoteSecrets[prop];
      }
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
