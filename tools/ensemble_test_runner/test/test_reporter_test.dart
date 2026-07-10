import 'package:ensemble/framework/screen_tracker.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/yaml_test_session.dart';
import 'package:ensemble_test_runner/reporters/test_reporter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatStepBrief', () {
    test('formats id-based steps', () {
      expect(
        formatStepBrief(const TestStep(type: 'tap', args: {'id': 'btn'})),
        'tap(btn)',
      );
      expect(
        formatStepBrief(const TestStep(
          type: 'trigger',
          args: {'action': 'onTap', 'id': 'nav'},
        )),
        'trigger(onTap nav)',
      );
    });
  });

  group('collectScreensVisited', () {
    test('reads navigation flow including back navigation', () {
      YamlTestSession.navigationFlow
          .seed(['Hello Home', 'Goodbye', 'Hello Home']);

      expect(
        collectScreensVisited('Hello Home'),
        ['Hello Home', 'Goodbye', 'Hello Home'],
      );
    });

    test('beginTest starts a fresh report flow for continuation tests',
        () async {
      YamlTestSession.navigationFlow.seed([
        'Login',
        'InitApp',
        'AutoSignIn',
        'AutoSignIn_Gateway',
        'Home',
      ]);

      YamlTestSession.navigationFlow.beginTest('Home');
      YamlTestSession.navigationFlow.recordScreenChange(
        VisibleScreen(screenName: 'Devices', visibleSince: DateTime.now()),
      );
      await YamlTestSession.navigationFlow.flushPending();
      YamlTestSession.navigationFlow.recordScreenChange(
        VisibleScreen(screenName: 'Home', visibleSince: DateTime.now()),
      );
      await YamlTestSession.navigationFlow.flushPending();
      YamlTestSession.navigationFlow.recordScreenChange(
        VisibleScreen(
            screenName: 'Settings_Wifi', visibleSince: DateTime.now()),
      );
      await YamlTestSession.navigationFlow.flushPending();
      YamlTestSession.navigationFlow.recordScreenChange(
        VisibleScreen(screenName: 'Home', visibleSince: DateTime.now()),
      );
      await YamlTestSession.navigationFlow.flushPending();

      expect(
        collectScreensVisited('Home'),
        ['Home', 'Devices', 'Home', 'Settings_Wifi', 'Home'],
      );
    });
  });

  group('TestReporter', () {
    test('includes file, flow, and steps on pass', () {
      final report = EnsembleTestReportDetails(
        startScreen: 'Hello Home',
        endScreen: 'Hello Home',
        screensVisited: ['Hello Home', 'Goodbye', 'Hello Home'],
        stepsOutline: [
          'expectVisible(greeting_text)',
          'trigger(onTap navigate_button)',
        ],
      );
      final output = TestReporter().formatSummary(
        EnsembleTestRunResult(
          results: [
            EnsembleSingleTestResult.passed(
              testId: 'hello_home_renders',
              durationMs: 610,
              report: report,
            ),
          ],
        ),
        testFile: 'ensemble/tests/hello_home.test.yaml',
      );

      expect(output, contains('hello_home.test.yaml'));
      expect(output, contains('hello_home_renders'));
      expect(output, contains('Hello Home → Goodbye → Hello Home'));
      expect(output, contains('expectVisible(greeting_text)'));
      expect(output, contains('1 passed, 0 failed'));
      expect(output, contains('610ms total'));
    });

    test('marks failed step in outline', () {
      final report = EnsembleTestReportDetails(
        startScreen: 'Login',
        stepsOutline: ['tap(email)', 'tap(submit)'],
      );
      final output = TestReporter().formatSummary(
        EnsembleTestRunResult(
          results: [
            EnsembleSingleTestResult.failed(
              testId: 'login',
              durationMs: 100,
              failedStepIndex: 1,
              failedStep: const TestStep(type: 'tap', args: {'id': 'submit'}),
              error: 'not found',
              report: report,
            ),
          ],
        ),
      );

      expect(output, contains('>> 2. tap(submit)'));
      expect(output, contains('error: not found'));
    });

    test('prints step logs', () {
      final output = TestReporter().formatSummary(
        EnsembleTestRunResult(
          results: [
            EnsembleSingleTestResult.passed(
              testId: 'api_log_test',
              durationMs: 42,
              logs: const ['API getCompleteSchedules x1'],
            ),
          ],
        ),
      );

      expect(output, contains('logs:'));
      expect(output, contains('API getCompleteSchedules x1'));
    });
  });
}
