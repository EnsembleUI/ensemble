import 'dart:io';

import 'package:ensemble_test_runner/cli/yaml_test_app_patcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

    final patcher = YamlTestAppPatcher(dir.path);
    patcher.enable();

    expect(patcher.pubspecChanged, isTrue);
    final enabled = File('${dir.path}/pubspec.yaml').readAsStringSync();
    expect(
      enabled,
      contains(
        YamlTestAppPatcher.testsAssetLineFor(
          'ensemble/apps/helloApp/tests',
        ),
      ),
    );
    expect(
      File('${dir.path}/${YamlTestAppPatcher.testEntryRelativePath}')
          .readAsStringSync(),
      contains('EnsembleModules().init()'),
    );

    patcher.restore();

    expect(File('${dir.path}/pubspec.yaml').readAsStringSync(), pubspec);
    expect(
      File('${dir.path}/${YamlTestAppPatcher.testEntryRelativePath}')
          .existsSync(),
      isFalse,
    );
  });

  test('upgrades legacy stub and keeps it after restore', () {
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
    File('${dir.path}/${YamlTestAppPatcher.testEntryRelativePath}')
        .writeAsStringSync(YamlTestAppPatcher.legacyTestEntryContents);

    final patcher = YamlTestAppPatcher(dir.path);
    patcher.enable();
    patcher.restore();

    final restored =
        File('${dir.path}/${YamlTestAppPatcher.testEntryRelativePath}')
            .readAsStringSync();
    expect(restored, contains('EnsembleModules().init()'));
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
  await runEnsembleYamlTests(
    bootstrap: () async {},
  );
}
''';
    Directory('${dir.path}/test').createSync(recursive: true);
    File('${dir.path}/${YamlTestAppPatcher.testEntryRelativePath}')
        .writeAsStringSync(customEntry);

    final patcher = YamlTestAppPatcher(dir.path);
    patcher.enable();

    expect(
      File('${dir.path}/${YamlTestAppPatcher.testEntryRelativePath}')
          .readAsStringSync(),
      customEntry,
    );

    patcher.restore();

    expect(
      File('${dir.path}/${YamlTestAppPatcher.testEntryRelativePath}')
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

    final patcher = YamlTestAppPatcher(dir.path);
    patcher.enable();

    expect(patcher.pubspecChanged, isFalse);
    expect(File('${dir.path}/pubspec.yaml').readAsStringSync(), pubspec);

    patcher.restore();
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

    final patcher = YamlTestAppPatcher(dir.path);
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

    final patcher = YamlTestAppPatcher(dir.path);
    expect(patcher.testsDirRelative, 'ensemble/apps/helloApp/tests');
    expect(patcher.hasTestYamlOnDisk, isFalse);

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

    expect(patcher.hasTestYamlOnDisk, isTrue);
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

    final patcher = YamlTestAppPatcher(dir.path);
    patcher.enable();
    patcher.rewriteTimersIn(workerDir.path);

    expect(screenFile.readAsStringSync(), screen);
    expect(workerScreenFile.readAsStringSync(), '''
View:
  onLoad:
    startAfter: 1
    repeatInterval: 2
    # startAfter: 120
    nested:
      startAfter: 0
''');

    patcher.restore();

    expect(screenFile.readAsStringSync(), screen);
    expect(workerScreenFile.readAsStringSync(), '''
View:
  onLoad:
    startAfter: 1
    repeatInterval: 2
    # startAfter: 120
    nested:
      startAfter: 0
''');
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
