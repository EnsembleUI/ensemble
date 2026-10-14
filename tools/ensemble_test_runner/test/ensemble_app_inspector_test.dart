import 'dart:io';

import 'package:ensemble_test_runner/inspect/ensemble_app_inspector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('inspects app screens for AI generation metadata', () {
    final dir = Directory.systemTemp.createTempSync('ensemble_inspect_');
    addTearDown(() => dir.deleteSync(recursive: true));
    _writeApp(dir);

    final inspection = EnsembleAppInspector(dir.path).inspect();
    final screen = inspection.screens.single;

    expect(inspection.appPath, 'ensemble/apps/inhome');
    expect(inspection.appHome, 'Login');
    expect(screen.name, 'Login');
    expect(screen.testIds, containsAll(['email_field', 'login_button']));
    expect(screen.apis, containsAll(['login', 'profile']));
    expect(screen.actions, contains('saveSession'));
    expect(screen.navigationTargets, contains('Home'));
    expect(screen.storageReferences, contains('auth.token'));
    expect(screen.envReferences, contains('apiURL'));
    expect(screen.lifecycle, contains('onLoad'));
  });
}

void _writeApp(Directory dir) {
  File('${dir.path}/pubspec.yaml').writeAsStringSync('name: sample_app');
  Directory('${dir.path}/ensemble/apps/inhome/screens')
      .createSync(recursive: true);
  File('${dir.path}/ensemble/ensemble-config.yaml').writeAsStringSync('''
definitions:
  local:
    path: ensemble/apps/inhome
    appHome: Login
''');
  File('${dir.path}/ensemble/apps/inhome/screens/Login.yaml')
      .writeAsStringSync('''
Import:
  - common
View:
  onLoad:
    invokeAPI:
      name: profile
  body:
    Column:
      children:
        - TextInput:
            testId: email_field
        - Button:
            id: login_button
            onTap:
              executeAction:
                name: saveSession
              navigateScreen:
                name: Home
Action:
  saveSession:
    body:
      setStorage:
        key: auth.token
        value: \${env.apiURL}
API:
  login:
    url: \${env.apiURL}/login
''');
}
