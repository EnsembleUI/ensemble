import 'package:flutter_test/flutter_test.dart';

import 'support/dart_process.dart';

void main() {
  test('CLI help exits before inspecting the app or starting workers',
      () async {
    final result = await runDartScript(
      'bin/ensemble_test.dart',
      arguments: const [
        '--app-dir=/path/that/does/not/exist',
        '--help',
      ],
    );

    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    expect(result.stdout, contains('Usage: ensemble test [options]'));
    expect('${result.stdout}\n${result.stderr}', isNot(contains('Running')));
  });

  test('compiled worker plan batch runs in a plain Dart process', () async {
    final result = await runDartScript(
      'test/support/cli_plan_batch_plain_dart.dart',
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
    final result = await runDartScript(
      'bin/ensemble_test.dart',
      arguments: const [
        '--app-dir=example_host',
        '--tests-dir=tests',
        '--test-entry=test/application_tests.dart',
        '--validate-only',
      ],
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
