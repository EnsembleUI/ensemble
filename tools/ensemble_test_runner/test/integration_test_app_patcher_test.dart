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

  test('integration entry keeps custom widget bootstrap helpers', () {
    final dir = Directory.systemTemp.createTempSync('integration_adapt_');
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
    File('${dir.path}/${YamlTestAppPatcher.testEntryRelativePath}')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('''
import 'package:ensemble_test_runner/entry/ensemble_test_entry.dart';
import 'package:sample_app/generated/ensemble_modules.dart';
import 'package:sample_app/main.dart' as starter;

Future<void> main() async {
  await runEnsembleYamlTests(
    bootstrap: () => EnsembleModules().init(),
    externalMethods: {
      'captureCertificateForHost': starter.captureCertificateForHost,
    },
  );
}
''');

    final patcher = YamlTestAppPatcher(dir.path);
    patcher.enable(mode: ExecutionMode.integration);
    final entry = File(
      '${dir.path}/${YamlTestAppPatcher.integrationTestEntryRelativePath}',
    ).readAsStringSync();
    expect(entry, contains('runEnsembleIntegrationYamlTests'));
    expect(entry, isNot(contains('runEnsembleYamlTests(')));
    expect(entry, contains('ensemble_integration_test_entry.dart'));
    expect(entry, contains('captureCertificateForHost'));
    expect(entry, contains("import 'package:sample_app/main.dart' as starter;"));
    patcher.restore();
  });

  test('failed enable leaves customer files unchanged', () {
    final dir = Directory.systemTemp.createTempSync('integration_fail_');
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
    Directory('${dir.path}/integration_test').createSync(recursive: true);
    File(
      '${dir.path}/${YamlTestAppPatcher.integrationTestEntryRelativePath}',
    ).writeAsStringSync('''
// Wrong entry — mentions the name only in a comment:
// runEnsembleIntegrationYamlTests
void main() {}
''');
    const podfile = "# platform :ios, '13.0'\n";
    File('${dir.path}/ios/Podfile')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(podfile);
    File('${dir.path}/ios/Runner.xcodeproj/project.pbxproj')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('IPHONEOS_DEPLOYMENT_TARGET = 13.0;\n');

    final patcher = YamlTestAppPatcher(dir.path);
    expect(
      () => patcher.enable(mode: ExecutionMode.integration),
      throwsStateError,
    );

    expect(File('${dir.path}/pubspec.yaml').readAsStringSync(), pubspec);
    expect(
      File('${dir.path}/ios/Podfile').readAsStringSync(),
      podfile,
    );
    expect(
      File('${dir.path}/ios/Runner.xcodeproj/project.pbxproj')
          .readAsStringSync(),
      'IPHONEOS_DEPLOYMENT_TARGET = 13.0;\n',
    );
    expect(
      File(
        '${dir.path}/${YamlTestAppPatcher.integrationTestEntryRelativePath}',
      ).readAsStringSync(),
      contains('void main() {}'),
    );
  });

  test('integration mode rejects low iOS deployment without rewriting', () {
    final dir = Directory.systemTemp.createTempSync('integration_ios_');
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
    const podfile = '''
# Uncomment this line to define a global platform for your project
# platform :ios, '13.0'
''';
    File('${dir.path}/ios/Podfile')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(podfile);
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
    expect(
      () => patcher.enable(
        mode: ExecutionMode.integration,
        targetPlatform: 'ios',
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('iOS deployment target'),
        ),
      ),
    );
    expect(File('${dir.path}/pubspec.yaml').readAsStringSync(), pubspec);
    expect(File('${dir.path}/ios/Podfile').readAsStringSync(), podfile);
    expect(
      File('${dir.path}/ios/Runner.xcodeproj/project.pbxproj')
          .readAsStringSync(),
      'IPHONEOS_DEPLOYMENT_TARGET = 13.0;\n',
    );
  });

  test(
    'android integration enable skips iOS deployment gate with low Podfile',
    () {
      final dir = Directory.systemTemp.createTempSync('integration_android_');
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
      const podfile = "# platform :ios, '13.0'\n";
      File('${dir.path}/ios/Podfile')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(podfile);

      final patcher = YamlTestAppPatcher(dir.path);
      expect(
        () => patcher.enable(
          mode: ExecutionMode.integration,
          targetPlatform: 'android',
        ),
        returnsNormally,
      );
      expect(File('${dir.path}/ios/Podfile').readAsStringSync(), podfile);
      patcher.restore();
    },
  );

  test('opt-in fix raises the iOS deployment target then restores it', () {
    final dir = Directory.systemTemp.createTempSync('integration_ios_fix_');
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
    patcher.enable(
      mode: ExecutionMode.integration,
      targetPlatform: 'ios',
      fixIosDeploymentTarget: true,
    );

    expect(
      File('${dir.path}/ios/Podfile').readAsStringSync(),
      contains("platform :ios, '15.0'"),
    );
    expect(
      File('${dir.path}/ios/Runner.xcodeproj/project.pbxproj')
          .readAsStringSync(),
      contains('IPHONEOS_DEPLOYMENT_TARGET = 15.0;'),
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

  test('entry point validation ignores comments', () {
    expect(
      YamlTestAppPatcher.entryPointCallsFunction(
        '// runEnsembleIntegrationYamlTests()\nvoid main() {}',
        'runEnsembleIntegrationYamlTests',
      ),
      isFalse,
    );
    expect(
      YamlTestAppPatcher.entryPointCallsFunction(
        '/* runEnsembleIntegrationYamlTests() */\nvoid main() {}',
        'runEnsembleIntegrationYamlTests',
      ),
      isFalse,
    );
    expect(
      YamlTestAppPatcher.entryPointCallsFunction(
        'Future<void> main() async {\n  await runEnsembleIntegrationYamlTests();\n}',
        'runEnsembleIntegrationYamlTests',
      ),
      isTrue,
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

  test('Android Gradle helpers enable core library desugaring', () {
    const kts = '''
android {
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
}
''';
    final patchedKts =
        YamlTestAppPatcher.enableGradleKtsCoreLibraryDesugaring(kts);
    expect(patchedKts, contains('isCoreLibraryDesugaringEnabled = true'));
    expect(patchedKts, contains('desugar_jdk_libs:2.1.4'));
    expect(
      YamlTestAppPatcher.enableGradleKtsCoreLibraryDesugaring(patchedKts),
      patchedKts,
    );

    const groovy = '''
android {
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }
}
''';
    final patchedGroovy =
        YamlTestAppPatcher.enableGradleGroovyCoreLibraryDesugaring(groovy);
    expect(patchedGroovy, contains('coreLibraryDesugaringEnabled true'));
    expect(patchedGroovy, contains("desugar_jdk_libs:2.1.4"));
  });
}
