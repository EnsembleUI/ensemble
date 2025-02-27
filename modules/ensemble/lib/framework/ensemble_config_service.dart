import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

// EnsembleConfigService is a service that provides access to the ensemble-config.yaml file through static property once initialized
class EnsembleConfigService {
  static YamlMap? _config;
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    final yamlString = await rootBundle.loadString('ensemble/ensemble-config.yaml');
    _config = loadYaml(yamlString);
    _isInitialized = true;
  }

  static YamlMap get config {
    if (_config == null) {
      // if config is not available, load the default config
      _config = loadYaml('''
definitions:
  from: 'ensemble'
      ''');
      _isInitialized =
          true;
    }
    return _config!;
  }

  static bool get isInitialized => _isInitialized;
}