import 'dart:io';

import 'package:ensemble_test_runner/runner/test_app_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory appDir;

  setUp(() {
    appDir = Directory.systemTemp.createTempSync('test_app_metadata_');
    Directory('${appDir.path}/ensemble').createSync();
    File('${appDir.path}/pubspec.yaml').writeAsStringSync('''
name: sports_wrapper
version: 0.1.0+7
''');
    File('${appDir.path}/ensemble/ensemble.properties').writeAsStringSync('''
appId=com.example.sports
appName=Sports
''');
    TestAppMetadata.setVersionOverrideForTest(null);
  });

  tearDown(() {
    TestAppMetadata.setVersionOverrideForTest(null);
    appDir.deleteSync(recursive: true);
  });

  test('uses host package version by default', () {
    expect(TestAppMetadata.packageInfo(appDir.path)['version'], '0.1.0');
  });

  test('uses an app version override for host-driven tests', () {
    TestAppMetadata.setVersionOverrideForTest('8.95.0');

    expect(TestAppMetadata.packageInfo(appDir.path)['version'], '8.95.0');
  });

  test('clearing the override restores host package version', () {
    TestAppMetadata.setVersionOverrideForTest('8.95.0');
    TestAppMetadata.setVersionOverrideForTest(null);

    expect(TestAppMetadata.packageInfo(appDir.path)['version'], '0.1.0');
  });
}
