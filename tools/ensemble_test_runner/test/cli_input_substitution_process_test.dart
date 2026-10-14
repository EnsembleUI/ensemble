import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test(
    'forwards CLI inputs through the separate Flutter process',
    () async {
      final root = Directory.systemTemp.createTempSync('cli_input_process_');
      addTearDown(() => root.deleteSync(recursive: true));
      final app = Directory(p.join(root.path, 'app'))..createSync();
      final tests = Directory(p.join(app.path, 'tests'))..createSync();
      final entry = Directory(p.join(app.path, 'test'))..createSync();
      final fakeBin = Directory(p.join(root.path, 'bin'))..createSync();
      final capturedArguments = File(p.join(root.path, 'flutter-args.txt'));

      File(p.join(app.path, 'pubspec.yaml')).writeAsStringSync('''
name: cli_input_process_fixture
environment:
  sdk: ">=3.5.0 <4.0.0"
flutter:
  assets:
    - tests/
''');
      File(p.join(tests.path, 'input.test.yaml')).writeAsStringSync('''
id: input_case
startScreen: Home
steps:
  - expectVisible:
      id: ready
''');
      File(p.join(entry.path, 'application_tests.dart')).writeAsStringSync('''
void main() {
  runApplicationTests();
}
''');

      final fakeFlutter = File(p.join(fakeBin.path, 'flutter'));
      fakeFlutter.writeAsStringSync(r'''
#!/bin/sh
printf '%s\n' "$@" >> "$ENSEMBLE_TEST_CAPTURE_ARGS"
if [ "$1" = "test" ]; then
  printf '%s\n' 'ENSEMBLE_TEST_JSON_REPORT:{"results":[]}'
fi
''');
      await Process.run('chmod', ['+x', fakeFlutter.path]);

      final packageRoot = Directory.current.path;
      final result = await Process.run(
        'dart',
        [
          'run',
          'bin/ensemble_test.dart',
          '--app-dir=${app.path}',
          '--tests-dir=tests',
          '--test-entry=test/application_tests.dart',
          '--mode=widget',
          '--jobs=1',
          '--report=json',
          '--input',
          'password=secret=with-equals',
          '--input=expectedCount=2',
          '--input=enabled=true',
        ],
        workingDirectory: packageRoot,
        environment: {
          ...Platform.environment,
          'PATH': '${fakeBin.path}:'
              '${Platform.environment['PATH'] ?? ''}',
          'ENSEMBLE_TEST_CAPTURE_ARGS': capturedArguments.path,
        },
      );

      expect(
        result.exitCode,
        0,
        reason: '${result.stdout}\n${result.stderr}',
      );
      expect(capturedArguments.existsSync(), isTrue);
      final args = capturedArguments.readAsLinesSync();
      expect(args, contains('test'));
      expect(args, isNot(contains('--input')));
      final encodedInput = args.firstWhere(
          (arg) => arg.startsWith('--dart-define=ensembleTestInputs='));
      final encoded = encodedInput.substring(
        '--dart-define=ensembleTestInputs='.length,
      );
      expect(
        jsonDecode(utf8.decode(base64Url.decode(encoded))),
        {
          'password': 'secret=with-equals',
          'expectedCount': 2,
          'enabled': true,
        },
      );
    },
    skip: Platform.isWindows ? 'Uses a POSIX fake Flutter executable.' : false,
  );
}
