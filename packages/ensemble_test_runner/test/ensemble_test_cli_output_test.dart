import 'package:ensemble_test_runner/cli/ensemble_test_cli_output.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('extractSuiteReport keeps screen tracker and boxed summary', () {
    const noisy = '''
00:00 +0: loading test/ensemble_tests.dart
SCREEN TRACKER: Hello Home
name is ={first: John}
┌─ Ensemble YAML tests ─────────────────────────────
│  ✓ hello_home_renders
└─ 5 passed, 0 failed (5 total) · 653ms total

00:00 +1: All tests passed!
''';

    expect(
      extractSuiteReport(noisy),
      '''SCREEN TRACKER: Hello Home
┌─ Ensemble YAML tests ─────────────────────────────
│  ✓ hello_home_renders
└─ 5 passed, 0 failed (5 total) · 653ms total
''',
    );
  });

  test('flutterTestArguments strips CLI-only flags', () {
    expect(
      flutterTestArguments([
        '--app-dir=foo',
        '--verbose',
        '--quiet',
        '--name',
        'x',
      ]),
      ['--name', 'x'],
    );
  });

  test('extractKnownFailure keeps no-tests message only', () {
    const noisy = '''
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════
The following EnsembleTestFailure was thrown running a test:
No declarative tests found. Add *.test.yaml files under ensemble/apps/inhome/tests/

When the exception was thrown, this was the stack:
#0      EnsembleTestExecutionPlanner.build
The test description was:
  Ensemble app *.test.yaml
════════════════════════════════════════════════════════════════════════════════
''';

    expect(
      extractKnownFailure(noisy),
      'No declarative tests found. Add *.test.yaml files under ensemble/apps/inhome/tests/',
    );
  });
}
