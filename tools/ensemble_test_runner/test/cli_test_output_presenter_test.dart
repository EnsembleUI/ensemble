import 'package:ensemble_test_runner/cli/cli_test_output_presenter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CliTestOutputPresenter', () {
    test('keeps running events internal and formats completed outcomes', () {
      expect(
        CliTestOutputPresenter.progressLine({
          'status': 'running',
          'testId': 'checkout',
        }),
        isNull,
      );
      expect(
        CliTestOutputPresenter.progressLine({
          'status': 'passed',
          'testId': 'checkout  (iphone)',
          'durationMs': 1250,
        }),
        '✓ checkout (1.3s)',
      );
      expect(
        CliTestOutputPresenter.progressLine({
          'status': 'failed',
          'testId': 'login',
          'durationMs': 4,
          'message': 'network timeout',
        }),
        '✗ login (4ms): network timeout',
      );
    });

    test('selects machine reports before the boxed report', () {
      const output = '''
┌─ Ensemble tests
ENSEMBLE_TEST_JSON_REPORT:{"status":"passed"}
└─
''';

      expect(
        CliTestOutputPresenter.selectReport(
          output,
          jsonReport: true,
          junitReport: false,
          machineReport: true,
          streamLiveOutput: false,
        ),
        '{"status":"passed"}',
      );
    });

    test('suppresses reports when machine mode has no selected marker', () {
      expect(
        CliTestOutputPresenter.selectReport(
          'ordinary flutter output',
          jsonReport: false,
          junitReport: false,
          machineReport: true,
          streamLiveOutput: false,
        ),
        isNull,
      );
    });

    test('returns the boxed report for human output', () {
      const output = '''
┌─ Ensemble tests
│  ✓ checkout (10ms)
└─
''';

      expect(
        CliTestOutputPresenter.selectReport(
          output,
          jsonReport: false,
          junitReport: false,
          machineReport: false,
          streamLiveOutput: false,
        ),
        contains('Ensemble tests'),
      );
    });
  });
}
