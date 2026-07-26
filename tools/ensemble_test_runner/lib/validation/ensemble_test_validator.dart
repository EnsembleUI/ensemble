import 'dart:convert';
import 'dart:io';

import 'package:ensemble_test_runner/inspect/ensemble_app_inspector.dart';
import 'package:ensemble_test_runner/parser/ensemble_test_parser.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

enum ValidationSeverity { error, warning }

class EnsembleTestValidationIssue {
  final ValidationSeverity severity;
  final String code;
  final String message;
  final String? path;
  final String? testId;

  const EnsembleTestValidationIssue({
    required this.severity,
    required this.code,
    required this.message,
    this.path,
    this.testId,
  });

  Map<String, dynamic> toJson() => {
        'severity': severity.name,
        'code': code,
        'message': message,
        if (path != null) 'path': path,
        if (testId != null) 'testId': testId,
      };
}

class EnsembleTestValidationResult {
  final List<EnsembleTestValidationIssue> issues;

  const EnsembleTestValidationResult(this.issues);

  bool get hasErrors =>
      issues.any((issue) => issue.severity == ValidationSeverity.error);

  String formatText() {
    if (issues.isEmpty) return 'Ensemble test validation passed';
    return issues.map((issue) {
      final location = [
        if (issue.path != null) issue.path,
        if (issue.testId != null) issue.testId,
      ].join(' ');
      final prefix = '[${issue.severity.name.toUpperCase()}] ${issue.code}';
      return location.isEmpty
          ? '$prefix: ${issue.message}'
          : '$prefix ($location): ${issue.message}';
    }).join('\n');
  }

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert({
        'status': hasErrors ? 'failed' : 'passed',
        'errors': issues
            .where((issue) => issue.severity == ValidationSeverity.error)
            .length,
        'warnings': issues
            .where((issue) => issue.severity == ValidationSeverity.warning)
            .length,
        'issues': issues.map((issue) => issue.toJson()).toList(),
      });
}

class EnsembleTestValidator {
  final String appDir;

  EnsembleTestValidator(this.appDir);

  EnsembleTestValidationResult validate() {
    final issues = <EnsembleTestValidationIssue>[];
    void add(
      ValidationSeverity severity,
      String code,
      String message, {
      String? path,
      String? testId,
    }) {
      issues.add(EnsembleTestValidationIssue(
        severity: severity,
        code: code,
        message: message,
        path: path,
        testId: testId,
      ));
    }

    late final EnsembleAppInspection inspection;
    try {
      inspection = EnsembleAppInspector(appDir).inspect();
    } on StateError catch (error) {
      add(ValidationSeverity.error, 'config', error.message);
      return EnsembleTestValidationResult(issues);
    }

    final testsDirRelative = p.posix.join(inspection.appPath, 'tests');
    final testsDir = Directory(p.join(appDir, testsDirRelative));
    if (!testsDir.existsSync()) {
      add(
        ValidationSeverity.error,
        'missingTests',
        'No declarative tests found. Add *.test.yaml files under $testsDirRelative/',
      );
      return EnsembleTestValidationResult(issues);
    }

    final testFiles = testsDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.test.yaml'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    if (testFiles.isEmpty) {
      add(
        ValidationSeverity.error,
        'missingTests',
        'No declarative tests found. Add *.test.yaml files under $testsDirRelative/',
      );
      return EnsembleTestValidationResult(issues);
    }

    final configFile = File(p.join(testsDir.path, 'config.yaml'));
    if (configFile.existsSync()) {
      try {
        EnsembleTestParser.parseConfigString(
          configFile.readAsStringSync(),
          sourcePath: p.relative(configFile.path, from: appDir),
        );
      } catch (error) {
        add(
          ValidationSeverity.error,
          'config',
          error.toString(),
          path: p.relative(configFile.path, from: appDir),
        );
      }
    }

    final screensByName = {
      for (final screen in inspection.screens) screen.name: screen
    };
    final knownScreens = screensByName.keys.toSet();
    final knownWidgetIds = inspection.screens.expand((s) => s.testIds).toSet();
    final knownApis = inspection.screens.expand((s) => s.apis).toSet();
    final ids = <String, String>{};
    final sessions = <String, String>{};

