import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

// EnsembleConfigService is a service that provides access to the ensemble-config.yaml file through static property once initialized
class EnsembleConfigService {
  static YamlMap? _config;

  static Future<void> initialize() async {
    final yamlString = await rootBundle.loadString('ensemble/ensemble-config.yaml');
    _config = loadYaml(yamlString);
  }

  static YamlMap get config {
    if (_config == null) {
      throw StateError('EnsembleConfig not initialized');
    }
    return _config!;
  }
}