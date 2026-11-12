import 'dart:convert';
import 'dart:io';

import 'package:ensemble_test_runner/cli/cli_worker_workspace.dart';
import 'package:ensemble_test_runner/cli/test_timer_rewriter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('prepares and removes an isolated linked worker', () {
    final app = Directory.systemTemp.createTempSync('cli_worker_workspace_');
    addTearDown(() => app.deleteSync(recursive: true));
    File('${app.path}/pubspec.yaml').writeAsStringSync('''
name: sample
dependencies:
  local_dep:
    path: ../local_dep
''');
    File('${app.path}/main.dart').writeAsStringSync('void main() {}');
    Directory('${app.path}/test').createSync();
    File('${app.path}/test/entry.dart').writeAsStringSync(
      "import 'helper.dart';\nvoid main() => helper();\n",
    );
    File('${app.path}/test/helper.dart').writeAsStringSync('void helper() {}');
    Directory('${app.path}/.dart_tool').createSync();
    File('${app.path}/.dart_tool/package_config.json').writeAsStringSync(
      json.encode({
        'configVersion': 2,
        'packages': [
          {'name': 'sample', 'rootUri': '../'},
          {'name': 'local_dep', 'rootUri': '../../local_dep'},
        ],
      }),
    );

    final timerPlan = TestTimerRewritePlan.forApp(
      appDir: app.path,
      testsDirRelative: 'tests',
    );
    final workspace = CliWorkerWorkspace(app.path);
    final worker = Directory(workspace.prepare(
      0,
      timerPlan,
      testEntryRelativePath: 'test/entry.dart',
    ));

    expect(worker.existsSync(), isTrue);
    expect(Link('${worker.path}/main.dart').existsSync(), isTrue);
    expect(Link('${worker.path}/test').existsSync(), isFalse);
    expect(File('${worker.path}/test/entry.dart').existsSync(), isTrue);
    expect(File('${worker.path}/test/helper.dart').existsSync(), isTrue);
    expect(
      File('${worker.path}/test/entry.dart').readAsStringSync(),
      contains("import 'helper.dart'"),
    );
    expect(
      File('${worker.path}/pubspec.yaml').readAsStringSync(),
      contains('path: "${Directory(app.path).parent.path}/local_dep"'),
    );
    final packageConfig = json.decode(
      File('${worker.path}/.dart_tool/package_config.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    expect(
      (packageConfig['packages'] as List).every(
        (entry) => Uri.parse((entry as Map)['rootUri'] as String).isAbsolute,
      ),
      isTrue,
    );

    final kernelCache = File('${worker.path}/build/test_cache/runner.dill')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('compiled');
    final frontendCache =
        File('${worker.path}/.dart_tool/flutter_build/frontend.cache')
          ..parent.createSync(recursive: true)
          ..writeAsStringSync('frontend');
    File('${worker.path}/worker-transient.txt').writeAsStringSync('temporary');

    workspace.clean();
    expect(worker.existsSync(), isFalse);
    expect(kernelCache.existsSync(), isFalse);
    expect(frontendCache.existsSync(), isFalse);
  });

  test('copies platform projects for isolated integration builds', () {
    final app = Directory.systemTemp.createTempSync('cli_worker_platforms_');
    addTearDown(() => app.deleteSync(recursive: true));
    File('${app.path}/pubspec.yaml').writeAsStringSync('name: sample\n');
    for (final path in [
      '.dart_tool/package_config.json',
      'android/gradle.properties',
      'android/app/build.gradle',
      'android/local.properties',
      'android/.gradle/cache.bin',
      'android/app/build/cache.bin',
      'ios/Runner.xcodeproj/project.pbxproj',
      'ios/Pods/Manifest.lock',
      'ios/Flutter/Generated.xcconfig',
      'ios/build/cache.bin',
    ]) {
      final file = File('${app.path}/$path')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync('fixture');
      if (path == '.dart_tool/package_config.json') {
        file.writeAsStringSync(json.encode({
          'configVersion': 2,
          'packages': [
            {'name': 'sample', 'rootUri': '../'},
          ],
        }));
      } else if (path == 'android/gradle.properties') {
        file.writeAsStringSync(
          'org.gradle.jvmargs=-Xmx8G -XX:MaxMetaspaceSize=4G\n',
        );
      }
    }

    final workspace = CliWorkerWorkspace(app.path);
    final workerPath = workspace.prepare(
      0,
      TestTimerRewritePlan.forApp(
        appDir: app.path,
        testsDirRelative: null,
      ),
      testEntryRelativePath: 'test/entry.dart',
      copyPlatformProjects: true,
    );
    addTearDown(workspace.clean);

    expect(Link('$workerPath/android').existsSync(), isFalse);
    expect(File('$workerPath/android/app/build.gradle').existsSync(), isTrue);
    expect(File('$workerPath/android/local.properties').existsSync(), isTrue);
    expect(
      File('$workerPath/android/gradle.properties').readAsStringSync(),
      contains('org.gradle.jvmargs=-Xmx3G -XX:MaxMetaspaceSize=1G'),
    );
    expect(
      File('${app.path}/android/gradle.properties').readAsStringSync(),
      'org.gradle.jvmargs=-Xmx8G -XX:MaxMetaspaceSize=4G\n',
    );
    expect(Directory('$workerPath/android/.gradle').existsSync(), isFalse);
    expect(
        File('$workerPath/android/app/build/cache.bin').existsSync(), isFalse);
    expect(Link('$workerPath/ios').existsSync(), isFalse);
    expect(
        File('$workerPath/ios/Runner.xcodeproj/project.pbxproj').existsSync(),
        isTrue);
    expect(File('$workerPath/ios/Flutter/Generated.xcconfig').existsSync(),
        isTrue);
    expect(Directory('$workerPath/ios/Pods').existsSync(), isFalse);
    expect(File('$workerPath/ios/build/cache.bin').existsSync(), isFalse);
  });

  test('removes partial worker files when preparation fails', () {
    final app = Directory.systemTemp.createTempSync('cli_worker_failed_');
    addTearDown(() => app.deleteSync(recursive: true));
    File('${app.path}/pubspec.yaml').writeAsStringSync('name: sample\n');
    File('${app.path}/main.dart').writeAsStringSync('void main() {}');
    Directory('${app.path}/.dart_tool').createSync();
    File('${app.path}/.dart_tool/package_config.json')
        .writeAsStringSync('{ invalid json');

    final workspace = CliWorkerWorkspace(app.path);
    final workerPath = workspace.directory(0);
    expect(
      () => workspace.prepare(
        0,
        TestTimerRewritePlan.forApp(
          appDir: app.path,
          testsDirRelative: null,
        ),
        testEntryRelativePath: 'test/entry.dart',
      ),
      throwsFormatException,
    );

    expect(Directory(workerPath).existsSync(), isFalse);
    expect(File('${app.path}/main.dart').readAsStringSync(), 'void main() {}');
  });

  test('recovers stale package config after an interrupted worker run', () {
    final app = Directory.systemTemp.createTempSync('cli_worker_stale_');
    addTearDown(() => app.deleteSync(recursive: true));
    File('${app.path}/pubspec.yaml').writeAsStringSync('name: sample\n');
    File('${app.path}/main.dart').writeAsStringSync('void main() {}');
    Directory('${app.path}/.dart_tool').createSync();
    File('${app.path}/.dart_tool/package_config.json').writeAsStringSync(
      json.encode({
        'configVersion': 2,
        'packages': [
          {'name': 'sample', 'rootUri': '../'},
        ],
      }),
    );

    final workspace = CliWorkerWorkspace(app.path);
    final staleWorker = Directory(workspace.directory(0));
    File('${staleWorker.path}/.dart_tool/stale.json')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('stale');
    final reusableCache = File('${staleWorker.path}/build/cache/kernel.dill')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync('compiled');

    final workerPath = workspace.prepare(
      0,
      TestTimerRewritePlan.forApp(
        appDir: app.path,
        testsDirRelative: null,
      ),
      testEntryRelativePath: 'test/entry.dart',
    );
    addTearDown(workspace.clean);

    expect(File('$workerPath/.dart_tool/package_config.json').existsSync(),
        isTrue);
    expect(File('$workerPath/.dart_tool/stale.json').existsSync(), isFalse);
    expect(reusableCache.readAsStringSync(), 'compiled');
  });

  test('rebases an absolute app package root without moving external roots',
      () {
    final app = Directory.systemTemp.createTempSync('cli_worker_absolute_');
    addTearDown(() => app.deleteSync(recursive: true));
    File('${app.path}/pubspec.yaml').writeAsStringSync('name: sample\n');
    Directory('${app.path}/.dart_tool').createSync();
    final external =
        Directory.systemTemp.createTempSync('cli_worker_external_');
    addTearDown(() => external.deleteSync(recursive: true));
    File('${app.path}/.dart_tool/package_config.json').writeAsStringSync(
      json.encode({
        'configVersion': 2,
        'packages': [
          {
            'name': 'sample',
            'rootUri': Directory(app.path).absolute.uri.toString()
          },
          {'name': 'external', 'rootUri': external.absolute.uri.toString()},
        ],
      }),
    );

    final timerPlan = TestTimerRewritePlan.forApp(
      appDir: app.path,
      testsDirRelative: 'tests',
    );
    final workspace = CliWorkerWorkspace(app.path);
    final workerPath = workspace.prepare(
      0,
      timerPlan,
      testEntryRelativePath: 'test/entry.dart',
    );
    addTearDown(workspace.clean);
    final packages = (json.decode(
      File('$workerPath/.dart_tool/package_config.json').readAsStringSync(),
    ) as Map<String, dynamic>)['packages'] as List;
    final roots = {
      for (final entry in packages)
        (entry as Map)['name'] as String: (entry['rootUri'] as String),
    };

    expect(p.normalize(Uri.parse(roots['sample']!).toFilePath()),
        p.normalize(workerPath));
    expect(roots['external'], external.absolute.uri.toString());
  });
}
