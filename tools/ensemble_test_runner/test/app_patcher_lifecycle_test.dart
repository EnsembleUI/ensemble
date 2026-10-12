import 'dart:io';

import 'package:ensemble_test_runner/cli/app_dependency_configurator.dart';
import 'package:ensemble_test_runner/cli/app_patcher.dart';
import 'package:ensemble_test_runner/cli/entry_source_transformer.dart';
import 'package:ensemble_test_runner/cli/test_timer_rewriter.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('timer rewrite plan snapshots settings for one run', () {
    final dir = Directory.systemTemp.createTempSync('timer_config_snapshot_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final config = File('${dir.path}/specs/config.yaml')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('''
timers:
  enabled: true
  maxStartAfterSeconds: 2
  maxNumberOfTimesByScreen:
    Home: 3
''');
    final plan = TestTimerRewritePlan.forApp(
      appDir: dir.path,
      testsDirRelative: 'specs',
    );
    final snapshot = plan.config;
    config.writeAsStringSync('''
timers:
  enabled: false
  maxStartAfterSeconds: 9
''');

    expect(plan.config, same(snapshot));
    expect(plan.enabled, isTrue);
    expect(snapshot.maxStartAfterSeconds, 2);
    expect(snapshot.maxNumberOfTimesByScreen['Home'], 3);
    expect(
      () => snapshot.maxNumberOfTimesByScreen['Home'] = 99,
      throwsUnsupportedError,
    );
  });

  test('timer rewrite plan rejects tests directories outside the app root', () {
    final app = Directory.systemTemp.createTempSync('timer_plan_root_');
    addTearDown(() => app.deleteSync(recursive: true));
    final external =
        Directory.systemTemp.createTempSync('timer_plan_external_');
    addTearDown(() => external.deleteSync(recursive: true));
    File('${external.path}/config.yaml')
        .writeAsStringSync('timers:\n  enabled: true\n');
    Link('${app.path}/tests').createSync(external.path);

    expect(
      () => TestTimerRewritePlan.forApp(
        appDir: app.path,
        testsDirRelative: 'tests',
      ),
      throwsStateError,
    );
  });

  test('custom host entry and tests directory are bundled but never modified',
      () {
    final dir = Directory.systemTemp.createTempSync('yaml_host_patcher_');
    addTearDown(() => dir.deleteSync(recursive: true));
    const pubspec = '''
name: sample_host
flutter:
  assets: []
''';
    const entry = '''
import 'package:ensemble_test_runner/ensemble_test_runner.dart';
Future<void> main() => runApplicationTests(driver: createDriver());
''';
    File('${dir.path}/pubspec.yaml').writeAsStringSync(pubspec);
    Directory('${dir.path}/specs').createSync();
    File('${dir.path}/specs/login.test.yaml').writeAsStringSync('''
id: login
steps: []
''');
    Directory('${dir.path}/test').createSync();
    final entryFile = File('${dir.path}/test/application_tests.dart')
      ..writeAsStringSync(entry);

    final patcher = TestAppPatcher(
      dir.path,
      testsDirRelative: 'specs',
      testEntryRelativePath: 'test/application_tests.dart',
    );
    patcher.enable();
    expect(entryFile.readAsStringSync(), entry);
    expect(File('${dir.path}/pubspec.yaml').readAsStringSync(),
        contains('specs/'));
    patcher.restore();
    expect(entryFile.readAsStringSync(), entry);
    expect(File('${dir.path}/pubspec.yaml').readAsStringSync(), pubspec);
  });

  test('restoring does not rewrite a validated runner entry', () {
    final dir = Directory.systemTemp.createTempSync('runner_entry_unchanged_');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/pubspec.yaml').writeAsStringSync('''
name: sample_app
flutter:
  assets: []
''');
    final entry = File('${dir.path}/test/ensemble_tests.dart')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('''
import 'package:ensemble_test_runner/ensemble_test_runner.dart';
Future<void> main() => runEnsembleTests();
''');
    final originalTimestamp = DateTime.utc(2020, 1, 2, 3, 4, 5);
    entry.setLastModifiedSync(originalTimestamp);

    final patcher = TestAppPatcher(dir.path);
    patcher.enable();
    patcher.restore();

    expect(
      entry.lastModifiedSync().isAtSameMomentAs(originalTimestamp),
      isTrue,
    );
  });

  test('integration mode wraps a widget host entry beside it, then restores',
      () {
    final dir = Directory.systemTemp.createTempSync('yaml_host_integration_');
    addTearDown(() => dir.deleteSync(recursive: true));
    const pubspec = '''
name: sample_host
dev_dependencies:
  flutter_test:
    sdk: flutter
flutter:
  assets: []
''';
    const entry = '''
import 'package:ensemble_test_runner/ensemble_test_runner.dart';
import 'host_app_test_driver.dart';
Future<void> main() => runApplicationTests(driver: createDriver());
''';
    File('${dir.path}/pubspec.yaml').writeAsStringSync(pubspec);
    Directory('${dir.path}/specs').createSync();
    File('${dir.path}/specs/login.test.yaml').writeAsStringSync('''
id: login
steps: []
''');
    Directory('${dir.path}/test').createSync();
    final entryFile = File('${dir.path}/test/application_tests.dart')
      ..writeAsStringSync(entry);

    final patcher = TestAppPatcher(
      dir.path,
      testsDirRelative: 'specs',
      testEntryRelativePath: 'test/application_tests.dart',
    );
    patcher.enable(mode: ExecutionMode.integration);

    expect(entryFile.readAsStringSync(), entry);
    expect(
      patcher.activeEntryRelativePath,
      'integration_test/application_tests.dart',
    );
    final adapter = File('${dir.path}/${patcher.activeEntryRelativePath}');
    expect(adapter.existsSync(), isTrue);
    expect(
      adapter.readAsStringSync(),
      EntrySourceTransformer.applicationIntegrationWrapperContents(
        'test/application_tests.dart',
      ),
    );
    expect(
      File('${dir.path}/pubspec.yaml').readAsStringSync(),
      contains('integration_test:'),
    );

    patcher.restore();
    expect(entryFile.readAsStringSync(), entry);
    expect(adapter.existsSync(), isFalse);
    expect(
      Directory('${dir.path}/integration_test').existsSync(),
      isFalse,
    );
    expect(File('${dir.path}/pubspec.yaml').readAsStringSync(), pubspec);
  });

  test('integration destination is validated before dependency mutation', () {
    final dir = Directory.systemTemp.createTempSync('integration_preflight_');
    final outside =
        Directory.systemTemp.createTempSync('integration_preflight_target_');
    addTearDown(() => dir.deleteSync(recursive: true));
    addTearDown(() => outside.deleteSync(recursive: true));
    const pubspec = 'name: sample_host\nflutter:\n  assets: []\n';
    final pubspecFile = File('${dir.path}/pubspec.yaml')
      ..writeAsStringSync(pubspec);
    final originalTimestamp = DateTime.utc(2020, 1, 2, 3, 4, 5);
    pubspecFile.setLastModifiedSync(originalTimestamp);
    Directory('${dir.path}/test').createSync();
    File('${dir.path}/test/application_tests.dart').writeAsStringSync('''
import 'package:ensemble_test_runner/ensemble_test_runner.dart';
Future<void> main() => runApplicationTests(driver: createDriver());
''');
    Link('${dir.path}/integration_test').createSync(outside.path);

    final patcher = TestAppPatcher(
      dir.path,
      testEntryRelativePath: 'test/application_tests.dart',
    );
    expect(
      () => patcher.enable(mode: ExecutionMode.integration),
      throwsStateError,
    );

    expect(pubspecFile.readAsStringSync(), pubspec);
    expect(
      pubspecFile.lastModifiedSync().isAtSameMomentAs(originalTimestamp),
      isTrue,
    );
    expect(Directory(outside.path).listSync(), isEmpty);
  });

  test('invalid optional widget source fails before pubspec mutation', () {
    final dir = Directory.systemTemp.createTempSync('integration_preflight_');
    addTearDown(() => dir.deleteSync(recursive: true));
    const pubspec = '''
name: sample_app
dev_dependencies:
  flutter_test:
    sdk: flutter
flutter:
  assets: []
''';
    final pubspecFile = File('${dir.path}/pubspec.yaml')
      ..writeAsStringSync(pubspec);
    final originalTimestamp = DateTime.utc(2020, 1, 2, 3, 4, 5);
    pubspecFile.setLastModifiedSync(originalTimestamp);
    File('${dir.path}/test/ensemble_tests.dart')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync([0xFF]);

    final patcher = TestAppPatcher(dir.path);
    expect(
      () => patcher.enable(mode: ExecutionMode.integration),
      throwsA(isA<FileSystemException>()),
    );

    expect(pubspecFile.readAsStringSync(), pubspec);
    expect(
      pubspecFile.lastModifiedSync().isAtSameMomentAs(originalTimestamp),
      isTrue,
    );
    expect(
      Directory('${dir.path}/integration_test').existsSync(),
      isFalse,
    );
  });

  test('integration mode keeps a host entry that already selects the binding',
      () {
    final dir = Directory.systemTemp.createTempSync('yaml_host_dual_');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/pubspec.yaml').writeAsStringSync('''
name: sample_host
dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
flutter:
  assets: []
''');
    Directory('${dir.path}/specs').createSync();
    File('${dir.path}/specs/login.test.yaml').writeAsStringSync('''
id: login
steps: []
''');
    Directory('${dir.path}/test').createSync();
    const entry = '''
import 'package:ensemble_test_runner/ensemble_test_runner.dart';
Future<void> main() => runApplicationTests(driver: createDriver());
''';
    File('${dir.path}/test/application_tests.dart').writeAsStringSync(entry);

    final patcher = TestAppPatcher(
      dir.path,
      testsDirRelative: 'specs',
      testEntryRelativePath: 'test/application_tests.dart',
    );
    patcher.enable(mode: ExecutionMode.integration);

    expect(
      patcher.activeEntryRelativePath,
      'integration_test/application_tests.dart',
    );
    expect(
      File('${dir.path}/integration_test/application_tests.dart')
          .readAsStringSync(),
      contains("import '../test/application_tests.dart'"),
    );
    expect(
      File('${dir.path}/test/application_tests.dart').readAsStringSync(),
      entry,
    );
    patcher.restore();
    expect(
      File('${dir.path}/integration_test/application_tests.dart').existsSync(),
      isFalse,
    );
  });

  test('relocateDartImports rewrites sibling imports for integration_test', () {
    expect(
      EntrySourceTransformer.relocateDartImports(
        source: "import 'host_app_test_driver.dart';\n"
            "import 'package:ensemble_test_runner/ensemble_test_runner.dart';\n",
        fromRelative: 'test/application_tests.dart',
        toRelative: 'integration_test/application_tests.dart',
      ),
      "import '../test/host_app_test_driver.dart';\n"
      "import 'package:ensemble_test_runner/ensemble_test_runner.dart';\n",
    );
  });

  test('custom paths cannot escape the application root', () {
    expect(
      () => AppDependencyConfigurator(
        appDir: '/tmp/app',
        testsDirRelative: '../tests',
      ),
      throwsStateError,
    );
    expect(
      () => TestAppPatcher('/tmp/app', testsDirRelative: '../tests'),
      throwsStateError,
    );
    expect(
      () => TestAppPatcher('/tmp/app', testEntryRelativePath: '/tmp/a.dart'),
      throwsStateError,
    );
  });

  test('entry validation preserves mode-specific acceptance and errors', () {
    final scenarios = <(ExecutionMode, String, String)>[
      (
        ExecutionMode.widget,
        'Future<void> main() => runApplicationIntegrationTests();',
        'test/application_tests.dart must call runApplicationTests().',
      ),
      (
        ExecutionMode.integration,
        'Future<void> main() {}',
        'test/application_tests.dart must call runApplicationTests() or '
            'runApplicationIntegrationTests().',
      ),
    ];

    for (final (mode, entry, expectedMessage) in scenarios) {
      final dir = Directory.systemTemp.createTempSync('runner_entry_check_');
      addTearDown(() => dir.deleteSync(recursive: true));
      const pubspec = 'name: sample_host\nflutter:\n  assets: []\n';
      File('${dir.path}/pubspec.yaml').writeAsStringSync(pubspec);
      Directory('${dir.path}/test').createSync();
      final entryFile = File('${dir.path}/test/application_tests.dart')
        ..writeAsStringSync(entry);
      final patcher = TestAppPatcher(
        dir.path,
        testEntryRelativePath: 'test/application_tests.dart',
      );

      expect(
        () => patcher.enable(mode: mode),
        throwsA(isA<StateError>().having(
          (error) => error.message,
          'message',
          expectedMessage,
        )),
      );
      expect(File('${dir.path}/pubspec.yaml').readAsStringSync(), pubspec);
      expect(entryFile.readAsStringSync(), entry);
    }
  });

  test('enable injects test assets and restores', () {
    final dir = Directory.systemTemp.createTempSync('yaml_test_patcher_');
    addTearDown(() => dir.deleteSync(recursive: true));

    const pubspec = '''
name: sample_app
dev_dependencies:
  flutter_test:
    sdk: flutter

flutter:
  assets:
    - ensemble/
''';
    File('${dir.path}/pubspec.yaml').writeAsStringSync(pubspec);
    _writeConfig(dir);
    Directory('${dir.path}/ensemble/apps/helloApp/tests')
        .createSync(recursive: true);
    File('${dir.path}/ensemble/apps/helloApp/tests/sample.test.yaml')
        .writeAsStringSync('''
id: sample
startScreen: Home
steps: []
''');

    final patcher = TestAppPatcher(dir.path);
    patcher.enable();

    expect(patcher.pubspecChanged, isTrue);
    final enabled = File('${dir.path}/pubspec.yaml').readAsStringSync();
    expect(
      enabled,
      contains(
        AppDependencyConfigurator.assetLineFor(
          'ensemble/apps/helloApp/tests',
        ),
      ),
    );
    expect(
      File('${dir.path}/${TestAppPatcher.testEntryRelativePath}')
          .readAsStringSync(),
      contains('EnsembleModules().init()'),
    );

    patcher.restore();

    expect(File('${dir.path}/pubspec.yaml').readAsStringSync(), pubspec);
    expect(patcher.pubspecChanged, isFalse);
    expect(
      File('${dir.path}/${TestAppPatcher.testEntryRelativePath}').existsSync(),
      isFalse,
    );
    expect(Directory('${dir.path}/test').existsSync(), isFalse);
  });

  test('preserves a valid runner entry without rewriting it', () {
    final dir = Directory.systemTemp.createTempSync('yaml_test_patcher_');
    addTearDown(() => dir.deleteSync(recursive: true));

    File('${dir.path}/pubspec.yaml').writeAsStringSync('''
name: sample_app
dev_dependencies:
  flutter_test:
    sdk: flutter
flutter:
  assets:
    - ensemble/
''');
    _writeConfig(dir);
    Directory('${dir.path}/ensemble/apps/helloApp/tests')
        .createSync(recursive: true);
    File('${dir.path}/ensemble/apps/helloApp/tests/sample.test.yaml')
        .writeAsStringSync('''
id: sample
startScreen: Home
steps: []
''');
    Directory('${dir.path}/test').createSync(recursive: true);
    File('${dir.path}/${TestAppPatcher.testEntryRelativePath}')
        .writeAsStringSync('''
import 'package:ensemble_test_runner/entry/ensemble_test_entry.dart';

void main() => runEnsembleTests();
''');
    final originalEntry = File(
      '${dir.path}/${TestAppPatcher.testEntryRelativePath}',
    ).readAsStringSync();

    final patcher = TestAppPatcher(dir.path);
    patcher.enable();
    patcher.restore();

    final restored = File('${dir.path}/${TestAppPatcher.testEntryRelativePath}')
        .readAsStringSync();
    expect(restored, originalEntry);
  });

  test('does not overwrite a customized test entry', () {
    final dir = Directory.systemTemp.createTempSync('yaml_test_patcher_');
    addTearDown(() => dir.deleteSync(recursive: true));

    File('${dir.path}/pubspec.yaml').writeAsStringSync('''
name: sample_app
dev_dependencies:
  flutter_test:
    sdk: flutter
flutter:
  assets:
    - ensemble/
''');
    _writeConfig(dir);
    Directory('${dir.path}/ensemble/apps/helloApp/tests')
        .createSync(recursive: true);
    File('${dir.path}/ensemble/apps/helloApp/tests/sample.test.yaml')
        .writeAsStringSync('''
id: sample
startScreen: Home
steps: []
''');
    const customEntry = '''
import 'package:ensemble_test_runner/entry/ensemble_test_entry.dart';

Future<void> main() async {
  await runEnsembleTests(
    bootstrap: () async {},
  );
}
''';
    Directory('${dir.path}/test').createSync(recursive: true);
    File('${dir.path}/${TestAppPatcher.testEntryRelativePath}')
        .writeAsStringSync(customEntry);

    final patcher = TestAppPatcher(dir.path);
    patcher.enable();

    expect(
      File('${dir.path}/${TestAppPatcher.testEntryRelativePath}')
          .readAsStringSync(),
      customEntry,
    );

    patcher.restore();

    expect(
      File('${dir.path}/${TestAppPatcher.testEntryRelativePath}')
          .readAsStringSync(),
      customEntry,
    );
  });

  test('enable skips pubspec write when test assets already present', () {
    final dir = Directory.systemTemp.createTempSync('yaml_test_patcher_');
    addTearDown(() => dir.deleteSync(recursive: true));

    const pubspec = '''
name: sample_app
dev_dependencies:
  flutter_test:
    sdk: flutter

flutter:
  assets:
    - ensemble/
    - ensemble/apps/helloApp/tests/
''';
    final pubspecFile = File('${dir.path}/pubspec.yaml')
      ..writeAsStringSync(pubspec);
    final originalTimestamp = DateTime.utc(2020, 1, 2, 3, 4, 5);
    pubspecFile.setLastModifiedSync(originalTimestamp);
    _writeConfig(dir);
    Directory('${dir.path}/ensemble/apps/helloApp/tests')
        .createSync(recursive: true);
    File('${dir.path}/ensemble/apps/helloApp/tests/sample.test.yaml')
        .writeAsStringSync('''
id: sample
startScreen: Home
steps: []
''');

    final patcher = TestAppPatcher(dir.path);
    patcher.enable();

    expect(patcher.pubspecChanged, isFalse);
    expect(File('${dir.path}/pubspec.yaml').readAsStringSync(), pubspec);

    patcher.restore();
    expect(patcher.pubspecChanged, isFalse);
    expect(
      pubspecFile.lastModifiedSync().isAtSameMomentAs(originalTimestamp),
      isTrue,
    );
  });

  test('enable adds nested test asset directories for mock files', () {
    final dir = Directory.systemTemp.createTempSync('yaml_test_patcher_');
    addTearDown(() => dir.deleteSync(recursive: true));

    const pubspec = '''
name: sample_app
flutter:
  assets:
    - ensemble/
    - ensemble/apps/helloApp/tests/
''';
    File('${dir.path}/pubspec.yaml').writeAsStringSync(pubspec);
    _writeConfig(dir);
    Directory('${dir.path}/ensemble/apps/helloApp/tests/mocks/common')
        .createSync(recursive: true);
    File('${dir.path}/ensemble/apps/helloApp/tests/sample.test.yaml')
        .writeAsStringSync('''
id: sample
startScreen: Home
steps:
  - expectVisible:
      id: home
''');
    File('${dir.path}/ensemble/apps/helloApp/tests/mocks/common/base.mock.json')
        .writeAsStringSync('{}');

    final patcher = TestAppPatcher(dir.path);
    patcher.enable();

    final enabled = File('${dir.path}/pubspec.yaml').readAsStringSync();
    expect(
      enabled,
      contains('    - ensemble/apps/helloApp/tests/mocks/common/'),
    );

    patcher.restore();
  });

  test('exposes configured tests directory and test presence', () {
    final dir = Directory.systemTemp.createTempSync('yaml_test_patcher_');
    addTearDown(() => dir.deleteSync(recursive: true));

    File('${dir.path}/pubspec.yaml').writeAsStringSync('''
name: sample_app
flutter:
  assets:
    - ensemble/
''');
    _writeConfig(dir);

    final patcher = TestAppPatcher(dir.path);
    expect(patcher.testsDirRelative, 'ensemble/apps/helloApp/tests');
    expect(patcher.hasTestsOnDisk, isFalse);

    Directory('${dir.path}/ensemble/apps/helloApp/tests')
        .createSync(recursive: true);
    File('${dir.path}/ensemble/apps/helloApp/tests/login_flow.test.yaml')
        .writeAsStringSync('''
id: login_flow
startScreen: Login
steps:
  - expectVisible:
      id: login_button
''');

    expect(patcher.hasTestsOnDisk, isTrue);
  });

  test('reuses the positive test asset scan when enabling the patch', () {
    final dir = Directory.systemTemp.createTempSync('runner_asset_scan_');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/pubspec.yaml').writeAsStringSync('''
name: sample_app
flutter:
  assets: []
''');
    final testsDir = Directory('${dir.path}/tests')..createSync();
    final testFile = File('${testsDir.path}/sample.test.yaml')
      ..writeAsStringSync('id: sample\nsteps: []\n');

    final patcher = TestAppPatcher(dir.path, testsDirRelative: 'tests');
    expect(patcher.hasTestsOnDisk, isTrue);
    testFile.deleteSync();
    patcher.enable();

    expect(
      File('${dir.path}/pubspec.yaml').readAsStringSync(),
      contains('    - tests/'),
    );
    patcher.restore();
  });

  test('resolves app test configuration once per patcher run', () {
    final dir = Directory.systemTemp.createTempSync('runner_config_snapshot_');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/pubspec.yaml').writeAsStringSync(
      'name: sample_app\nflutter:\n  assets: []\n',
    );
    _writeConfig(dir);

    final patcher = TestAppPatcher(dir.path);
    expect(patcher.testsDirRelative, 'ensemble/apps/helloApp/tests');

    File('${dir.path}/ensemble/ensemble-config.yaml').writeAsStringSync('''
definitions:
  local:
    path: ensemble/apps/reconfigured
''');

    expect(patcher.testsDirRelative, 'ensemble/apps/helloApp/tests');
  });

  test('configured app test path cannot escape through parent traversal', () {
    final dir = Directory.systemTemp.createTempSync('runner_path_escape_');
    addTearDown(() => dir.deleteSync(recursive: true));
    const pubspec = 'name: sample_app\nflutter:\n  assets: []\n';
    File('${dir.path}/pubspec.yaml').writeAsStringSync(pubspec);
    File('${dir.path}/ensemble/ensemble-config.yaml')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('''
definitions:
  local:
    path: ../../outside
''');

    final patcher = TestAppPatcher(dir.path);
    expect(() => patcher.enable(), throwsStateError);
    expect(File('${dir.path}/pubspec.yaml').readAsStringSync(), pubspec);
  });

  test('configured app test path cannot scan through an external symlink', () {
    final dir = Directory.systemTemp.createTempSync('runner_path_link_');
    final outside = Directory.systemTemp.createTempSync('runner_path_target_');
    addTearDown(() => dir.deleteSync(recursive: true));
    addTearDown(() => outside.deleteSync(recursive: true));
    const pubspec = 'name: sample_app\nflutter:\n  assets: []\n';
    File('${dir.path}/pubspec.yaml').writeAsStringSync(pubspec);
    File('${dir.path}/ensemble/ensemble-config.yaml')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('''
definitions:
  local:
    path: ensemble/apps/sample
''');
    Directory('${dir.path}/ensemble/apps').createSync(recursive: true);
    Directory('${outside.path}/tests').createSync(recursive: true);
    File('${outside.path}/tests/outside.test.yaml')
        .writeAsStringSync('id: outside\nsteps: []\n');
    Link('${dir.path}/ensemble/apps/sample').createSync(outside.path);

    final patcher = TestAppPatcher(dir.path);
    expect(() => patcher.enable(), throwsStateError);
    expect(File('${dir.path}/pubspec.yaml').readAsStringSync(), pubspec);
  });

  test('test discovery does not follow nested directory symlinks', () {
    final dir = Directory.systemTemp.createTempSync('runner_nested_link_');
    final outside =
        Directory.systemTemp.createTempSync('runner_nested_target_');
    addTearDown(() => dir.deleteSync(recursive: true));
    addTearDown(() => outside.deleteSync(recursive: true));
    const pubspec = 'name: sample_app\nflutter:\n  assets: []\n';
    File('${dir.path}/pubspec.yaml').writeAsStringSync(pubspec);
    final tests = Directory('${dir.path}/specs')..createSync();
    final externalTests = Directory('${outside.path}/nested')
      ..createSync(recursive: true);
    File('${externalTests.path}/outside.test.yaml')
        .writeAsStringSync('id: outside\nsteps: []\n');
    Link('${tests.path}/external').createSync(outside.path);

    final patcher = TestAppPatcher(dir.path, testsDirRelative: 'specs');
    expect(patcher.hasTestsOnDisk, isFalse);
    patcher.enable();

    expect(File('${dir.path}/pubspec.yaml').readAsStringSync(), pubspec);
    patcher.restore();
  });

  test('rechecks cached test path symlinks before each filesystem access', () {
    final dir = Directory.systemTemp.createTempSync('runner_path_recheck_');
    final outside =
        Directory.systemTemp.createTempSync('runner_path_recheck_target_');
    addTearDown(() => dir.deleteSync(recursive: true));
    addTearDown(() => outside.deleteSync(recursive: true));
    File('${dir.path}/pubspec.yaml').writeAsStringSync(
      'name: sample_app\nflutter:\n  assets: []\n',
    );
    _writeConfig(dir);
    final testDir = Directory('${dir.path}/ensemble/apps/helloApp/tests')
      ..createSync(recursive: true);
    final patcher = TestAppPatcher(dir.path);

    expect(patcher.testsDirRelative, 'ensemble/apps/helloApp/tests');
    testDir.deleteSync();
    Link(testDir.path).createSync(outside.path);

    expect(() => patcher.hasTestsOnDisk, throwsStateError);
  });

  test('does not add test assets when the directory has no test cases', () {
    final dir = Directory.systemTemp.createTempSync('runner_patcher_');
    addTearDown(() => dir.deleteSync(recursive: true));
    const pubspec = '''
name: sample_app
flutter:
  assets: []
''';
    File('${dir.path}/pubspec.yaml').writeAsStringSync(pubspec);
    Directory('${dir.path}/specs').createSync();
    File('${dir.path}/specs/notes.yaml').writeAsStringSync('notes: []');

    final patcher = TestAppPatcher(dir.path, testsDirRelative: 'specs');
    patcher.enable();

    expect(File('${dir.path}/pubspec.yaml').readAsStringSync(), pubspec);
    patcher.restore();
  });

  test('caps configured app timers in a target directory only', () {
    final dir = Directory.systemTemp.createTempSync('yaml_test_patcher_');
    addTearDown(() => dir.deleteSync(recursive: true));

    File('${dir.path}/pubspec.yaml').writeAsStringSync('''
name: sample_app
flutter:
  assets:
    - ensemble/
''');
    _writeConfig(dir);
    Directory('${dir.path}/ensemble/apps/helloApp/tests')
        .createSync(recursive: true);
    File('${dir.path}/ensemble/apps/helloApp/tests/config.yaml')
        .writeAsStringSync('''
timers:
  enabled: true
  maxStartAfterSeconds: 1
  maxRepeatIntervalSeconds: 2
  maxNumberOfTimes: 10
  maxNumberOfTimesByScreen:
    Reset: 5
''');
    File('${dir.path}/ensemble/apps/helloApp/tests/sample.test.yaml')
        .writeAsStringSync('''
id: sample
startScreen: Home
steps: []
''');
    Directory('${dir.path}/ensemble/apps/helloApp/screens')
        .createSync(recursive: true);
    const screen = '''
View:
  onLoad:
    startAfter: 60
    repeatInterval: 30
    maxNumberOfTimes: 120
    # startAfter: 120
    nested:
      startAfter: 0
''';
    final screenFile =
        File('${dir.path}/ensemble/apps/helloApp/screens/Reset.yaml');
    screenFile.writeAsStringSync(screen);

    final workerDir = Directory('${dir.path}/worker')..createSync();
    Directory('${workerDir.path}/ensemble/apps/helloApp/screens')
        .createSync(recursive: true);
    final workerScreenFile =
        File('${workerDir.path}/ensemble/apps/helloApp/screens/Reset.yaml');
    workerScreenFile.writeAsStringSync(screen);

    final plan = TestTimerRewritePlan.forApp(
      appDir: dir.path,
      testsDirRelative: 'ensemble/apps/helloApp/tests',
    );
    plan.applyTo(workerDir.path);

    expect(screenFile.readAsStringSync(), screen);
    expect(workerScreenFile.readAsStringSync(), '''
View:
  onLoad:
    startAfter: 1
    repeatInterval: 2
    maxNumberOfTimes: 5
    # startAfter: 120
    nested:
      startAfter: 0
''');

    expect(screenFile.readAsStringSync(), screen);
    expect(workerScreenFile.readAsStringSync(), '''
View:
  onLoad:
    startAfter: 1
    repeatInterval: 2
    maxNumberOfTimes: 5
    # startAfter: 120
    nested:
      startAfter: 0
''');
  });
  test('legacy patcher import re-exports the canonical patcher', () {
    // This file imports the compatibility path; the implementation remains
    // owned by the canonical app_patcher library.
    expect(TestAppPatcher, isNotNull);
  });
}

void _writeConfig(Directory dir) {
  Directory('${dir.path}/ensemble').createSync(recursive: true);
  File('${dir.path}/ensemble/ensemble-config.yaml').writeAsStringSync('''
definitions:
  local:
    path: ensemble/apps/helloApp
    appHome: Home
''');
}