    for (final file in testFiles) {
      final relativePath =
          p.relative(file.path, from: appDir).replaceAll('\\', '/');
      final dynamic doc = loadYaml(file.readAsStringSync());
      if (doc is! YamlMap) {
        add(ValidationSeverity.error, 'parse', 'Test root must be a map',
            path: relativePath);
        continue;
      }

      final unsupportedKeys = _unsupportedTestRootKeys(doc);
      if (unsupportedKeys.isNotEmpty) {
        add(
          ValidationSeverity.error,
          'unsupportedRootKey',
          'Unsupported root key${unsupportedKeys.length == 1 ? '' : 's'} '
              '${unsupportedKeys.map((key) => '"$key"').join(', ')}',
          path: relativePath,
        );
        continue;
      }

      final id = doc['id']?.toString();
      if (id == null || id.isEmpty) {
        add(ValidationSeverity.error, 'missingId', 'Each test must have an id',
            path: relativePath);
        continue;
      }
      final existing = ids[id];
      if (existing != null) {
        add(
          ValidationSeverity.error,
          'duplicateId',
          'Duplicate test id "$id" also found in $existing',
          path: relativePath,
          testId: id,
        );
      } else {
        ids[id] = relativePath;
      }

      final startScreen = doc['startScreen']?.toString();
      final session = doc['session']?.toString();
      if (session != null && session.isNotEmpty) {
        sessions[id] = session;
      }
      if (startScreen != null &&
          startScreen.isNotEmpty &&
          !knownScreens.contains(startScreen)) {
        add(
          ValidationSeverity.error,
          'unknownScreen',
          'Unknown startScreen "$startScreen"',
          path: relativePath,
          testId: id,
        );
      }

      final steps = doc['steps'];
      if (steps is! YamlList || steps.isEmpty) {
        add(
          ValidationSeverity.error,
          'missingSteps',
          'Test must define a non-empty steps list',
          path: relativePath,
          testId: id,
        );
        continue;
      }

      final stepInfo = _collectStepInfo(steps);
      for (final widgetId in stepInfo.widgetIds) {
        if (_isPlaceholder(widgetId)) continue;
        if (!knownWidgetIds.contains(widgetId)) {
          add(
            ValidationSeverity.warning,
            'unknownWidgetId',
            'No obvious widget id/testId definition found for "$widgetId"',
            path: relativePath,
            testId: id,
          );
        }
      }
      for (final api in stepInfo.apiNames) {
        if (_isPlaceholder(api)) continue;
        if (!knownApis.contains(api)) {
          add(
            ValidationSeverity.warning,
            'unknownApi',
            'No obvious API definition found for "$api"',
            path: relativePath,
            testId: id,
          );
        }
      }
    }

    for (final entry in sessions.entries) {
      if (!ids.containsKey(entry.value)) {
        add(
          ValidationSeverity.error,
          'unknownSession',
          'Unknown session "${entry.value}"',
          path: ids[entry.key],
          testId: entry.key,
        );
      }
    }

    return EnsembleTestValidationResult(issues);
  }
}

typedef _StepInfo = ({
  Set<String> widgetIds,
  Set<String> apiNames,
});

_StepInfo _collectStepInfo(dynamic steps) {
  final widgetIds = <String>{};
  final apiNames = <String>{};

  void visit(dynamic node) {
    if (node is! Iterable) return;
    for (final step in node) {
      if (step is! Map || step.isEmpty) continue;
      final type = step.keys.first.toString();
      final args = step.values.first;
      if (args is Map) {
        final id = args['id'];
        if (id != null) widgetIds.add(id.toString());
        final name = args['name'];
        if (name != null && type.toLowerCase().contains('api')) {
          apiNames.add(name.toString());
        }
        visit(args['steps']);
        final single = args['step'];
        if (single != null) visit([single]);
      }
    }
  }

  visit(steps);
  return (
    widgetIds: widgetIds,
    apiNames: apiNames,
  );
}

bool _isPlaceholder(String value) =>
    RegExp(r'\$\{(inputs|scenario)\.[A-Za-z0-9_.-]+\}').hasMatch(value);

List<String> _unsupportedTestRootKeys(YamlMap map) {
  const supported = {
    'id',
    'type',
    'feature',
    'tags',
    'description',
    'owner',
    'priority',
    'parallel',
    'retry',
    'startScreen',
    'startScreenInputs',
    'session',
    'initialState',
    'setup',
    'mocks',
    'scenarios',
    'steps',
  };
  return map.keys
      .map((key) => key.toString())
      .where((key) => !supported.contains(key))
      .toList();
}
