import 'dart:io';

import 'package:ensemble_test_runner/parser/ensemble_test_parser.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

const hostedSchemaUrl =
    'https://cdn.ensembleui.com/schemas/ensemble_tests_schema.json';
const hostedConfigSchemaUrl =
    'https://cdn.ensembleui.com/schemas/ensemble_test_config_schema.json';

class EnsembleTestDoctorResult {
  final List<String> lines;
  final bool hasErrors;

  const EnsembleTestDoctorResult({
    required this.lines,
    required this.hasErrors,
  });
}

class EnsembleTestDoctor {
  final String appDir;

  EnsembleTestDoctor(this.appDir);

  Future<EnsembleTestDoctorResult> run() async {
    final lines = <String>['Ensemble test runner doctor'];
    var hasErrors = false;

    void ok(String message) => lines.add('[OK] $message');
    void warn(String message) => lines.add('[WARN] $message');
    void error(String message) {
      hasErrors = true;
      lines.add('[ERROR] $message');
    }

    final pubspecFile = File(p.join(appDir, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) {
      error('No pubspec.yaml found in $appDir');
      return EnsembleTestDoctorResult(lines: lines, hasErrors: hasErrors);
    }
    ok('Found pubspec.yaml');

    final pubspec = pubspecFile.readAsStringSync();
    if (pubspec.contains('ensemble_test_runner:')) {
      ok('pubspec.yaml includes ensemble_test_runner');
    } else {
      warn('pubspec.yaml does not list ensemble_test_runner in dependencies');
    }

    final configFile = File(p.join(appDir, 'ensemble', 'ensemble-config.yaml'));
    if (!configFile.existsSync()) {
      error('Missing ensemble/ensemble-config.yaml');
      return EnsembleTestDoctorResult(lines: lines, hasErrors: hasErrors);
    }
    ok('Found ensemble/ensemble-config.yaml');

    final dynamic config = loadYaml(configFile.readAsStringSync());
    if (config is! YamlMap) {
      error('ensemble-config.yaml root must be a map');
      return EnsembleTestDoctorResult(lines: lines, hasErrors: hasErrors);
    }

    final definitions = config['definitions'];
    final local = definitions is YamlMap ? definitions['local'] : null;
    if (local is! YamlMap) {
      error('ensemble-config.yaml must define definitions.local');
      return EnsembleTestDoctorResult(lines: lines, hasErrors: hasErrors);
    }

    final appPath = local['path']?.toString();
    final appHome = local['appHome']?.toString();
    if (appPath == null || appPath.isEmpty) {
      error('definitions.local.path is required');
      return EnsembleTestDoctorResult(lines: lines, hasErrors: hasErrors);
    }
    if (appHome == null || appHome.isEmpty) {
      error('definitions.local.appHome is required');
    }
    ok('Using local app path $appPath');

    final appPathOnDisk = Directory(p.join(appDir, appPath));
    if (!appPathOnDisk.existsSync()) {
      error('definitions.local.path does not exist: $appPath');
      return EnsembleTestDoctorResult(lines: lines, hasErrors: hasErrors);
    }

    final testsDirRelative =
        p.posix.join(_withoutTrailingSlash(appPath), 'tests');
    final testsDir = Directory(p.join(appDir, testsDirRelative));
    if (!testsDir.existsSync()) {
      error(
        'No declarative tests found. Add *.test.yaml files under $testsDirRelative/',
      );
      return EnsembleTestDoctorResult(lines: lines, hasErrors: hasErrors);
    }

    final testFiles = testsDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.test.yaml'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    if (testFiles.isEmpty) {
      error(
        'No declarative tests found. Add *.test.yaml files under $testsDirRelative/',
      );
      return EnsembleTestDoctorResult(lines: lines, hasErrors: hasErrors);
    }
    ok('Found ${testFiles.length} YAML test file(s)');

    final testConfigFile = File(p.join(testsDir.path, 'config.yaml'));
    if (testConfigFile.existsSync()) {
      final relativePath = p.relative(testConfigFile.path, from: appDir);
      final content = testConfigFile.readAsStringSync();
      if (!content.contains(hostedConfigSchemaUrl)) {
        warn('$relativePath does not reference the hosted config schema URL');
      }
      try {
        EnsembleTestParser.parseConfigString(
          content,
          sourcePath: relativePath,
        );
        ok('Found tests/config.yaml');
      } catch (failure) {
        error('$relativePath: $failure');
      }
    }

    final ids = <String, String>{};
    final prerequisites = <String, String>{};
    final referencedWidgetIds = <String>{};

    for (final file in testFiles) {
      final relativePath = p.relative(file.path, from: appDir);
      final content = file.readAsStringSync();
      if (!content.contains(hostedSchemaUrl)) {
        warn('$relativePath does not reference the hosted schema URL');
      }

      final test = _parseDoctorTest(content);
      if (test.error != null) {
        error('$relativePath: ${test.error}');
        continue;
      }

      try {
        final existing = ids[test.id];
        if (existing != null) {
          error(
              'Duplicate test id "${test.id}" in $existing and $relativePath');
        } else {
          ids[test.id] = relativePath;
        }
        if (test.prerequisite != null) {
          prerequisites[test.id] = test.prerequisite!;
        }
        referencedWidgetIds.addAll(test.referencedWidgetIds);
      } catch (failure) {
        error('$relativePath: $failure');
      }
    }

    for (final entry in prerequisites.entries) {
      if (!ids.containsKey(entry.value)) {
        error(
            'Test "${entry.key}" references unknown prerequisite "${entry.value}"');
      }
    }

    final knownWidgetIds = _collectKnownWidgetIds(appPathOnDisk);
    if (knownWidgetIds.isNotEmpty) {
      final missing = referencedWidgetIds
          .where((id) => !knownWidgetIds.contains(id))
          .toList()
        ..sort();
      if (missing.isNotEmpty) {
        warn(
          'Could not find obvious widget id/testId definitions for: ${missing.join(", ")}',
        );
      } else {
        ok('All obvious widget id/testId references were found');
      }
    }

    if (!hasErrors) {
      ok('Doctor completed without blocking errors');
    }

    return EnsembleTestDoctorResult(lines: lines, hasErrors: hasErrors);
  }
}

