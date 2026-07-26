import 'dart:io';

import 'package:ensemble_test_runner/cli/ensemble_test_scaffold.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('creates app-local starter test file', () {
    final dir = Directory.systemTemp.createTempSync('ensemble_scaffold_');
    addTearDown(() => dir.deleteSync(recursive: true));
    _writeApp(dir);

    final result = EnsembleTestScaffold(dir.path).create([
      '--scaffold-test=login_valid',
      '--feature=login',
      '--tag=smoke',
      '--screen=Login',
    ]);

    expect(result.created, isTrue);
    final file =
        File('${dir.path}/ensemble/apps/inhome/tests/login_valid.test.yaml');
    expect(file.existsSync(), isTrue);
    final content = file.readAsStringSync();
    expect(content, contains('id: login_valid'));
    expect(content, contains('feature: login'));
    expect(content, contains('tags: [smoke]'));
    expect(content, contains('startScreen: Login'));
    expect(
        Directory('${dir.path}/ensemble/apps/inhome/tests/mocks').existsSync(),
        isTrue);
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
View:
  body:
    Text:
      testId: title
''');
}
