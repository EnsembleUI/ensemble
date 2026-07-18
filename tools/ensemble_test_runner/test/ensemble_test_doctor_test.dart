import 'dart:io';

import 'package:ensemble_test_runner/cli/ensemble_test_doctor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('doctor passes for a valid app test setup', () async {
    final dir = _createApp();
    addTearDown(() => dir.deleteSync(recursive: true));
    _writeTest(dir, 'login_flow.test.yaml', '''
# yaml-language-server: \$schema=$hostedSchemaUrl
id: login_flow
startScreen: Login
steps:
  - expectVisible:
      id: login_button
''');

    final result = await EnsembleTestDoctor(dir.path).run();

    expect(result.hasErrors, isFalse);
    expect(result.lines.join('\n'), contains('Found 1 YAML test file'));
  });

  test('doctor reports missing tests cleanly', () async {
    final dir = _createApp();
    addTearDown(() => dir.deleteSync(recursive: true));

    final result = await EnsembleTestDoctor(dir.path).run();

    expect(result.hasErrors, isTrue);
    expect(
      result.lines.join('\n'),
      contains(
        'No declarative tests found. Add *.test.yaml files under ensemble/apps/inhome/tests/',
      ),
    );
  });

  test('doctor reports duplicate ids and unknown sessions', () async {
    final dir = _createApp();
    addTearDown(() => dir.deleteSync(recursive: true));
    _writeTest(dir, 'a.test.yaml', '''
id: duplicate
startScreen: Login
steps:
  - expectVisible:
      id: login_button
''');
    _writeTest(dir, 'b.test.yaml', '''
id: duplicate
startScreen: Home
session: missing
steps:
  - expectVisible:
      id: login_button
''');

    final result = await EnsembleTestDoctor(dir.path).run();
    final output = result.lines.join('\n');

    expect(result.hasErrors, isTrue);
    expect(output, contains('Duplicate test id "duplicate"'));
    expect(output, contains('references unknown session "missing"'));
  });

  test('doctor rejects unsupported root keys', () async {
    final dir = _createApp();
    addTearDown(() => dir.deleteSync(recursive: true));
    _writeTest(dir, 'unsupported.test.yaml', '''
id: unsupported
startScreen: Login
unknownSetting: true
steps:
  - expectVisible:
      id: login_button
''');

    final result = await EnsembleTestDoctor(dir.path).run();

    expect(result.hasErrors, isTrue);
    expect(
      result.lines.join('\n'),
      contains('Unsupported root key "unknownSetting"'),
    );
  });
}

Directory _createApp() {
  final dir = Directory.systemTemp.createTempSync('ensemble_doctor_');
  File('${dir.path}/pubspec.yaml').writeAsStringSync('''
name: sample_app
dev_dependencies:
  ensemble_test_runner:
    path: ../ensemble_test_runner
''');
  Directory('${dir.path}/ensemble/apps/inhome/screens')
      .createSync(recursive: true);
  Directory('${dir.path}/ensemble/apps/inhome/tests')
      .createSync(recursive: true);
  File('${dir.path}/ensemble/ensemble-config.yaml').writeAsStringSync('''
definitions:
  local:
    path: ensemble/apps/inhome
    appHome: Login
''');
  File('${dir.path}/ensemble/apps/inhome/screens/Login.yaml')
      .writeAsStringSync('''
View:
  body:
    Button:
      testId: login_button
      label: Login
''');
  return dir;
}

void _writeTest(Directory dir, String name, String content) {
  File('${dir.path}/ensemble/apps/inhome/tests/$name')
      .writeAsStringSync(content);
}