typedef _DoctorTest = ({
  String id,
  String? prerequisite,
  Set<String> referencedWidgetIds,
  String? error,
});

_DoctorTest _parseDoctorTest(String content) {
  final dynamic doc = loadYaml(content);
  if (doc is! YamlMap) {
    return (
      id: '',
      prerequisite: null,
      referencedWidgetIds: <String>{},
      error: 'root must be a map',
    );
  }

  if (doc.containsKey('options')) {
    return (
      id: '',
      prerequisite: null,
      referencedWidgetIds: <String>{},
      error:
          'Root-level "options" is no longer supported. Move shared settings to tests/config.yaml.',
    );
  }

  final id = doc['id']?.toString();
  if (id == null || id.isEmpty) {
    return (
      id: '',
      prerequisite: null,
      referencedWidgetIds: <String>{},
      error: 'Each test must have an "id"',
    );
  }

  final startScreen = doc['startScreen']?.toString();
  final prerequisite = doc['prerequisite']?.toString();
  final hasStartScreen = startScreen != null && startScreen.isNotEmpty;
  final hasPrerequisite = prerequisite != null && prerequisite.isNotEmpty;
  if (hasStartScreen == hasPrerequisite) {
    return (
      id: id,
      prerequisite: prerequisite,
      referencedWidgetIds: <String>{},
      error: 'Test "$id" must have either "startScreen" or "prerequisite"',
    );
  }

  final steps = doc['steps'];
  if (steps is! YamlList || steps.isEmpty) {
    return (
      id: id,
      prerequisite: prerequisite,
      referencedWidgetIds: <String>{},
      error: 'Test "$id" must have a non-empty "steps" list',
    );
  }

  return (
    id: id,
    prerequisite: hasPrerequisite ? prerequisite : null,
    referencedWidgetIds: _collectReferencedWidgetIds(steps),
    error: null,
  );
}

Set<String> _collectReferencedWidgetIds(dynamic steps) {
  final ids = <String>{};
  if (steps is! Iterable) return ids;
  for (final step in steps) {
    if (step is! Map) continue;
    if (step.isEmpty) continue;
    final args = step.values.first;
    if (args is Map) {
      final id = args['id'];
      if (id != null && id.toString().isNotEmpty) {
        ids.add(id.toString());
      }
      ids.addAll(_collectReferencedWidgetIds(args['steps']));
      final singleStep = args['step'];
      if (singleStep != null) {
        ids.addAll(_collectReferencedWidgetIds([singleStep]));
      }
    }
  }
  return ids;
}

Set<String> _collectKnownWidgetIds(Directory appPath) {
  final ids = <String>{};
  if (!appPath.existsSync()) return ids;

  final idPattern =
      RegExp(r'^\s*(?:testId|id):\s*([^\s#]+)\s*$', multiLine: true);
  for (final file in appPath.listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.yaml')) continue;
    final content = file.readAsStringSync();
    for (final match in idPattern.allMatches(content)) {
      final id = match.group(1);
      if (id != null && !id.startsWith(r'${')) ids.add(id);
    }
  }
  return ids;
}

String _withoutTrailingSlash(String path) {
  final normalized = path.replaceAll('\\', '/');
  return normalized.endsWith('/')
      ? normalized.substring(0, normalized.length - 1)
      : normalized;
}
