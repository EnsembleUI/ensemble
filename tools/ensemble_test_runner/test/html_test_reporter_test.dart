import 'dart:convert';
import 'dart:io';

import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/reporters/html_test_reporter.dart';
import 'package:ensemble_test_runner/reporters/report_json_optimizer.dart';
import 'package:ensemble_test_runner/reporters/test_report_document.dart';
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

  Map<String, dynamic> readExpandedResults() {
    final reportDir = Directory(p.join(tempDir.path, 'report'));
    expect(
      File(p.join(reportDir.path, TestReportDocument.resultsFileName))
          .existsSync(),
      isTrue,
    );
    expect(File(p.join(reportDir.path, 'results.json')).existsSync(), isFalse);
    return TestReportDocument.readResults(reportDir);
  }

  Map<String, dynamic> readRawOptimized() {
    final file =
        File(p.join(tempDir.path, 'report', TestReportDocument.resultsFileName));
    final jsonText = utf8.decode(gzip.decode(file.readAsBytesSync()));
    return json.decode(jsonText) as Map<String, dynamic>;
  }

  test('suite start writes shell + loading results without rewriting later',
      () {
    const displayRoot = 'build/ensemble_test_runner';
    final reporter = HtmlTestReporter();

    final htmlPath = reporter.write(
      const EnsembleTestRunResult(results: []),
      artifactRoot: tempDir.path,
      displayRoot: displayRoot,
      isSuiteRunning: true,
      wallTimeMs: 0,
    );
    expect(htmlPath, '$displayRoot/report/index.html');

    final htmlFile = File(p.join(tempDir.path, 'report', 'index.html'));
    expect(htmlFile.existsSync(), isTrue);
    final shell = htmlFile.readAsStringSync();
    expect(shell, contains('results.json.gz'));
    expect(shell, contains("fetch('results.json.gz"));
    expect(shell, contains('DecompressionStream'));
    expect(shell, contains('report-loader'));
    expect(shell, isNot(contains('ensembleHtmlTestReportAppJs')));
    expect(shell, contains('pollAndRender'));
    expect(shell.length, lessThan(200000));
    expect(File(p.join(tempDir.path, 'report', 'results.js')).existsSync(),
        isFalse);

    final loading = readExpandedResults();
    expect(loading['state'], 'loading');
    expect(loading['tests'], isEmpty);

    final shellBefore = shell;
    final mtimeBefore = htmlFile.lastModifiedSync();

    Directory(p.join(tempDir.path, 'logs')).createSync(recursive: true);
    File(p.join(tempDir.path, 'logs', 'ok_app_console.log'))
        .writeAsStringSync('done\n');

    reporter.writeResultsOnly(
      EnsembleTestRunResult(
        results: [
          EnsembleSingleTestResult.passed(
            testId: 'ok',
            durationMs: 100,
            logs: ['appLogs: $displayRoot/logs/ok_app_console.log'],
            report: const EnsembleTestReportDetails(
              startScreen: 'Home',
              stepsOutline: ['expectVisible(title)'],
              stepDurationsMs: [50],
            ),
          ),
        ],
      ),
      artifactRoot: tempDir.path,
      displayRoot: displayRoot,
    );

    expect(htmlFile.readAsStringSync(), shellBefore);
    expect(
      htmlFile.lastModifiedSync().isBefore(
              mtimeBefore.add(const Duration(seconds: 1))) ||
          htmlFile.readAsStringSync() == shellBefore,
      isTrue,
    );

    final complete = readExpandedResults();
    expect(complete['state'], 'complete');
    expect(complete['tests'], hasLength(1));
    expect(complete['tests'][0]['id'], 'ok');
    expect(complete['summary']['passed'], 1);
    expect(Directory(p.join(tempDir.path, 'logs')).existsSync(), isFalse);
  });

  test('complete results aggregate api/storage/console/screenshots/steps', () {
    final screenshotsDir = Directory(p.join(tempDir.path, 'screenshots'))
      ..createSync(recursive: true);
    File(p.join(screenshotsDir.path, 'login_flow_step0_0.png'))
        .writeAsBytesSync([137, 80, 78, 71, 13, 10, 26, 10]);
    File(p.join(screenshotsDir.path, 'login_flow_step1_0.png'))
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
    final logsDir = Directory(p.join(tempDir.path, 'logs'))
      ..createSync(recursive: true);
    File(p.join(logsDir.path, 'login_flow_api_calls.json')).writeAsStringSync(
      jsonEncode({
        'events': [
          {
            'name': 'login',
            'timestamp': '2026-07-22T12:00:00.050',
            'stepIndex': 1,
            'statusCode': 200,
            'mocked': true,
            'request': {
              'url': 'https://example.test/login',
              'method': 'POST',
              'headers': {'Content-Type': 'application/json'},
              'body': {'user': 'a', 'password': 'b'},
            },
            'responseBody': {
              'token': 'abc',
              'profile': {'id': 1, 'roles': ['admin', 'user']},
            },
          },
        ],
      }),
    );
    File(p.join(logsDir.path, 'login_flow_storage.json')).writeAsStringSync(
      jsonEncode({
        'keys': {'token': 'abc'},
        'steps': [
          {
            'stepIndex': 1,
            'timestamp': '2026-07-22T12:00:01.000',
            'changes': [
              {'key': 'token', 'change': 'added', 'after': 'abc'},
            ],
          },
        ],
      }),
    );
    File(p.join(logsDir.path, 'login_flow_app_console.log'))
        .writeAsStringSync('[2026-07-22T12:00:00.050][step=1] during wait\n');
    File(p.join(logsDir.path, 'ok_home_app_console.log'))
        .writeAsStringSync('<no console output>\n');

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
            stepStartTimes: [
              '2026-07-22T12:00:00.000',
              '2026-07-22T12:00:01.000',
            ],
          ),
        ),
      ],
    );

    final reporter = HtmlTestReporter();
    reporter.write(
      result,
      artifactRoot: tempDir.path,
      displayRoot: displayRoot,
    );

    final html = File(p.join(tempDir.path, 'report', 'index.html'))
        .readAsStringSync();
    expect(html, contains('results.json.gz'));
    expect(html, contains("fetch('results.json.gz"));
    expect(html, contains('switchModalTab(\'screenshots\')'));
    expect(html, isNot(contains('Timed out waiting for dashboard')));
    expect(html, isNot(contains('"name":"login"')));

    final doc = readExpandedResults();
    expect(doc['state'], 'complete');
    expect(doc['summary']['passed'], 1);
    expect(doc['summary']['failed'], 1);

    final tests = doc['tests'] as List;
    expect(tests.first['id'], contains('login_flow'));
    expect(tests.last['id'], contains('ok_home'));

    final failed = tests.first as Map<String, dynamic>;
    expect(failed['message'], 'Timed out waiting for dashboard');
    expect(failed.containsKey('api'), isFalse);
    expect(failed.containsKey('console'), isFalse);
    expect(failed.containsKey('screenshots'), isFalse);
    expect((failed['storage'] as Map).containsKey('steps'), isFalse);
    expect((failed['storage'] as Map)['keys']['token'], 'abc');

    final steps = failed['steps'] as List;
    expect(steps, hasLength(2));
    expect((steps[0] as Map)['apiCalls'], isEmpty);
    expect(((steps[1] as Map)['apiCalls'] as List).first['name'], 'login');
    expect(
      ((steps[1] as Map)['apiCalls'] as List).first['responseBody']['token'],
      'abc',
    );
    expect((steps[1] as Map)['appLogs'], isNotEmpty);
    expect(
      (steps[1] as Map)['appLogs'],
      contains('[2026-07-22T12:00:00.050][step=1] during wait'),
    );
    expect(
      ((steps[1] as Map)['storageChanges'] as List).first['change'],
      'added',
    );
    expect((steps[0] as Map)['screenshots'], isNotEmpty);
    final frames = (steps[0] as Map)['screenshots'] as List;
    expect(
        frames.first['href'], contains('../screenshots/login_flow_step0_0.png'));
    expect(((steps[1] as Map)['screenshots'] as List).first['failed'], isTrue);

    final raw = readRawOptimized();
    expect(raw.containsKey('blobs'), isTrue);
    final api = (((raw['tests'] as List).first as Map)['steps'] as List)[1]
        as Map<String, dynamic>;
    final ev = (api['apiCalls'] as List).first as Map<String, dynamic>;
    expect(ev['responseBody'], isA<Map>());
    expect((ev['responseBody'] as Map).containsKey(r'$b'), isTrue);

    expect(Directory(p.join(tempDir.path, 'logs')).existsSync(), isFalse);
    expect(
      File(p.join(screenshotsDir.path, 'login_flow_frames.json')).existsSync(),
      isFalse,
    );
    expect(
      File(p.join(screenshotsDir.path, 'login_flow_step0_0.png')).existsSync(),
      isTrue,
    );
  });

  test('buildHtml escapes untrusted text inside results payload', () {
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
    expect(html, isNot(contains('<img src=x')));

    final doc = readExpandedResults();
    final test = (doc['tests'] as List).first as Map<String, dynamic>;
    expect(test['id'], 'bad<script>');
    expect(test['message'], '<img src=x onerror=alert(1)>');
    expect(html, contains('function escapeHtml'));
  });

  test('optimizer dedupes repeated bodies and expand restores them', () {
    final body = {
      'status': List.generate(40, (i) => {'id': i, 'name': 'device_$i'}),
    };
    final doc = {
      'state': 'complete',
      'summary': {'passed': 1, 'failed': 0, 'pending': 0, 'totalMs': 1},
      'tests': [
        {
          'id': 't1',
          'baseId': 't1',
          'status': 'passed',
          'durationMs': 1,
          'attempts': 1,
          'retry': 0,
          'steps': [
            {
              'stepText': 'tap(a)',
              'apiCalls': [
                {
                  'name': 'a',
                  'responseBody': body,
                  'request': {'headers': {'A': '1'}, 'body': body},
                },
                {
                  'name': 'b',
                  'responseBody': body,
                  'request': {'headers': {'A': '1'}, 'body': body},
                },
              ],
              'appLogs': <String>[],
              'storageChanges': <Map<String, dynamic>>[],
              'screenshots': <Map<String, dynamic>>[],
            },
            {
              'stepText': '  nested(x)',
              'apiCalls': [
                {'name': 'a', 'responseBody': body},
              ],
              'appLogs': <String>[],
              'storageChanges': <Map<String, dynamic>>[],
              'screenshots': <Map<String, dynamic>>[],
            },
          ],
        },
      ],
    };

    final optimized = ReportJsonOptimizer.optimize(doc);
    expect(optimized['blobs'], isA<Map>());
    expect((optimized['blobs'] as Map).length, lessThan(5));
    final nested = (((optimized['tests'] as List).first as Map)['steps']
        as List)[1] as Map;
    expect(nested.containsKey('apiCalls'), isFalse);

    final expanded = ReportJsonOptimizer.expand(optimized);
    final steps = (expanded['tests'] as List).first['steps'] as List;
    expect(
      (steps[0] as Map)['apiCalls'][0]['responseBody'],
      body,
    );
    expect(
      (steps[1] as Map)['apiCalls'][0]['responseBody'],
      body,
    );
  });

  test('TestReportDocument loading and complete builders', () {
    final loading = TestReportDocument.buildLoading(wallTimeMs: 0);
    expect(loading['state'], 'loading');
    expect(loading['tests'], isEmpty);

    final dir = Directory(p.join(tempDir.path, 'report'))
      ..createSync(recursive: true);
    TestReportDocument.writeResults(dir, loading);
    expect(
      File(p.join(dir.path, TestReportDocument.resultsFileName)).existsSync(),
      isTrue,
    );
    expect(File(p.join(dir.path, 'results.json')).existsSync(), isFalse);
    expect(File(p.join(dir.path, 'results.js')).existsSync(), isFalse);

    final complete = TestReportDocument.buildComplete(
      EnsembleTestRunResult(
        results: [
          EnsembleSingleTestResult.passed(
            testId: 't1',
            durationMs: 10,
          ),
        ],
      ),
      artifactRoot: tempDir.path,
      displayRoot: 'build/ensemble_test_runner',
    );
    expect(complete['state'], 'complete');
    expect(complete['summary']['passed'], 1);
    expect((complete['tests'] as List).first['id'], 't1');
  });

  test('embeds dumpTree and appPerformance per test into results.json.gz', () {
    const displayRoot = 'build/ensemble_test_runner';
    final logsDir = Directory(p.join(tempDir.path, 'logs'))
      ..createSync(recursive: true);
    File(p.join(logsDir.path, 't1_app_performance.json')).writeAsStringSync(
      jsonEncode({
        'summary': {
          'totalFrames': 2,
          'jankyFrames': 1,
          'worstStep': 'tap(a)',
          'worstScreen': 'Home',
        },
        'worstSteps': [
          {
            'step': 'tap(a)',
            'stepIndex': 0,
            'screen': 'Home',
            'totalFrames': 2,
            'jankyFrames': 1,
            'maxTotalSpanMs': 22,
          },
        ],
        'frames': [
          {
            'frameNumber': 1,
            'stepIndex': 0,
            'screen': 'Home',
            'totalSpanMs': 8,
            'janky': false,
          },
          {
            'frameNumber': 2,
            'stepIndex': 0,
            'screen': 'Home',
            'totalSpanMs': 22,
            'janky': true,
          },
        ],
      }),
    );
    File(p.join(logsDir.path, 't1_dump_tree.txt'))
        .writeAsStringSync('MaterialApp\n  Scaffold\n');

    final reporter = HtmlTestReporter();
    reporter.write(
      EnsembleTestRunResult(
        results: [
          EnsembleSingleTestResult.passed(
            testId: 't1',
            durationMs: 10,
            logs: const [
              'appPerformance: $displayRoot/logs/t1_app_performance.json',
              'dumpTree: $displayRoot/logs/t1_dump_tree.txt',
            ],
            report: const EnsembleTestReportDetails(
              startScreen: 'Home',
              stepsOutline: ['tap(a)'],
              stepDurationsMs: [10],
            ),
          ),
        ],
      ),
      artifactRoot: tempDir.path,
      displayRoot: displayRoot,
    );

    expect(Directory(p.join(tempDir.path, 'logs')).existsSync(), isFalse);

    final doc = TestReportDocument.readResults(
      Directory(p.join(tempDir.path, 'report')),
    );
    expect(doc['suiteArtifacts'] ?? [], isEmpty);
    final test = (doc['tests'] as List).single as Map<String, dynamic>;
    expect(test['performance']['summary']['totalFrames'], 2);
    expect(test['performance'].containsKey('frames'), isFalse);
    expect(test['dumpTree'], contains('MaterialApp'));
    final step = (test['steps'] as List).single as Map<String, dynamic>;
    expect(step['performance']['totalFrames'], 2);
    expect(step['performance']['jankyFrames'], 1);
    expect(step['performance']['screens'], ['Home']);

    final html = File(p.join(tempDir.path, 'report', 'index.html'))
        .readAsStringSync();
    expect(html, contains('renderTestPerformance'));
    expect(html, contains('renderTestDumpTree'));
    expect(html, contains('modal-tab-performance'));
  });

  test('cleanTransientArtifacts keeps report, PNGs, and durations', () {
    final root = tempDir.path;
    Directory(p.join(root, 'logs')).createSync(recursive: true);
    File(p.join(root, 'logs', 'x_api_calls.json')).writeAsStringSync('{}');
    Directory(p.join(root, 'worker_progress')).createSync(recursive: true);
    Directory(p.join(root, 'worker_reports')).createSync(recursive: true);
    File(p.join(root, 'worker_reports', 'worker1.json')).writeAsStringSync('{}');
    Directory(p.join(root, 'report')).createSync(recursive: true);
    File(p.join(root, 'report', TestReportDocument.resultsFileName))
        .writeAsBytesSync([1, 2, 3]);
    File(p.join(root, 'report', 'index.html')).writeAsStringSync('<html></html>');
    File(p.join(root, 'test_durations.json')).writeAsStringSync('{}');
    Directory(p.join(root, 'screenshots')).createSync(recursive: true);
    File(p.join(root, 'screenshots', 't_frames.json')).writeAsStringSync('{}');
    File(p.join(root, 'screenshots', 't_step0_0.png')).writeAsBytesSync([1]);

    TestReportDocument.cleanTransientArtifacts(root);

    expect(Directory(p.join(root, 'logs')).existsSync(), isFalse);
    expect(Directory(p.join(root, 'worker_progress')).existsSync(), isFalse);
    expect(Directory(p.join(root, 'worker_reports')).existsSync(), isFalse);
    expect(
      File(p.join(root, 'report', TestReportDocument.resultsFileName))
          .existsSync(),
      isTrue,
    );
    expect(File(p.join(root, 'report', 'index.html')).existsSync(), isTrue);
    expect(File(p.join(root, 'test_durations.json')).existsSync(), isTrue);
    expect(File(p.join(root, 'screenshots', 't_frames.json')).existsSync(),
        isFalse);
    expect(
      File(p.join(root, 'screenshots', 't_step0_0.png')).existsSync(),
      isTrue,
    );
  });
}
