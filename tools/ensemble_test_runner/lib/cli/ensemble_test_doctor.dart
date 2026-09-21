import 'dart:convert';
import 'dart:io';

import 'package:ensemble_test_runner/cli/yaml_test_app_patcher.dart';
import 'package:ensemble_test_runner/parser/ensemble_test_parser.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
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
  final ExecutionMode? modeOverride;

  EnsembleTestDoctor(this.appDir, {this.modeOverride});

  Future<EnsembleTestDoctorResult> run({bool fix = false}) async {
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

    var suiteConfig = const EnsembleTestConfig();
    final testConfigFile = File(p.join(testsDir.path, 'config.yaml'));
    if (testConfigFile.existsSync()) {
      final relativePath = p.relative(testConfigFile.path, from: appDir);
      final content = testConfigFile.readAsStringSync();
      if (!content.contains(hostedConfigSchemaUrl)) {
        warn('$relativePath does not reference the hosted config schema URL');
      }
      try {
        suiteConfig = EnsembleTestParser.parseConfigString(
          content,
          sourcePath: relativePath,
        );
        ok('Found tests/config.yaml');
      } catch (failure) {
        error('$relativePath: $failure');
      }
    }

    final executionMode = modeOverride ?? suiteConfig.mode;
    ok('Execution mode: ${executionMode.name}');
    if (executionMode == ExecutionMode.integration) {
      if (suiteConfig.devices.isNotEmpty) {
        warn(
          'Integration mode ignores devices[].model viewport and keeps entries '
          'whose platform matches the connected emulator/simulator; locale and '
          'theme still apply. Other platforms are skipped.',
        );
      }
      final androidProject = Directory(p.join(appDir, 'android', 'app'));
      final iosProject = File(
        p.join(appDir, 'ios', 'Runner.xcodeproj', 'project.pbxproj'),
      );
      if (!androidProject.existsSync() && !iosProject.existsSync()) {
        error(
          'No complete Android or iOS project found. Run '
          '`flutter create --platforms=android,ios .` from the app root.',
        );
      }
      if (androidProject.existsSync()) {
        if (fix) {
          final before =
              YamlTestAppPatcher.androidDesugaringRequirementMessage(appDir);
          if (before != null) {
            YamlTestAppPatcher(appDir).applyAndroidDesugaringFix();
            final after =
                YamlTestAppPatcher.androidDesugaringRequirementMessage(appDir);
            if (after == null) {
              ok('Enabled Android core library desugaring');
            } else {
              warn(after);
            }
          }
        }
        final desugaring =
            YamlTestAppPatcher.androidDesugaringRequirementMessage(appDir);
        if (desugaring == null) {
          ok('Android core library desugaring is enabled');
        } else {
          warn(desugaring);
        }
      }
      if (iosProject.existsSync()) {
        if (fix) {
          final before =
              YamlTestAppPatcher.iosDeploymentTargetRequirementMessage(
            appDir,
          );
          if (before != null) {
            YamlTestAppPatcher(appDir).applyIosDeploymentTargetFix();
            // Keep the raised files permanently for doctor --fix (no restore).
            final after =
                YamlTestAppPatcher.iosDeploymentTargetRequirementMessage(
              appDir,
            );
            if (after == null) {
              ok(
                'Raised iOS deployment target to '
                '${YamlTestAppPatcher.minIntegrationIosDeploymentTarget}',
              );
            } else {
              warn(after);
            }
          }
        }
        _reportIosDeploymentTarget(
          appDir: appDir,
          ok: ok,
          warn: warn,
        );
      }
      final devicesResult = await Process.run(
        'flutter',
        ['devices', '--machine'],
        workingDirectory: appDir,
      );
      if (devicesResult.exitCode != 0) {
        error('Could not discover Flutter devices');
      } else {
        try {
          final dynamic devices = json.decode(devicesResult.stdout.toString());
          final supported = devices is List
              ? devices.where((dynamic item) {
                  if (item is! Map) return false;
                  final platform = item['targetPlatform']?.toString() ?? '';
                  return platform.startsWith('android') || platform == 'ios';
                }).length
              : 0;
          if (supported == 0) {
            warn(
              'No Android or iOS emulator/simulator/device is currently connected',
            );
          } else {
            ok('Found $supported supported integration target(s)');
          }
        } catch (_) {
          error('flutter devices --machine returned invalid JSON');
        }
      }
      if (suiteConfig.services.isNotEmpty) {
        final adb = await Process.run('which', ['adb']);
        if (adb.exitCode == 0) {
          ok('Found adb for Android host-service routing');
        } else {
          warn(
              'adb is not on PATH; Android host services will not be routable');
        }
      }
    }

    final ids = <String, String>{};
    final sessions = <String, String>{};
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
        if (test.session != null) {
          sessions[test.id] = test.session!;
        }
        referencedWidgetIds.addAll(test.referencedWidgetIds);
      } catch (failure) {
        error('$relativePath: $failure');
      }
    }

    for (final entry in sessions.entries) {
      if (!ids.containsKey(entry.value)) {
        error(
            'Test "${entry.key}" references unknown session "${entry.value}"');
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
  String? session,
  Set<String> referencedWidgetIds,
  String? error,
});

_DoctorTest _parseDoctorTest(String content) {
  final dynamic doc = loadYaml(content);
  if (doc is! YamlMap) {
    return (
      id: '',
      session: null,
      referencedWidgetIds: <String>{},
      error: 'root must be a map',
    );
  }
  final unsupportedKeys = _unsupportedTestRootKeys(doc);
  if (unsupportedKeys.isNotEmpty) {
    return (
      id: '',
      session: null,
      referencedWidgetIds: <String>{},
      error: 'Unsupported root key${unsupportedKeys.length == 1 ? '' : 's'} '
          '${unsupportedKeys.map((key) => '"$key"').join(', ')}',
    );
  }

  final id = doc['id']?.toString();
  if (id == null || id.isEmpty) {
    return (
      id: '',
      session: null,
      referencedWidgetIds: <String>{},
      error: 'Each test must have an "id"',
    );
  }

  final startScreen = doc['startScreen']?.toString();
  final session = doc['session']?.toString();
  final hasStartScreen = startScreen != null && startScreen.isNotEmpty;
  if (!hasStartScreen) {
    return (
      id: id,
      session: session,
      referencedWidgetIds: <String>{},
      error: 'Test "$id" must have "startScreen"',
    );
  }

  final steps = doc['steps'];
  if (steps is! YamlList || steps.isEmpty) {
    return (
      id: id,
      session: session,
      referencedWidgetIds: <String>{},
      error: 'Test "$id" must have a non-empty "steps" list',
    );
  }

  return (
    id: id,
    session: session == null || session.isEmpty ? null : session,
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

void _reportIosDeploymentTarget({
  required String appDir,
  required void Function(String message) ok,
  required void Function(String message) warn,
}) {
  final message =
      YamlTestAppPatcher.iosDeploymentTargetRequirementMessage(appDir);
  if (message == null) {
    final podfile = File(p.join(appDir, 'ios', 'Podfile'));
    if (!podfile.existsSync()) {
      ok('No iOS Podfile (skipped deployment-target check)');
      return;
    }
    final match = RegExp(
      r'''^#?\s*platform\s*:ios\s*,\s*['"]([0-9.]+)['"]''',
      multiLine: true,
    ).firstMatch(podfile.readAsStringSync());
    ok('iOS deployment target is ${match?.group(1) ?? 'ok'}');
    return;
  }
  warn(message);
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
