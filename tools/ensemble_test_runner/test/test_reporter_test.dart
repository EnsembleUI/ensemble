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
        stepDurationsMs: const [42, 118],
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
      expect(output, contains('expectVisible(greeting_text) (42ms)'));
      expect(output, contains('trigger(onTap navigate_button) (118ms)'));
      expect(output, contains('1 passed, 0 failed'));
      expect(output, contains('610ms total'));
    });

    test('marks failed step in outline', () {
      final report = EnsembleTestReportDetails(
        startScreen: 'Login',
        stepsOutline: ['tap(email)', 'tap(submit)'],
        stepDurationsMs: const [10, 55],
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

      expect(output, contains('>> 2. tap(submit) (55ms)'));
      expect(output, contains('error: not found'));
    });

    test('report JSON includes stepDurationsMs', () {
      const report = EnsembleTestReportDetails(
        startScreen: 'Home',
        stepsOutline: ['waitFor(a)', 'tap(b)'],
        stepDurationsMs: [12, 34],
      );
      expect(report.toJson()['stepDurationsMs'], [12, 34]);
    });

    test('prints retry attempts when a test needed retry', () {
      final output = TestReporter().formatSummary(
        EnsembleTestRunResult(
          results: [
            EnsembleSingleTestResult.passed(
              testId: 'signin_to_gateway',
              durationMs: 1200,
              attempts: 2,
              retry: 3,
            ),
          ],
        ),
      );

      expect(output, contains('attempts: 2/4'));
    });

    test('omits transient sidecar paths folded into the HTML report', () {
      final output = TestReporter().formatSummary(
        EnsembleTestRunResult(
          results: [
            EnsembleSingleTestResult.passed(
              testId: 'api_log_test',
              durationMs: 42,
              logs: const [
                'apiCalls: build/ensemble_test_runner/logs/api_log_test_api_calls.json',
                'storage: build/ensemble_test_runner/logs/api_log_test_storage.json',
                'appLogs: build/ensemble_test_runner/logs/api_log_test_app_console.log',
                'screenshots: build/ensemble_test_runner/screenshots/api_log_test_frames.json',
                'screenshotFrames: build/ensemble_test_runner/screenshots/api_log_test_frames.json',
                'dumpTree: build/ensemble_test_runner/logs/api_log_test_dump_tree.txt',
              ],
            ),
          ],
          suiteLogs: const [
            'htmlReport: build/ensemble_test_runner/report/index.html',
            'results: build/ensemble_test_runner/report/results.json.gz',
            'appPerformance: build/ensemble_test_runner/logs/app_performance.json',
          ],
        ),
      );

      expect(output, isNot(contains('│     artifacts:')));
      expect(output, isNot(contains('apiCalls:')));
      expect(output, isNot(contains('appLogs:')));
      expect(output, isNot(contains('screenshotFrames:')));
      expect(output, isNot(contains('appPerformance:')));
      expect(output, contains('suite artifacts:'));
      expect(output, contains('htmlReport:'));
      expect(output, contains('results:'));
    });

    test('prints durable suite logs separately from test logs', () {
      final output = TestReporter().formatSummary(
        EnsembleTestRunResult(
          results: [
            EnsembleSingleTestResult.passed(
              testId: 'login_test',
              durationMs: 42,
            ),
          ],
          suiteLogs: const [
            'htmlReport: build/ensemble_test_runner/report/index.html',
            'results: build/ensemble_test_runner/report/results.json.gz',
          ],
        ),
      );

      expect(output, contains('suite artifacts:'));
      expect(
        output,
        contains('htmlReport: build/ensemble_test_runner/report/index.html'),
      );
      expect(
        output,
        contains('results: build/ensemble_test_runner/report/results.json.gz'),
      );
    });

    test('formats compact failure summary without repeating boxed report', () {
      final output = TestReporter().formatFailureSummary(
        EnsembleTestRunResult(
          results: [
            EnsembleSingleTestResult.failed(
              testId:
                  'login_test  (ensemble/apps/inhome/tests/signin.test.yaml)',
              durationMs: 100,
              failedStep: const TestStep(
                type: 'waitForNavigation',
                args: {'screen': 'Home'},
              ),
              error: 'Timed out waiting for navigation',
            ),
            EnsembleSingleTestResult.failed(
              testId:
                  'smoke_navigations  (ensemble/apps/inhome/tests/smoke.test.yaml)',
              durationMs: 0,
              error: 'Prerequisite "login_test" failed',
            ),
          ],
        ),
        failedPaths: const [
          'ensemble/apps/inhome/tests/signin.test.yaml',
          'ensemble/apps/inhome/tests/smoke.test.yaml',
        ],
        pendingFrameworkExceptions: const [
          'Reentrant call to runAsync() denied.\nextra framework text',
        ],
      );

      expect(output, contains('Failed YAML tests (2/2):'));
      expect(output, contains('Timed out waiting for navigation'));
      expect(output, contains('failed: waitForNavigation(Home)'));
      expect(output, contains('Pending Flutter framework exceptions:'));
      expect(output, contains('Reentrant call to runAsync() denied.'));
      expect(output, contains('See the Ensemble YAML tests report above.'));
      expect(output, isNot(contains('┌─ Ensemble YAML tests')));
      expect(output, isNot(contains('extra framework text')));
    });
  });
}
