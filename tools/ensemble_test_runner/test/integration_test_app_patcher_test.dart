import 'dart:io';

import 'package:ensemble_test_runner/cli/app_patcher.dart';
import 'package:ensemble_test_runner/cli/app_platform_support.dart';
import 'package:ensemble_test_runner/cli/entry_source_transformer.dart';
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

    final patcher = TestAppPatcher(dir.path);
    patcher.enable(mode: ExecutionMode.integration);

    expect(
      File('${dir.path}/pubspec.yaml').readAsStringSync(),
      contains('integration_test:'),
    );
    final entry = File(
      '${dir.path}/${TestAppPatcher.integrationTestEntryRelativePath}',
    );
    expect(
      entry.readAsStringSync(),
      contains('runEnsembleIntegrationTests'),
    );

    patcher.restore();
    expect(File('${dir.path}/pubspec.yaml').readAsStringSync(), pubspec);
    expect(entry.existsSync(), isFalse);
  });

  test('integration rollback preserves a pre-existing empty adapter file', () {
    final dir = Directory.systemTemp.createTempSync('integration_empty_');
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
    File('${dir.path}/test/ensemble_tests.dart')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('void main() { runApplicationTests(); }');
    final adapter = File(
      '${dir.path}/${TestAppPatcher.integrationTestEntryRelativePath}',
    )..createSync(recursive: true);

    final patcher = TestAppPatcher(
      dir.path,
      testEntryRelativePath: 'test/ensemble_tests.dart',
    );
    patcher.enable(mode: ExecutionMode.integration);
    expect(adapter.readAsStringSync(), isNotEmpty);

    patcher.restore();
    expect(adapter.existsSync(), isTrue);
    expect(adapter.readAsStringSync(), isEmpty);
  });

  test('custom entry symlink cannot make the patcher read outside the app', () {
    final dir = Directory.systemTemp.createTempSync('integration_entry_link_');
    final outside =
        Directory.systemTemp.createTempSync('integration_entry_target_');
    addTearDown(() => dir.deleteSync(recursive: true));
    addTearDown(() => outside.deleteSync(recursive: true));
    const pubspec = 'name: sample_app\nflutter:\n  assets: []\n';
    File('${dir.path}/pubspec.yaml').writeAsStringSync(pubspec);
    File('${outside.path}/application_tests.dart').writeAsStringSync(
      'Future<void> main() => runApplicationTests();',
    );
    Directory('${dir.path}/test').createSync();
    Link('${dir.path}/test/application_tests.dart')
        .createSync('${outside.path}/application_tests.dart');

    final patcher = TestAppPatcher(
      dir.path,
      testEntryRelativePath: 'test/application_tests.dart',
    );
    expect(() => patcher.enable(), throwsStateError);
    expect(File('${dir.path}/pubspec.yaml').readAsStringSync(), pubspec);
    expect(
      File('${outside.path}/application_tests.dart').readAsStringSync(),
      'Future<void> main() => runApplicationTests();',
    );
  });

  test('pubspec symlink is rejected before patcher mutations', () {
    final dir =
        Directory.systemTemp.createTempSync('integration_pubspec_link_');
    final outside =
        Directory.systemTemp.createTempSync('integration_pubspec_target_');
    addTearDown(() => dir.deleteSync(recursive: true));
    addTearDown(() => outside.deleteSync(recursive: true));
    const pubspec = 'name: sample_app\nflutter:\n  assets: []\n';
    File('${outside.path}/pubspec.yaml').writeAsStringSync(pubspec);
    Link('${dir.path}/pubspec.yaml').createSync('${outside.path}/pubspec.yaml');

    final patcher = TestAppPatcher(dir.path);
    expect(() => patcher.enable(), throwsStateError);
    expect(
      File('${outside.path}/pubspec.yaml').readAsStringSync(),
      pubspec,
    );
    expect(File('${dir.path}/test/ensemble_tests.dart').existsSync(), isFalse);
  });

  test('integration entry symlink cannot write outside the app', () {
    final dir = Directory.systemTemp.createTempSync('integration_output_link_');
    final outside =
        Directory.systemTemp.createTempSync('integration_output_target_');
    addTearDown(() => dir.deleteSync(recursive: true));
    addTearDown(() => outside.deleteSync(recursive: true));
    const pubspec = 'name: sample_app\nflutter:\n  assets: []\n';
    File('${dir.path}/pubspec.yaml').writeAsStringSync(pubspec);
    Directory('${dir.path}/test').createSync();
    File('${dir.path}/test/application_tests.dart').writeAsStringSync(
      'Future<void> main() => runApplicationTests();',
    );
    Link('${dir.path}/integration_test').createSync(outside.path);

    final patcher = TestAppPatcher(
      dir.path,
      testEntryRelativePath: 'test/application_tests.dart',
    );
    expect(
      () => patcher.enable(mode: ExecutionMode.integration),
      throwsStateError,
    );
    expect(File('${dir.path}/pubspec.yaml').readAsStringSync(), pubspec);
    expect(
      File('${outside.path}/application_tests.dart').existsSync(),
      isFalse,
    );
  });

  test('generated integration entry rejects external widget source symlinks',
      () {
    final dir =
        Directory.systemTemp.createTempSync('integration_widget_source_link_');
    final outside =
        Directory.systemTemp.createTempSync('integration_widget_source_');
    addTearDown(() => dir.deleteSync(recursive: true));
    addTearDown(() => outside.deleteSync(recursive: true));
    const pubspec = 'name: sample_app\nflutter:\n  assets: []\n';
    const widgetEntry = 'Future<void> main() => runEnsembleTests();\n';
    File('${dir.path}/pubspec.yaml').writeAsStringSync(pubspec);
    File('${outside.path}/ensemble_tests.dart').writeAsStringSync(widgetEntry);
    Link('${dir.path}/test').createSync(outside.path);

    final patcher = TestAppPatcher(dir.path);
    expect(
      () => patcher.enable(mode: ExecutionMode.integration),
      throwsStateError,
    );

    expect(File('${dir.path}/pubspec.yaml').readAsStringSync(), pubspec);
    expect(
      File('${outside.path}/ensemble_tests.dart').readAsStringSync(),
      widgetEntry,
    );
    expect(
      Directory('${dir.path}/integration_test').existsSync(),
      isFalse,
    );
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
    File('${dir.path}/${TestAppPatcher.testEntryRelativePath}')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('''
import 'package:ensemble_test_runner/entry/ensemble_test_entry.dart';
import 'package:sample_app/generated/ensemble_modules.dart';
import 'package:sample_app/main.dart' as starter;

Future<void> main() async {
  await runEnsembleTests(
    bootstrap: () => EnsembleModules().init(),
    externalMethods: {
      'captureCertificateForHost': starter.captureCertificateForHost,
    },
  );
}
''');

    final patcher = TestAppPatcher(dir.path);
    patcher.enable(mode: ExecutionMode.integration);
    final entry = File(
      '${dir.path}/${TestAppPatcher.integrationTestEntryRelativePath}',
    ).readAsStringSync();
    expect(entry, contains('runEnsembleIntegrationTests'));
    expect(entry, isNot(contains('runEnsembleTests(')));
    expect(entry, contains('ensemble_integration_test_entry.dart'));
    expect(entry, contains('captureCertificateForHost'));
    expect(
        entry, contains("import 'package:sample_app/main.dart' as starter;"));
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
      '${dir.path}/${TestAppPatcher.integrationTestEntryRelativePath}',
    ).writeAsStringSync('''
// Wrong entry — mentions the name only in a comment:
// runEnsembleIntegrationTests
void main() {}
''');
    const podfile = "# platform :ios, '13.0'\n";
    File('${dir.path}/ios/Podfile')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(podfile);
    File('${dir.path}/ios/Runner.xcodeproj/project.pbxproj')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('IPHONEOS_DEPLOYMENT_TARGET = 13.0;\n');

    final patcher = TestAppPatcher(dir.path);
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
        '${dir.path}/${TestAppPatcher.integrationTestEntryRelativePath}',
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

    final patcher = TestAppPatcher(dir.path);
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

      final patcher = TestAppPatcher(dir.path);
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

    final patcher = TestAppPatcher(dir.path);
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
      EntrySourceTransformer.entryPointCallsFunction(
        '// runEnsembleIntegrationTests()\nvoid main() {}',
        'runEnsembleIntegrationTests',
      ),
      isFalse,
    );
    expect(
      EntrySourceTransformer.entryPointCallsFunction(
        '/* runEnsembleIntegrationTests() */\nvoid main() {}',
        'runEnsembleIntegrationTests',
      ),
      isFalse,
    );
    expect(
      EntrySourceTransformer.entryPointCallsFunction(
        'Future<void> main() async {\n  await runEnsembleIntegrationTests();\n}',
        'runEnsembleIntegrationTests',
      ),
      isTrue,
    );
    expect(
      EntrySourceTransformer.entryPointCallsFunction(
        "const marker = 'runEnsembleIntegrationTests()';\nvoid main() {}",
        'runEnsembleIntegrationTests',
      ),
      isFalse,
    );
  });

  test('entry point validation checks candidates in one match pass', () {
    const candidates = ['runApp', 'runApplicationIntegrationTests'];
    expect(
      EntrySourceTransformer.entryPointCallsAny(
        '// runApp()\nFuture<void> main() => runApplicationIntegrationTests();',
        candidates,
      ),
      isTrue,
    );
    expect(
      EntrySourceTransformer.entryPointCallsAny(
        '// runApp()\nvoid main() {}',
        candidates,
      ),
      isFalse,
    );
    expect(
      EntrySourceTransformer.entryPointCallsAny('void main() {}', const []),
      isFalse,
    );
  });

  test('iOS deployment helpers raise below 15 and leave higher versions', () {
    expect(
      AppPlatformSupport.raisePodfilePlatform("# platform :ios, '13.0'\n"),
      "platform :ios, '15.0'\n",
    );
    expect(
      AppPlatformSupport.raisePodfilePlatform("platform :ios, '16.0'\n"),
      "platform :ios, '16.0'\n",
    );
    expect(
      AppPlatformSupport.raisePbxprojDeploymentTarget(
        'IPHONEOS_DEPLOYMENT_TARGET = 13.0;',
      ),
      'IPHONEOS_DEPLOYMENT_TARGET = 15.0;',
    );
    expect(
      AppPlatformSupport.iosVersionLessThan('13.0', '15.0'),
      isTrue,
    );
    expect(
      AppPlatformSupport.iosVersionLessThan('15.0', '15.0'),
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
        AppPlatformSupport.enableGradleKtsCoreLibraryDesugaring(kts);
    expect(patchedKts, contains('isCoreLibraryDesugaringEnabled = true'));
    expect(patchedKts, contains('desugar_jdk_libs:2.1.4'));
    expect(
      AppPlatformSupport.enableGradleKtsCoreLibraryDesugaring(patchedKts),
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
        AppPlatformSupport.enableGradleGroovyCoreLibraryDesugaring(groovy);
    expect(patchedGroovy, contains('coreLibraryDesugaringEnabled true'));
    expect(patchedGroovy, contains("desugar_jdk_libs:2.1.4"));
  });
}
