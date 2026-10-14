import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

class EnsembleAppInspection {
  final String appDir;
  final String appPath;
  final String appHome;
  final List<ScreenInspection> screens;
  final List<String> widgets;
  final List<String> actions;
  final List<String> scripts;

  const EnsembleAppInspection({
    required this.appDir,
    required this.appPath,
    required this.appHome,
    required this.screens,
    this.widgets = const [],
    this.actions = const [],
    this.scripts = const [],
  });

  Map<String, dynamic> toJson() => {
        'appDir': appDir,
        'appPath': appPath,
        'appHome': appHome,
        'screens': screens.map((screen) => screen.toJson()).toList(),
        'widgets': widgets,
        'actions': actions,
        'scripts': scripts,
      };

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());
}

class ScreenInspection {
  final String name;
  final String path;
  final List<String> imports;
  final List<String> testIds;
  final List<String> apis;
  final List<String> actions;
  final List<String> navigationTargets;
  final List<String> storageReferences;
  final List<String> envReferences;
  final List<String> lifecycle;

  const ScreenInspection({
    required this.name,
    required this.path,
    this.imports = const [],
    this.testIds = const [],
    this.apis = const [],
    this.actions = const [],
    this.navigationTargets = const [],
    this.storageReferences = const [],
    this.envReferences = const [],
    this.lifecycle = const [],
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'path': path,
        'imports': imports,
        'testIds': testIds,
        'apis': apis,
        'actions': actions,
        'navigationTargets': navigationTargets,
        'storageReferences': storageReferences,
        'envReferences': envReferences,
        'lifecycle': lifecycle,
      };
}

class EnsembleAppInspector {
  final String appDir;

  EnsembleAppInspector(this.appDir);

  EnsembleAppInspection inspect() {
    final config = _loadLocalConfig();
    final appPath = config.path;
    final appRoot = Directory(p.join(appDir, appPath));
    if (!appRoot.existsSync()) {
      throw StateError('definitions.local.path does not exist: $appPath');
    }

    return EnsembleAppInspection(
      appDir: appDir,
      appPath: appPath,
      appHome: config.appHome,
      screens: _inspectScreens(appPath, appRoot),
      widgets: _listYamlNames(Directory(p.join(appRoot.path, 'widgets'))),
      actions: _listYamlNames(Directory(p.join(appRoot.path, 'actions'))),
      scripts: _listNames(Directory(p.join(appRoot.path, 'scripts')), '.js'),
    );
  }

  _LocalConfig _loadLocalConfig() {
    final configFile = File(p.join(appDir, 'ensemble', 'ensemble-config.yaml'));
    if (!configFile.existsSync()) {
      throw StateError('Missing ensemble/ensemble-config.yaml');
    }
    final dynamic config = loadYaml(configFile.readAsStringSync());
    if (config is! YamlMap) {
      throw StateError('ensemble-config.yaml root must be a map');
    }
    final definitions = config['definitions'];
    final local = definitions is YamlMap ? definitions['local'] : null;
    if (local is! YamlMap) {
      throw StateError('ensemble-config.yaml must define definitions.local');
    }
    final path = local['path']?.toString();
    final appHome = local['appHome']?.toString();
    if (path == null || path.isEmpty) {
      throw StateError('definitions.local.path is required');
    }
    if (appHome == null || appHome.isEmpty) {
      throw StateError('definitions.local.appHome is required');
    }
    return _LocalConfig(path: _withoutTrailingSlash(path), appHome: appHome);
  }

  List<ScreenInspection> _inspectScreens(String appPath, Directory appRoot) {
    final screensDir = Directory(p.join(appRoot.path, 'screens'));
    if (!screensDir.existsSync()) return const [];

    final files = screensDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.yaml'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    return files.map((file) {
      final relative =
          p.relative(file.path, from: appDir).replaceAll('\\', '/');
      final name = p.basenameWithoutExtension(file.path);
      final content = file.readAsStringSync();
      final dynamic yaml = loadYaml(content);
      final collector = _InspectionCollector(content);
      if (yaml is YamlMap) collector.visit(yaml);

      return ScreenInspection(
        name: name,
        path: relative,
        imports: _toStringList(yaml is YamlMap ? yaml['Import'] : null),
        testIds: collector.testIds.sorted(),
        apis: collector.apis.sorted(),
        actions: collector.actions.sorted(),
        navigationTargets: collector.navigationTargets.sorted(),
        storageReferences: collector.storageReferences.sorted(),
        envReferences: collector.envReferences.sorted(),
        lifecycle: collector.lifecycle.sorted(),
      );
    }).toList();
  }
}

class _InspectionCollector {
  final String content;
  final Set<String> testIds = {};
  final Set<String> apis = {};
  final Set<String> actions = {};
  final Set<String> navigationTargets = {};
  final Set<String> storageReferences = {};
  final Set<String> envReferences = {};
  final Set<String> lifecycle = {};

  _InspectionCollector(this.content) {
    storageReferences
        .addAll(_matches(RegExp(r'ensemble\.storage\.([A-Za-z0-9_.]+)')));
    envReferences.addAll(_matches(RegExp(r'env\.([A-Za-z0-9_.]+)')));
  }

  void visit(dynamic node, {String? key}) {
    if (node is YamlMap || node is Map) {
      final map = node as Map;
      if (map.containsKey('onLoad')) lifecycle.add('onLoad');
      if (map.containsKey('API') && map['API'] is Map) {
        apis.addAll((map['API'] as Map).keys.map((key) => key.toString()));
      }
      if (map.containsKey('Action') && map['Action'] is Map) {
        actions
            .addAll((map['Action'] as Map).keys.map((key) => key.toString()));
      }

      for (final entry in map.entries) {
        final k = entry.key.toString();
        final value = entry.value;
        if ((k == 'testId' || k == 'id') && value != null) {
          final id = value.toString();
          if (id.isNotEmpty && !id.startsWith(r'${')) testIds.add(id);
        }
        if (k == 'invokeAPI' && value is Map && value['name'] != null) {
          apis.add(value['name'].toString());
        }
        if (k == 'executeAction' && value is Map && value['name'] != null) {
          actions.add(value['name'].toString());
        }
        if (k == 'navigateScreen' && value is Map) {
          final target = value['name'] ?? value['screen'];
          if (target != null) navigationTargets.add(target.toString());
        }
        if (k == 'setStorage' && value is Map && value['key'] != null) {
          storageReferences.add(value['key'].toString());
        }
        visit(value, key: k);
      }
    } else if (node is YamlList || node is List) {
      for (final item in node as Iterable) {
        visit(item, key: key);
      }
    }
  }

  Iterable<String> _matches(RegExp regex) {
    return regex.allMatches(content).map((match) => match.group(1)!).toSet();
  }
}

class _LocalConfig {
  final String path;
  final String appHome;

  const _LocalConfig({required this.path, required this.appHome});
}

List<String> _listYamlNames(Directory dir) => _listNames(dir, '.yaml');

List<String> _listNames(Directory dir, String extension) {
  if (!dir.existsSync()) return const [];
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith(extension))
      .map((file) => p.basenameWithoutExtension(file.path))
      .toSet()
      .toList()
    ..sort();
}

List<String> _toStringList(dynamic node) {
  if (node is Iterable) {
    return node.map((item) => item.toString()).toList()..sort();
  }
  return const [];
}

String _withoutTrailingSlash(String path) {
  final normalized = path.replaceAll('\\', '/');
  return normalized.endsWith('/')
      ? normalized.substring(0, normalized.length - 1)
      : normalized;
}

extension _SortedSet on Set<String> {
  List<String> sorted() => toList()..sort();
}
