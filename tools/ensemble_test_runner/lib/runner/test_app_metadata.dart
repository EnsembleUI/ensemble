import 'dart:io';

import 'package:yaml/yaml.dart';

/// Reads the app metadata required by the test host.
final class TestAppMetadata {
  const TestAppMetadata._();

  static Map<String, String> packageInfo(String appDir) =>
      _resolvePackageInfo(Directory(appDir));

  static Map<String, String> _resolvePackageInfo(Directory appDir) {
    final pubspec = _readPubspec(appDir);
    final properties = _readProperties(
      File('${appDir.path}/ensemble/ensemble.properties'),
    );
    final packageName =
        properties['appId'] ?? pubspec['name'] ?? 'com.ensemble.test';
    final appName = properties['appName'] ??
        _titleFromPackageName(pubspec['name']) ??
        'EnsembleTest';
    final versionParts = _splitVersion(pubspec['version']);
    return {
      'appName': appName,
      'packageName': packageName,
      'version': versionParts.version,
      'buildNumber': versionParts.buildNumber,
    };
  }

  static Map<String, String> _readPubspec(Directory appDir) {
    final file = File('${appDir.path}/pubspec.yaml');
    if (!file.existsSync()) return const {};
    try {
      final document = loadYaml(file.readAsStringSync());
      if (document is! YamlMap) return const {};
      return {
        for (final entry in document.entries)
          if (entry.value != null) entry.key.toString(): entry.value.toString(),
      };
    } catch (_) {
      return const {};
    }
  }

  static Map<String, String> _readProperties(File file) {
    if (!file.existsSync()) return const {};
    final values = <String, String>{};
    for (final rawLine in file.readAsLinesSync()) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final separator = line.indexOf('=');
      if (separator <= 0) continue;
      values[line.substring(0, separator).trim()] =
          line.substring(separator + 1).trim();
    }
    return values;
  }

  static ({String version, String buildNumber}) _splitVersion(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return (version: '1.0.0', buildNumber: '1');
    }
    final parts = raw.trim().split('+');
    final version = parts.first.trim();
    final buildNumber = parts.length > 1 ? parts.sublist(1).join('+') : '1';
    return (
      version: version.isEmpty ? '1.0.0' : version,
      buildNumber: buildNumber.trim().isEmpty ? '1' : buildNumber.trim(),
    );
  }

  static String? _titleFromPackageName(String? name) {
    if (name == null || name.trim().isEmpty) return null;
    return name
        .trim()
        .split(RegExp(r'[_\s]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}
