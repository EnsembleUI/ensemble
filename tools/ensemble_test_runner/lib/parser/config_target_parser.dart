import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:yaml/yaml.dart';

/// Parses device and service targets declared by the suite configuration.
///
/// Keeping these target definitions together makes configuration parsing easier
/// to extend without mixing target validation with execution settings.
class ConfigTargetParser {
  const ConfigTargetParser._();

  static List<TestDeviceTarget> parseDevices(dynamic node) {
    if (node == null) return const [];
    if (node is! YamlList) {
      throw EnsembleTestFailure('"devices" must be a list');
    }
    final devices = <TestDeviceTarget>[];
    final ids = <String>{};
    for (var i = 0; i < node.length; i++) {
      final item = node[i];
      if (item is! YamlMap) {
        throw EnsembleTestFailure('Each devices entry must be a map');
      }
      const allowedKeys = {'id', 'platform', 'model', 'locale', 'theme'};
      for (final key in item.keys) {
        if (!allowedKeys.contains(key.toString())) {
          throw EnsembleTestFailure('Unsupported devices key "$key"');
        }
      }
      final platform = item['platform']?.toString().trim() ?? '';
      if (platform.isEmpty) {
        throw EnsembleTestFailure('devices[$i].platform is required');
      }
      final model = item['model']?.toString().trim() ?? '';
      if (model.isEmpty) {
        throw EnsembleTestFailure('devices[$i].model is required');
      }
      final locale = item['locale']?.toString().trim();
      final theme = _parseDeviceTheme(item['theme']);
      final idRaw = item['id']?.toString().trim();
      final id = (idRaw == null || idRaw.isEmpty)
          ? _defaultDeviceId(platform: platform, locale: locale, index: i)
          : idRaw;
      if (!ids.add(id)) {
        throw EnsembleTestFailure('Duplicate devices id "$id"');
      }
      devices.add(
        TestDeviceTarget(
          id: id,
          platform: platform,
          model: model,
          locale: (locale == null || locale.isEmpty) ? null : locale,
          theme: theme,
        ),
      );
    }
    return devices;
  }

  static String _defaultDeviceId({
    required String platform,
    required String? locale,
    required int index,
  }) {
    final platformKey = platform.toLowerCase().replaceAll(
          RegExp(r'[^a-z0-9]+'),
          '_',
        );
    final localeKey = (locale == null || locale.isEmpty)
        ? null
        : locale.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    if (localeKey == null) return '${platformKey}_$index';
    return '${platformKey}_$localeKey';
  }

  /// Optional `devices[].theme`. Empty is ignored; non-empty values are kept
  /// as written (the harness resolves aliases such as `light` to `Light`).
  static String? _parseDeviceTheme(dynamic value) {
    if (value == null) return null;
    final theme = value.toString().trim();
    if (theme.isEmpty) return null;
    return theme;
  }

  static List<TestServiceConfig> parseServices(dynamic node) {
    if (node == null) return const [];
    final services = <TestServiceConfig>[];
    final names = <String>{};
    for (final item in node as YamlList) {
      if (item is! YamlMap) {
        throw EnsembleTestFailure('Each service must be a map');
      }
      const allowedKeys = {
        'name',
        'command',
        'url',
        'arguments',
        'workingDirectory',
        'environment',
        'readyUrl',
        'readyTimeoutMs',
      };
      for (final key in item.keys) {
        if (!allowedKeys.contains(key)) {
          throw EnsembleTestFailure(
            'Unsupported service key "$key". Supported keys: '
            '${allowedKeys.join(', ')}',
          );
        }
      }

      final name = item['name']?.toString();
      final command = item['command']?.toString();
      if (name == null || name.isEmpty) {
        throw EnsembleTestFailure('Each service requires "name"');
      }
      if (!names.add(name)) {
        throw EnsembleTestFailure('Duplicate service name "$name"');
      }
      if (command == null || command.isEmpty) {
        throw EnsembleTestFailure('Service "$name" requires "command"');
      }

      final argumentsNode = item['arguments'];
      if (argumentsNode != null && argumentsNode is! YamlList) {
        throw EnsembleTestFailure('Service "$name" "arguments" must be a list');
      }
      final environmentNode = item['environment'];
      if (environmentNode != null && environmentNode is! YamlMap) {
        throw EnsembleTestFailure(
            'Service "$name" "environment" must be a map');
      }
      final timeout = item['readyTimeoutMs'];
      if (timeout != null && (timeout is! int || timeout <= 0)) {
        throw EnsembleTestFailure(
          'Service "$name" "readyTimeoutMs" must be a positive integer',
        );
      }

      services.add(
        TestServiceConfig(
          name: name,
          command: command,
          url: item['url']?.toString(),
          arguments: argumentsNode == null
              ? const []
              : argumentsNode.map<String>((value) => value.toString()).toList(),
          workingDirectory: item['workingDirectory']?.toString(),
          environment: environmentNode == null
              ? const {}
              : {
                  for (final entry in environmentNode.entries)
                    entry.key.toString(): entry.value.toString(),
                },
          readyUrl: item['readyUrl']?.toString(),
          readyTimeoutMs: timeout as int? ?? 10000,
        ),
      );
    }
    return services;
  }
}
