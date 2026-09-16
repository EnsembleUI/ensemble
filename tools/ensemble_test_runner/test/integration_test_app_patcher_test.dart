import 'dart:io';

import 'package:ensemble_test_runner/cli/yaml_test_app_patcher.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('integration mode adds dependency and entry then restores both', () {
    final dir = Directory.systemTemp.createTempSync('integration_patcher_');
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
    Directory('${dir.path}/ensemble/apps/hello/tests')
        .createSync(recursive: true);
    File('${dir.path}/ensemble/ensemble-config.yaml')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('''
definitions:
  local:
    path: ensemble/apps/hello
    appHome: Home
''');
    File('${dir.path}/ensemble/apps/hello/tests/home.test.yaml')
        .writeAsStringSync('id: home\nstartScreen: Home\nsteps: []\n');

    final patcher = YamlTestAppPatcher(dir.path);
    patcher.enable(mode: ExecutionMode.integration);

    expect(
      File('${dir.path}/pubspec.yaml').readAsStringSync(),
      contains('integration_test:'),
    );
    final entry = File(
      '${dir.path}/${YamlTestAppPatcher.integrationTestEntryRelativePath}',
    );
    expect(
      entry.readAsStringSync(),
      contains('runEnsembleIntegrationYamlTests'),
    );

    patcher.restore();
    expect(File('${dir.path}/pubspec.yaml').readAsStringSync(), pubspec);
    expect(entry.existsSync(), isFalse);
  });

  test('integration mode raises the iOS deployment target then restores it',
      () {
    final dir = Directory.systemTemp.createTempSync('integration_ios_');
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
    Directory('${dir.path}/ensemble/apps/hello/tests')
        .createSync(recursive: true);
    File('${dir.path}/ensemble/ensemble-config.yaml')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('''
definitions:
  local:
    path: ensemble/apps/hello
    appHome: Home
''');
    File('${dir.path}/ensemble/apps/hello/tests/home.test.yaml')
        .writeAsStringSync('id: home\nstartScreen: Home\nsteps: []\n');
    File('${dir.path}/ios/Podfile')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('''
# Uncomment this line to define a global platform for your project
# platform :ios, '13.0'
''');
    File('${dir.path}/ios/Runner.xcodeproj/project.pbxproj')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('IPHONEOS_DEPLOYMENT_TARGET = 13.0;\n');
    File('${dir.path}/ios/Flutter/AppFrameworkInfo.plist')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('''
<key>MinimumOSVersion</key>
<string>13.0</string>
''');

    final patcher = YamlTestAppPatcher(dir.path);
    patcher.enable(mode: ExecutionMode.integration);

    expect(
      File('${dir.path}/ios/Podfile').readAsStringSync(),
      contains("platform :ios, '15.0'"),
    );
    expect(
      File('${dir.path}/ios/Podfile').readAsStringSync(),
      isNot(contains("# platform :ios, '13.0'")),
    );
    expect(
      File('${dir.path}/ios/Runner.xcodeproj/project.pbxproj')
          .readAsStringSync(),
      contains('IPHONEOS_DEPLOYMENT_TARGET = 15.0;'),
    );
    expect(
      File('${dir.path}/ios/Flutter/AppFrameworkInfo.plist').readAsStringSync(),
      contains('<string>15.0</string>'),
    );

    patcher.restore();
    expect(
      File('${dir.path}/ios/Podfile').readAsStringSync(),
      contains("# platform :ios, '13.0'"),
    );
    expect(
      File('${dir.path}/ios/Runner.xcodeproj/project.pbxproj')
          .readAsStringSync(),
      contains('IPHONEOS_DEPLOYMENT_TARGET = 13.0;'),
    );
  });

  test('iOS deployment helpers raise below 15 and leave higher versions', () {
    expect(
      YamlTestAppPatcher.raisePodfilePlatform("# platform :ios, '13.0'\n"),
      "platform :ios, '15.0'\n",
    );
    expect(
      YamlTestAppPatcher.raisePodfilePlatform("platform :ios, '16.0'\n"),
      "platform :ios, '16.0'\n",
    );
    expect(
      YamlTestAppPatcher.raisePbxprojDeploymentTarget(
        'IPHONEOS_DEPLOYMENT_TARGET = 13.0;',
      ),
      'IPHONEOS_DEPLOYMENT_TARGET = 15.0;',
    );
    expect(
      YamlTestAppPatcher.iosVersionLessThan('13.0', '15.0'),
      isTrue,
    );
    expect(
      YamlTestAppPatcher.iosVersionLessThan('15.0', '15.0'),
      isFalse,
    );
  });
}
