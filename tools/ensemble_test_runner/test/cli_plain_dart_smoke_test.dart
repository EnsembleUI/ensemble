import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CLI help exits before inspecting the app or starting workers',
      () async {
    final result = await Process.run(
      'dart',
      const [
        'run',
        'bin/ensemble_test.dart',
        '--app-dir=/path/that/does/not/exist',
        '--help',
      ],
      workingDirectory: Directory.current.path,
    );

    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(result.stdout, contains('Usage: ensemble test [options]'));
    expect('${result.stdout}\n${result.stderr}', isNot(contains('Running')));
  });

  test('compiled worker plan batch runs in a plain Dart process', () async {
    final result = await Process.run(
      'dart',
      const ['run', 'test/support/cli_plan_batch_plain_dart.dart'],
      workingDirectory: Directory.current.path,
    );

    expect(
      result.exitCode,
      0,
      reason: '${result.stdout}\n${result.stderr}',
    );
    expect(result.stdout, contains('plain Dart compiled plan batch passed'));
    expect('${result.stdout}\n${result.stderr}', isNot(contains('dart:ui')));
  });

  test('CLI plan handoff imports and validates without Flutter symbols',
      () async {
    final packageRoot = Directory.current.path;
    final result = await Process.run(
      'dart',
      const [
        'run',
        'bin/ensemble_test.dart',
        '--app-dir=example_host',
        '--tests-dir=tests',
        '--test-entry=test/application_tests.dart',
        '--validate-only',
      ],
      workingDirectory: packageRoot,
    );

    expect(
      result.exitCode,
      0,
      reason: '${result.stdout}\n${result.stderr}',
    );
    expect(result.stdout, contains('Ensemble test validation passed'));
    expect('${result.stdout}\n${result.stderr}', isNot(contains('dart:ui')));
  });
}
