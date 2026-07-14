import 'dart:io';

import 'package:ensemble_test_runner/validation/ensemble_test_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('validates generated tests with structured warning issues', () {
    final dir = Directory.systemTemp.createTempSync('ensemble_validate_');
    addTearDown(() => dir.deleteSync(recursive: true));
    _writeApp(dir);
    _writeTest(dir, 'login.test.yaml', '''
id: login_happy
startScreen: Login
steps:
  - tap:
      id: missing_button
  - expectApiCalled:
      name: unknownApi
''');

    final result = EnsembleTestValidator(dir.path).validate();
    final codes = result.issues.map((issue) => issue.code).toList();

    expect(result.hasErrors, isFalse);
    expect(codes, contains('unknownWidgetId'));
    expect(codes, contains('unknownApi'));
  });

  test('passes with warnings only as non-blocking', () {
    final dir = Directory.systemTemp.createTempSync('ensemble_validate_ok_');
    addTearDown(() => dir.deleteSync(recursive: true));
    _writeApp(dir);
    _writeTest(dir, 'login.test.yaml', '''
id: login_happy
startScreen: Login
steps:
  - tap:
      id: login_button
  - expectApiCalled:
      name: login
''');

    final result = EnsembleTestValidator(dir.path).validate();

    expect(result.hasErrors, isFalse);
    expect(
      result.issues
          .where((issue) => issue.severity == ValidationSeverity.error),
      isEmpty,
    );
  });
}

void _writeApp(Directory dir) {
  File('${dir.path}/pubspec.yaml').writeAsStringSync('name: sample_app');
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
  onLoad:
    invokeAPI:
      name: profile
  body:
    Button:
      testId: login_button
      onTap:
        invokeAPI:
          name: login
API:
  profile:
    url: /profile
  login:
    url: /login
''');
}

void _writeTest(Directory dir, String name, String content) {
  File('${dir.path}/ensemble/apps/inhome/tests/$name')
      .writeAsStringSync(content);
}
