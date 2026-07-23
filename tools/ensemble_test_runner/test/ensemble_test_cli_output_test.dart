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

  test('extractSuiteReport can omit streamed screen tracker lines', () {
    const noisy = '''
SCREEN TRACKER: Login
┌─ Ensemble YAML tests ─────────────────────────────
│  ✓ login_test
└─ 1 passed, 0 failed (1 total) · 653ms total
''';

    expect(
      extractSuiteReport(noisy, includeScreenTracker: false),
      '''┌─ Ensemble YAML tests ─────────────────────────────
│  ✓ login_test
└─ 1 passed, 0 failed (1 total) · 653ms total
''',
    );
  });

  test('flutterTestArguments strips CLI-only flags', () {
    expect(
      flutterTestArguments([
        '--app-dir=foo',
        '--verbose',
        '--quiet',
        '--doctor',
        '--inspect-app',
        '--validate-only',
        '--scaffold-test=login',
        '--report=json',
        '--report-file=build/results.json',
        '--id=login',
        '--feature=auth',
        '--tag=smoke',
        '--path=auth/',
        '--timeout=30s',
        '--input',
        'adminPassword=s4C>M7U6t~',
        '--input=expectedDeviceCount=2',
        '--name',
        'x',
      ]),
      ['--name', 'x'],
    );
  });

  test('extractJunitReport reads escaped marker line', () {
    expect(
      extractJunitReport(
        'noise\nENSEMBLE_TEST_JUNIT_REPORT:<testsuite>\\n</testsuite>\\n',
      ),
      '<testsuite>\n</testsuite>\n',
    );
  });

  test('extractJsonReport reads marker line', () {
    expect(
      extractJsonReport(
          'noise\nENSEMBLE_TEST_JSON_REPORT:{"status":"passed"}\n'),
      '{"status":"passed"}',
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

  test('extractKnownFailure keeps actionable EnsembleTestFailure message', () {
    const noisy = '''
══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════════════════════════════
The following EnsembleTestFailure was thrown running a test:
Missing CLI input "password". Pass it with --input password=value.

When the exception was thrown, this was the stack:
#0      EnsembleTestParser._placeholderValue
════════════════════════════════════════════════════════════════════════════════
''';

    expect(
      extractKnownFailure(noisy),
      'Missing CLI input "password". Pass it with --input password=value.',
    );
  });

  test('live output filter emits app logs before final report only', () {
    final filter = LiveFlutterTestOutputFilter();

    expect(filter.shouldEmit('SCREEN TRACKER: Login'), isTrue);
    expect(
        filter.shouldEmit('DEBUG [InitApp] token stored successfully'), isTrue);
    expect(
      filter.shouldEmit('ENSEMBLE_TEST_JSON_REPORT:{"status":"passed"}'),
      isFalse,
    );
    expect(
      filter.shouldEmit(
        '(The following exception is now available via WidgetTester.takeException:)',
      ),
      isFalse,
    );
    expect(filter.shouldEmit('┌─ Ensemble YAML tests ─────'), isFalse);
    expect(filter.shouldEmit('SCREEN TRACKER: Home'), isFalse);
  });

  test('live output filter suppresses framework exception noise', () {
    final filter = LiveFlutterTestOutputFilter();

    expect(filter.shouldEmit('SCREEN TRACKER: Login'), isTrue);
    expect(
      filter.shouldEmit(
        '══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞════════',
      ),
      isFalse,
    );
    expect(filter.shouldEmit('The following TestFailure was thrown'), isFalse);
  });

  test('live output filter suppresses widget exception noise', () {
    final filter = LiveFlutterTestOutputFilter();

    expect(filter.shouldEmit('SCREEN TRACKER: Login'), isTrue);
    expect(
      filter.shouldEmit('══╡ EXCEPTION CAUGHT BY WIDGETS LIBRARY ╞══════'),
      isFalse,
    );
    expect(
      filter
          .shouldEmit('A RadioButtonController was used after being disposed.'),
      isFalse,
    );
  });
}
