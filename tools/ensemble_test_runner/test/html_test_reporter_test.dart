import 'dart:convert';
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

  test(
      'writes index.html with summary, failed tests first, and screenshot gallery',
      () {
    final screenshotsDir = Directory(p.join(tempDir.path, 'screenshots'))
      ..createSync(recursive: true);
    File(p.join(screenshotsDir.path, 'login_flow_step0_0.png'))
        .writeAsBytesSync([137, 80, 78, 71, 13, 10, 26, 10]);
    File(p.join(screenshotsDir.path, 'login_flow_frames.json'))
        .writeAsStringSync(
      jsonEncode({
        'status': 'failed',
        'failedStepIndex': 1,
        'frames': [
          {
            'stepIndex': 0,
            'label': '1. enterText(email_field)',
            'file': 'login_flow_step0_0.png',
          },
          {
            'stepIndex': 1,
            'label': '2. tap(login_button)',
            'file': 'login_flow_step1_0.png',
            'failed': true,
          },
        ],
      }),
    );
    File(p.join(screenshotsDir.path, 'login_flow_step1_0.png'))
        .writeAsBytesSync([137, 80, 78, 71, 13, 10, 26, 10]);
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
            stepDurationsMs: [85],
          ),
        ),
        EnsembleSingleTestResult.failed(
          testId: 'login_flow  (tests/login.test.yaml)',
          durationMs: 3400,
          failedStepIndex: 1,
          error: 'Timed out waiting for dashboard',
          logs: [
            'screenshots: $displayRoot/screenshots/login_flow_frames.json',
            'screenshotFrames: $displayRoot/screenshots/login_flow_frames.json',
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
            stepDurationsMs: [120, 3280],
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
    expect(html, contains('step-duration'));
    expect(html, contains('85ms'));
    expect(html, contains('3.3s'));
    expect(html, contains('screenshot-gallery'));
    expect(html, contains('../screenshots/login_flow_step0_0.png'));
    expect(html, contains('../screenshots/login_flow_step1_0.png'));
    expect(html, isNot(contains('../screenshots/login_flow_frames.json')));
    expect(html, contains('screenshot-gallery-tile failed'));
    expect(html, isNot(contains('../logs/login_flow_api_calls.json')));
    expect(html, isNot(contains('../logs/login_flow_storage.json')));
    expect(html, isNot(contains('../logs/login_flow_app_console.log')));
    expect(html, contains('apiCalls'));
    expect(html, contains('storage'));
    expect(html, contains('appLogs'));
    expect(html, isNot(contains('../logs/api_calls.json')));

    // Failed test appears before passed test.
    expect(
      html.indexOf('login_flow'),
      lessThan(html.indexOf('ok_home')),
    );
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
    expect(html, isNot(contains('bad<script>')));
    expect(html, contains('&lt;script&gt;'));
    expect(html, contains('&lt;img src=x'));
  });

  test('Step Details groups API/console by stepIndex', () {
    const displayRoot = 'build/ensemble_test_runner';
    final logsDir = Directory(p.join(tempDir.path, 'logs'))
      ..createSync(recursive: true);
    File(p.join(logsDir.path, 'nav_wait_api_calls.json')).writeAsStringSync(
      jsonEncode({
        'events': [
          {
            'name': 'login',
            'timestamp': '2026-07-22T12:00:00.050',
            'stepIndex': 1,
          },
        ],
      }),
    );
    File(p.join(logsDir.path, 'nav_wait_app_console.log')).writeAsStringSync(
      '[2026-07-22T12:00:00.050][step=1] during wait\n',
    );

    final html = HtmlTestReporter().buildHtml(
      EnsembleTestRunResult(
        results: [
          EnsembleSingleTestResult.passed(
            testId: 'nav_wait',
            durationMs: 500,
            logs: [
              'apiCalls: $displayRoot/logs/nav_wait_api_calls.json',
              'appLogs: $displayRoot/logs/nav_wait_app_console.log',
            ],
            report: const EnsembleTestReportDetails(
              startScreen: 'Login',
              endScreen: 'Home',
              stepsOutline: ['tap(login)', 'waitForNavigation(Home)'],
              stepDurationsMs: [100, 400],
              // Mismatched times so timestamp fallback would put logs on step 0.
              stepStartTimes: [
                '2026-07-22T12:00:00.000',
                '2026-07-22T12:00:10.000',
              ],
            ),
          ),
        ],
      ),
      artifactRoot: tempDir.path,
      displayRoot: displayRoot,
    );

    expect(html, contains('"name":"login"'));
    expect(html, contains('during wait'));
    // First step bucket empty; second has the attributed events.
    expect(html, contains('"storageChanges":[]'));
    expect(
      html,
      contains('"apiCalls":[{"name":"login"'),
    );
  });

  test('Step Details groups storage diffs by stepIndex with change kinds', () {
    const displayRoot = 'build/ensemble_test_runner';
    final logsDir = Directory(p.join(tempDir.path, 'logs'))
      ..createSync(recursive: true);
    File(p.join(logsDir.path, 'store_step_storage.json')).writeAsStringSync(
      jsonEncode({
        'keys': {'token': 'abc', 'count': 2},
        'steps': [
          {
            'stepIndex': 1,
            'timestamp': '2026-07-22T12:00:01.000',
            'changes': [
              {'key': 'token', 'change': 'added', 'after': 'abc'},
              {
                'key': 'count',
                'change': 'modified',
                'before': 1,
                'after': 2,
              },
            ],
          },
        ],
      }),
    );
    File(p.join(logsDir.path, 'store_step_app_console.log'))
        .writeAsStringSync('<no console output>\n');
    File(p.join(logsDir.path, 'store_step_api_calls.json'))
        .writeAsStringSync('{"events":[]}');

    final html = HtmlTestReporter().buildHtml(
      EnsembleTestRunResult(
        results: [
          EnsembleSingleTestResult.passed(
            testId: 'store_step',
            durationMs: 400,
            logs: [
              'apiCalls: $displayRoot/logs/store_step_api_calls.json',
              'storage: $displayRoot/logs/store_step_storage.json',
              'appLogs: $displayRoot/logs/store_step_app_console.log',
            ],
            report: const EnsembleTestReportDetails(
              startScreen: 'Home',
              stepsOutline: ['tap(a)', 'setStorage(token)'],
              stepDurationsMs: [100, 300],
              stepStartTimes: [
                '2026-07-22T12:00:00.000',
                '2026-07-22T12:00:01.000',
              ],
            ),
          ),
        ],
      ),
      artifactRoot: tempDir.path,
      displayRoot: displayRoot,
    );

    expect(html, contains('switchModalTab(\'storage\')'));
    expect(html, contains('"change":"added"'));
    expect(html, contains('"change":"modified"'));
    expect(html, contains('"key":"token"'));
    // End-of-test panel shows keys snapshot (HTML-escaped).
    expect(html, contains('&quot;token&quot;: &quot;abc&quot;'));
    expect(html, isNot(contains('&quot;steps&quot;:')));
  });

  test('Step Details embeds per-step screenshot hrefs from frames.json', () {
    const displayRoot = 'build/ensemble_test_runner';
    final logsDir = Directory(p.join(tempDir.path, 'logs'))
      ..createSync(recursive: true);
    final shotsDir = Directory(p.join(tempDir.path, 'screenshots'))
      ..createSync(recursive: true);
    File(p.join(shotsDir.path, 'shot_nav_step1_0.png'))
        .writeAsBytesSync([4, 5, 6]);
    File(p.join(shotsDir.path, 'shot_nav_frames.json')).writeAsStringSync(
      jsonEncode({
        'frames': [
          {
            'stepIndex': 1,
            'label': '2. waitForNavigation(Home)',
            'file': 'shot_nav_step1_0.png',
          },
        ],
      }),
    );
    File(p.join(logsDir.path, 'shot_nav_app_console.log'))
        .writeAsStringSync('<no console output>\n');
    File(p.join(logsDir.path, 'shot_nav_api_calls.json'))
        .writeAsStringSync('{"events":[]}');

    final html = HtmlTestReporter().buildHtml(
      EnsembleTestRunResult(
        results: [
          EnsembleSingleTestResult.passed(
            testId: 'shot_nav',
            durationMs: 400,
            logs: [
              'apiCalls: $displayRoot/logs/shot_nav_api_calls.json',
              'appLogs: $displayRoot/logs/shot_nav_app_console.log',
              'screenshots: $displayRoot/screenshots/shot_nav_frames.json',
              'screenshotFrames: $displayRoot/screenshots/shot_nav_frames.json',
            ],
            report: const EnsembleTestReportDetails(
              startScreen: 'Login',
              stepsOutline: ['tap(login)', 'waitForNavigation(Home)'],
              stepDurationsMs: [100, 300],
              stepStartTimes: [
                '2026-07-22T12:00:00.000',
                '2026-07-22T12:00:01.000',
              ],
            ),
          ),
        ],
      ),
      artifactRoot: tempDir.path,
      displayRoot: displayRoot,
    );

    expect(html, contains('switchModalTab(\'screenshots\')'));
    expect(html, contains('data-tab="screenshots"'));
    expect(html, contains('../screenshots/shot_nav_step1_0.png'));
    expect(html, contains('"screenshots":[]'));
    expect(
      html,
      contains('"file":"shot_nav_step1_0.png"'),
    );
  });
}
