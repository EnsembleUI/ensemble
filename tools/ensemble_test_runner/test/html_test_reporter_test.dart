import 'dart:io';

import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/reporters/html_test_reporter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('ensemble_html_report_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('writes index.html with summary, failed tests first, and screenshot links',
      () {
    final screenshotsDir = Directory(p.join(tempDir.path, 'screenshots'))
      ..createSync(recursive: true);
    final screenshot = File(p.join(screenshotsDir.path, 'login_flow.png'))
      ..writeAsBytesSync([137, 80, 78, 71, 13, 10, 26, 10]);
    final logsDir = Directory(p.join(tempDir.path, 'logs'))
      ..createSync(recursive: true);
    final apiCalls = File(p.join(logsDir.path, 'login_flow_api_calls.json'))
      ..writeAsStringSync('{"calls":[]}');
    final storage = File(p.join(logsDir.path, 'login_flow_storage.json'))
      ..writeAsStringSync('{"token":"abc"}');
    final appLogs = File(p.join(logsDir.path, 'login_flow_app_console.log'))
      ..writeAsStringSync('SCREEN TRACKER: Login\n');

    const displayRoot = 'build/ensemble_test_runner';
    final result = EnsembleTestRunResult(
      results: [
        EnsembleSingleTestResult.passed(
          testId: 'ok_home  (tests/ok.test.yaml)',
          durationMs: 1200,
          logs: [
            'appLogs: $displayRoot/logs/ok_home_app_console.log',
          ],
          report: const EnsembleTestReportDetails(
            startScreen: 'Home',
            stepsOutline: ['expectVisible(title)'],
          ),
        ),
        EnsembleSingleTestResult.failed(
          testId: 'login_flow  (tests/login.test.yaml)',
          durationMs: 3400,
          failedStepIndex: 1,
          error: 'Timed out waiting for dashboard',
          logs: [
            'screenshots: $displayRoot/screenshots/login_flow.png',
            'apiCalls: $displayRoot/logs/login_flow_api_calls.json',
            'storage: $displayRoot/logs/login_flow_storage.json',
            'appLogs: $displayRoot/logs/login_flow_app_console.log',
          ],
          report: const EnsembleTestReportDetails(
            startScreen: 'Login',
            endScreen: 'Login',
            stepsOutline: [
              'enterText(email_field)',
              'tap(login_button)',
            ],
          ),
        ),
      ],
      suiteLogs: const [
        'htmlReport: build/ensemble_test_runner/report/index.html',
      ],
    );

    File(p.join(logsDir.path, 'ok_home_app_console.log'))
        .writeAsStringSync('<no console output>\n');

    final reporter = HtmlTestReporter();
    final displayPath = reporter.write(
      result,
      artifactRoot: tempDir.path,
      displayRoot: displayRoot,
    );
    expect(displayPath, '$displayRoot/report/index.html');

    final htmlFile = File(p.join(tempDir.path, 'report', 'index.html'));
    expect(htmlFile.existsSync(), isTrue);
    final html = htmlFile.readAsStringSync();

    expect(html, contains('1 passed, 1 failed (2 total)'));
    expect(html, contains('login_flow'));
    expect(html, contains('ok_home'));
    expect(html, contains('Timed out waiting for dashboard'));
    expect(html, contains('failed-step'));
    expect(html, contains('../screenshots/login_flow.png'));
    expect(html, contains('../logs/login_flow_api_calls.json'));
    expect(html, contains('../logs/login_flow_storage.json'));
    expect(html, contains('../logs/login_flow_app_console.log'));
    expect(html, contains('apiCalls'));
    expect(html, contains('storage'));
    expect(html, contains('appLogs'));
    expect(html, isNot(contains('../logs/api_calls.json')));

    // Failed test appears before passed test.
    expect(
      html.indexOf('login_flow'),
      lessThan(html.indexOf('ok_home')),
    );
    expect(screenshot.existsSync(), isTrue);
    expect(apiCalls.existsSync(), isTrue);
    expect(storage.existsSync(), isTrue);
    expect(appLogs.existsSync(), isTrue);
  });

  test('buildHtml escapes untrusted text', () {
    final html = HtmlTestReporter().buildHtml(
      EnsembleTestRunResult(
        results: [
          EnsembleSingleTestResult.failed(
            testId: 'bad<script>',
            durationMs: 1,
            error: '<img src=x onerror=alert(1)>',
          ),
        ],
      ),
      artifactRoot: tempDir.path,
      displayRoot: 'build/ensemble_test_runner',
    );
    expect(html, isNot(contains('<script>')));
    expect(html, contains('&lt;script&gt;'));
    expect(html, contains('&lt;img src=x'));
  });
}
