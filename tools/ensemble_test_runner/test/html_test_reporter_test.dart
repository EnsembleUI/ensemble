import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/reporters/html_test_reporter.dart';
import 'package:ensemble_test_runner/reporters/ensemble_test_history_store.dart';
import 'package:ensemble_test_runner/reporters/report_json_optimizer.dart';
import 'package:ensemble_test_runner/reporters/test_report_document.dart';
import 'package:ensemble_test_runner/src/core/operation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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

  Future<Uint8List> readLatestReportBytes() async {
    final db = await databaseFactoryFfi.openDatabase(
      p.join(tempDir.path, 'report', EnsembleTestHistoryStore.fileName),
    );
    try {
      final rows = await db.rawQuery('''
SELECT report_data FROM test_results
WHERE record_type = 'run' AND report_data IS NOT NULL
ORDER BY id DESC LIMIT 1
''');
      expect(rows, hasLength(1));
      return Uint8List.fromList(rows.single['report_data'] as List<int>);
    } finally {
      await db.close();
    }
  }

  Future<Map<String, dynamic>> readExpandedResults() async =>
      TestReportDocument.decodeCompressed(await readLatestReportBytes());

  Future<Map<String, dynamic>> readRawOptimized() async {
    final jsonText = utf8.decode(gzip.decode(await readLatestReportBytes()));
    return json.decode(jsonText) as Map<String, dynamic>;
  }

  test('suite start writes shell + loading results without rewriting later',
      () async {
    const displayRoot = 'build/ensemble_test_runner';
    final reporter = HtmlTestReporter();

    final htmlPath = await reporter.write(
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
    expect(shell, isNot(contains('results.json.gz')));
    expect(shell, isNot(contains("fetch('results.json.gz")));
    expect(shell, contains('report_data AS reportData'));
    expect(shell, contains('history-host'));
    expect(shell, contains('ensemble_test.db'));
    expect(shell, contains('sql-wasm.js'));
    expect(shell, contains('Test Execution History'));
    expect(shell, contains('historyRange = 50'));
    expect(shell, contains('function renderTestTrends'));
    expect(shell, contains('function renderHistoryComparison'));
    expect(shell, contains('Choose two different runs to compare'));
    expect(
        shell, contains('Per-test comparison is unavailable for these runs'));
    expect(shell, contains('history-chart-heading'));
    expect(shell, contains('No issues surfaced in these runs'));
    expect(shell, contains('test_results'));
    expect(shell, contains('ensureHistoryLoaded'));
    expect(shell, contains('setHistorySearch'));
    expect(shell, isNot(contains('Last 10 Runs')));
    expect(shell, contains('chartRuns.length * 32'));
    expect(shell, contains('overflow-x: auto;'));
    expect(shell, contains("Execution Duration (' + chartLabel"));
    expect(shell, contains("Test Volume & Results (' + chartLabel"));
    expect(shell, contains('DecompressionStream'));
    expect(shell, contains('report-loader'));
    expect(shell,
        contains('Waiting for a completed test report in ensemble_test.db'));
    expect(shell,
        contains('No completed test report is stored in ensemble_test.db yet'));
    expect(shell, isNot(contains('ensembleHtmlTestReportAppJs')));
    expect(shell, contains('pollAndRender'));
    expect(shell, contains('feature-select'));
    expect(shell, contains('applyFeatureFilter'));
    expect(shell, contains('profile-select'));
    expect(shell, contains('applyProfileFilter'));
    expect(shell, contains('features.length > 1'));
    expect(shell, contains('profiles.length > 1'));
    expect(shell, contains('modal-step-error'));
    expect(shell, contains('stepFailureMessage'));
    expect(shell, contains('window.stepMeta'));
    expect(shell.length, lessThan(252000));
    expect(File(p.join(tempDir.path, 'report', 'results.js')).existsSync(),
        isFalse);

    expect(
      await databaseFactoryFfi
          .openDatabase(
        p.join(tempDir.path, 'report', EnsembleTestHistoryStore.fileName),
      )
          .then((db) async {
        try {
          return await db.rawQuery(
            "SELECT report_data FROM test_results WHERE record_type = 'run'",
          );
        } finally {
          await db.close();
        }
      }),
      isEmpty,
    );

    final shellBefore = shell;

    Directory(p.join(tempDir.path, 'logs')).createSync(recursive: true);
    File(p.join(tempDir.path, 'logs', 'ok_app_console.log'))
        .writeAsStringSync('done\n');

    await reporter.write(
      EnsembleTestRunResult(
        results: [
          EnsembleSingleTestResult.passed(
            testId: 'ok',
            metadata: const {
              'feature': 'alternate-installation',
              'profile': 'alternate',
              'scenarioId': 'manual_connect',
              'scenarioDescription': 'Manual Wi-Fi connection.',
              'device': {
                'id': 'android',
                'platform': 'android',
                'model': 'Samsung Galaxy S20',
                'locale': 'nl',
                'theme': 'light',
              },
            },
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

    expect(htmlFile.readAsStringSync(), contains('ensemble_test.db'));
    expect(shellBefore, contains('ensemble_test.db'));
    expect(
      File(p.join(tempDir.path, 'report', 'results.json.gz')).existsSync(),
      isFalse,
    );

    final complete = await readExpandedResults();
    expect(complete['state'], 'complete');
    expect(complete['tests'], hasLength(1));
    expect(complete['tests'][0]['id'], 'ok');
    expect(complete['tests'][0]['feature'], 'alternate-installation');
    expect(complete['tests'][0]['profile'], 'alternate');
    expect(complete['tests'][0]['scenarioId'], 'manual_connect');
    expect(
      complete['tests'][0]['scenarioDescription'],
      'Manual Wi-Fi connection.',
    );
    expect(complete['tests'][0]['device']['locale'], 'nl');
    expect(complete['tests'][0]['device']['model'], 'Samsung Galaxy S20');
    expect(complete['tests'][0]['deviceBadge'], 'android');
    expect(complete['summary']['passed'], 1);
    expect(Directory(p.join(tempDir.path, 'logs')).existsSync(), isFalse);
  });

  test('replaces an outdated report shell with the database reader', () {
    final report = Directory(p.join(tempDir.path, 'report'))
      ..createSync(recursive: true);
    final html = File(p.join(report.path, 'index.html'))
      ..writeAsStringSync("fetch('results.json.gz')");

    HtmlTestReporter().writeShell(artifactRoot: tempDir.path);

    final refreshed = html.readAsStringSync();
    expect(refreshed, contains('report_data AS reportData'));
    expect(refreshed, contains('ensemble_test.db'));
    expect(refreshed, isNot(contains('results.json.gz')));
  });

  test('complete results aggregate api/storage/console/screenshots/steps',
      () async {
    final framesDir = Directory(p.join(tempDir.path, 'frames'))
      ..createSync(recursive: true);
    final reportScreenshotsDir =
        Directory(p.join(tempDir.path, 'report', 'screenshots'))
          ..createSync(recursive: true);
    const webpHeader = [82, 73, 70, 70, 0, 0, 0, 0, 87, 69, 66, 80];
    File(p.join(reportScreenshotsDir.path, 'login_flow_step0_0.webp'))
        .writeAsBytesSync(webpHeader);
    File(p.join(reportScreenshotsDir.path, 'login_flow_step1_0.webp'))
        .writeAsBytesSync(webpHeader);
    File(p.join(framesDir.path, 'login_flow_frames.json')).writeAsStringSync(
      jsonEncode({
        'status': 'failed',
        'failedStepIndex': 1,
        'frames': [
          {
            'stepIndex': 0,
            'label': '1. enterText(email_field)',
            'file': 'login_flow_step0_0.webp',
          },
          {
            'stepIndex': 1,
            'label': '2. tap(login_button)',
            'file': 'login_flow_step1_0.webp',
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
              'profile': {
                'id': 1,
                'roles': ['admin', 'user']
              },
            },
          },
        ],
      }),
    );
    File(p.join(logsDir.path, 'login_flow_attempt_1_api_calls.json'))
        .writeAsStringSync(jsonEncode({
      'events': [
        {
          'name': 'loginRetry',
          'timestamp': '2026-07-22T12:00:00.020',
          'stepIndex': 1,
          'statusCode': 503,
        },
      ],
    }));
    File(p.join(logsDir.path, 'login_flow_storage.json')).writeAsStringSync(
      jsonEncode({
        'storage': {
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
        },
      }),
    );
    File(p.join(logsDir.path, 'login_flow_app_console.log'))
        .writeAsStringSync('[2026-07-22T12:00:00.050][step=1] during wait\n');
    File(p.join(logsDir.path, 'login_flow_attempt_1_app_console.log'))
        .writeAsStringSync(
            '--- Attempt 1 of 4 ---\n[2026-07-22T12:00:00.020][step=1] first attempt\n');
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
          metadata: const {
            'description': 'Logs in with a valid token and opens the dashboard',
          },
          durationMs: 3400,
          failedStepIndex: 1,
          message: 'Timed out waiting for dashboard',
          logs: [
            'screenshotFrames: $displayRoot/frames/login_flow_frames.json',
            'apiCalls: $displayRoot/logs/login_flow_attempt_1_api_calls.json',
            'appLogs: $displayRoot/logs/login_flow_attempt_1_app_console.log',
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
    await reporter.write(
      result,
      artifactRoot: tempDir.path,
      displayRoot: displayRoot,
    );

    final html =
        File(p.join(tempDir.path, 'report', 'index.html')).readAsStringSync();
    expect(html, isNot(contains('results.json.gz')));
    expect(html, isNot(contains("fetch('results.json.gz")));
    expect(html, contains('report_data AS reportData'));
    expect(html, contains('switchModalTab(\'screenshots\')'));
    expect(html, isNot(contains('switchModalTab(\'observer\')')));
    expect(html, contains('modal-observer-side'));
    expect(html, contains('screenshots-split'));
    expect(html, contains('copyObserverJson'));
    expect(html, contains('renderObserverTreeNode'));
    expect(html, contains('observer-tree'));
    expect(html, contains('bindObserverTreeHover'));
    expect(html, contains('openObserverElementDetail'));
    expect(html, contains('Bounds (logical px)'));
    expect(html, contains('el.selected'));
    expect(html, contains('el.offscreen'));
    expect(
        html, contains('const payload = observer && observer.observationJson'));
    expect(html, contains('window.__observerCopyPayload = payload'));
    expect(html, contains('el.actions'));
    expect(html, isNot(contains('formatObserverActionYaml')));
    expect(html, contains('return { bounds: el.bounds }'));
    expect(html, contains('bounds=\' + JSON.stringify(locator.bounds)'));
    expect(html, contains('navigateObserverElement'));
    expect(html, contains('renderObserverElementPreview'));
    expect(html, contains('Element is outside this screenshot viewport'));
    expect(html, contains('Screenshot has no bounds overlay for this element'));
    expect(html, contains('layoutObserverDetailPreview'));
    expect(html, contains('observer-element-detail-overlay'));
    expect(html, contains('screenshot-highlight'));
    expect(html, contains('renderScreenshotImage'));
    expect(html, contains('layoutScreenshotChips'));
    expect(html, contains('flattenScreenshotFramesWithOverlays'));
    expect(html, contains('screenshotOverlayToolbarHtml'));
    expect(html, contains('copyScreenshotOverlay'));
    expect(html,
        contains("screenshotOverlaySwitchHtml('obsHighlights', 'Elements')"));
    expect(
        html, contains("screenshotOverlaySwitchHtml('obsLabels', 'Labels')"));
    expect(html,
        contains("screenshotOverlaySwitchHtml('actionHighlights', 'Target')"));
    expect(html, contains("screenshotOverlaySwitchHtml('showTree', 'Tree')"));
    expect(html, contains('modal-screenshots-toolbar'));
    expect(html, isNot(contains('Timed out waiting for dashboard')));
    expect(html, isNot(contains('"name":"login"')));

    final doc = await readExpandedResults();
    expect(doc['state'], 'complete');
    expect(doc['summary']['passed'], 1);
    expect(doc['summary']['failed'], 1);

    final tests = doc['tests'] as List;
    // All report projections preserve the execution order from machine JSON.
    expect(tests.first['id'], contains('ok_home'));
    expect(tests.last['id'], contains('login_flow'));

    final failed = tests.last as Map<String, dynamic>;
    expect(
      failed['description'],
      'Logs in with a valid token and opens the dashboard',
    );
    expect(failed['message'], 'Timed out waiting for dashboard');
    expect(failed.containsKey('api'), isFalse);
    expect(failed.containsKey('console'), isFalse);
    expect(failed.containsKey('screenshots'), isFalse);
    expect((failed['storage'] as Map).containsKey('steps'), isFalse);
    expect((failed['storage'] as Map)['keys']['token'], 'abc');

    final steps = failed['steps'] as List;
    expect(steps, hasLength(2));
    expect((steps[0] as Map)['apiCalls'], isEmpty);
    final stepApiCalls = (steps[1] as Map)['apiCalls'] as List;
    expect(stepApiCalls.map((event) => event['name']),
        containsAll(['loginRetry', 'login']));
    expect(stepApiCalls.firstWhere((event) => event['name'] == 'login')['name'],
        'login');
    expect(
      stepApiCalls.firstWhere(
          (event) => event['name'] == 'login')['responseBody']['token'],
      'abc',
    );
    expect((steps[1] as Map)['appLogs'], isNotEmpty);
    expect(
      (steps[1] as Map)['appLogs'],
      contains('[2026-07-22T12:00:00.020][step=1] first attempt'),
    );
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
    expect(frames.first['href'],
        'screenshots.zip#screenshots/login_flow_step0_0.webp');
    expect(((steps[1] as Map)['screenshots'] as List).first['failed'], isTrue);

    final raw = await readRawOptimized();
    expect(raw.containsKey('blobs'), isTrue);
    final rawFailed = (raw['tests'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((test) => (test['id'] as String).contains('login_flow'));
    final api = ((rawFailed['steps'] as List)[1] as Map<String, dynamic>);
    final ev = (api['apiCalls'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((event) => event['name'] == 'login');
    expect(ev['responseBody'], isA<Map>());
    expect((ev['responseBody'] as Map).containsKey(r'$b'), isTrue);

    expect(Directory(p.join(tempDir.path, 'logs')).existsSync(), isFalse);
    expect(
      File(p.join(framesDir.path, 'login_flow_frames.json')).existsSync(),
      isFalse,
    );
    expect(
      File(p.join(framesDir.path, 'login_flow_step0_0.png')).existsSync(),
      isFalse,
    );
    final screenshotArchive = ZipDecoder().decodeBytes(
      File(p.join(tempDir.path, 'report', 'screenshots.zip')).readAsBytesSync(),
    );
    expect(
      screenshotArchive.files.map((file) => file.name),
      contains('screenshots/login_flow_step0_0.webp'),
    );
    expect(
      Directory(p.join(tempDir.path, 'report', 'screenshots')).existsSync(),
      isFalse,
    );
  });

  test('compressed report preserves untrusted text for escaped rendering', () {
    final html = HtmlTestReporter().buildShellHtml();
    final document = TestReportDocument.buildComplete(
      EnsembleTestRunResult(
        results: [
          EnsembleSingleTestResult.failed(
            testId: 'bad<script>',
            durationMs: 1,
            message: '<img src=x onerror=alert(1)>',
          ),
        ],
      ),
      artifactRoot: tempDir.path,
      displayRoot: 'build/ensemble_test_runner',
    );
    final doc = TestReportDocument.decodeCompressed(
      TestReportDocument.encodeCompressed(document),
    );
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
      'summary': {'passed': 1, 'failed': 0, 'totalMs': 1},
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
                  'request': {
                    'headers': {'A': '1'},
                    'body': body
                  },
                },
                {
                  'name': 'b',
                  'responseBody': body,
                  'request': {
                    'headers': {'A': '1'},
                    'body': body
                  },
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
    expect(complete['summary']['failed'], 0);
    expect(complete['summary']['total'], 1);
    expect(complete['summary']['status'], 'passed');
    final restoredLoading = TestReportDocument.decodeCompressed(
      TestReportDocument.encodeCompressed(loading),
    );
    expect(restoredLoading['state'], 'loading');
    expect(restoredLoading['summary'], loading['summary']);
    expect(restoredLoading['tests'], isEmpty);
    final restoredComplete = TestReportDocument.decodeCompressed(
      TestReportDocument.encodeCompressed(complete),
    );
    expect(restoredComplete['state'], 'complete');
    expect(restoredComplete['summary'], complete['summary']);
    expect((restoredComplete['tests'] as List).single['id'], 't1');
    expect((complete['tests'] as List).first['id'], 't1');
  });

  test('complete reports deduplicate repeated durable suite artifact links',
      () {
    final artifact = File(p.join(tempDir.path, 'logs', 'suite.log'))
      ..createSync(recursive: true)
      ..writeAsStringSync('suite evidence');
    const displayRoot = 'build/ensemble_test_runner';
    final result = EnsembleTestRunResult(
      results: const [],
      suiteLogs: [
        'custom: $displayRoot/logs/suite.log',
        'custom: $displayRoot/logs/suite.log',
      ],
    );

    final complete = TestReportDocument.buildComplete(
      result,
      artifactRoot: tempDir.path,
      displayRoot: displayRoot,
    );

    expect(artifact.existsSync(), isTrue);
    expect(complete['suiteArtifacts'], [
      {
        'label': 'custom',
        'path': '$displayRoot/logs/suite.log',
        'href': '../logs/suite.log',
      },
    ]);
  });

  test('complete reports read duplicate artifact references once', () {
    const displayRoot = 'build/ensemble_test_runner';
    final logs = Directory(p.join(tempDir.path, 'logs'))..createSync();
    File(p.join(logs.path, 'api.json')).writeAsStringSync(jsonEncode({
      'events': [
        {
          'name': 'load',
          'timestamp': '2026-07-22T12:00:00.100Z',
          'stepIndex': 0
        }
      ],
    }));
    File(p.join(logs.path, 'console.log'))
        .writeAsStringSync('[2026-07-22T12:00:00.100Z][step=0] loaded\n');

    final complete = TestReportDocument.buildComplete(
      EnsembleTestRunResult(results: [
        EnsembleSingleTestResult.passed(
          testId: 'load (tests/load.test.yaml)',
          durationMs: 100,
          logs: [
            'apiCalls: $displayRoot/logs/api.json',
            'apiCalls: $displayRoot/logs/api.json',
            'appLogs: $displayRoot/logs/console.log',
            'appLogs: $displayRoot/logs/console.log',
          ],
          report: const EnsembleTestReportDetails(
            stepsOutline: ['tap(load_button)'],
            stepDurationsMs: [100],
            stepStartTimes: ['2026-07-22T12:00:00.000Z'],
          ),
        ),
      ]),
      artifactRoot: tempDir.path,
      displayRoot: displayRoot,
    );

    final step =
        ((complete['tests'] as List).single as Map)['steps'].single as Map;
    expect(step['apiCalls'], hasLength(1));
    expect(step['appLogs'], hasLength(1));
  });

  test('storage reports ignore retired flat snapshot artifacts', () {
    const displayRoot = 'build/ensemble_test_runner';
    final logs = Directory(p.join(tempDir.path, 'logs'))..createSync();
    final flatSnapshot = File(p.join(logs.path, 'storage.json'))
      ..writeAsStringSync(jsonEncode({
        'keys': {'token': 'retired'},
        'steps': [
          {
            'stepIndex': 0,
            'changes': [
              {'key': 'token', 'change': 'added', 'after': 'retired'},
            ],
          },
        ],
      }));

    final complete = TestReportDocument.buildComplete(
      EnsembleTestRunResult(results: [
        EnsembleSingleTestResult.passed(
          testId: 'flat-storage',
          durationMs: 1,
          logs: ['storage: $displayRoot/logs/${p.basename(flatSnapshot.path)}'],
          report: const EnsembleTestReportDetails(
            stepsOutline: ['tap(open_button)'],
            stepDurationsMs: [1],
          ),
        ),
      ]),
      artifactRoot: tempDir.path,
      displayRoot: displayRoot,
    );

    final result = (complete['tests'] as List).single as Map;
    expect(result['storage'], {
      'keys': <String, dynamic>{},
      'secureStorageKeys': <String, dynamic>{},
      'keychainKeys': <String, dynamic>{},
    });
    final step = (result['steps'] as List).single as Map;
    expect(step['storageChanges'], isEmpty);
  });

  test('HTML results preserve canonical structured failure diagnostics', () {
    final failed = EnsembleSingleTestResult.failed(
      testId: 'failed-case',
      metadata: const {
        'owner': 'qa',
        'custom': {'priority': 'high'},
      },
      durationMs: 12,
      attempts: 2,
      retry: 1,
      message: 'missing submit button',
      stackTrace: 'failure stack',
      failedStepIndex: 2,
      failureOperation: 'tap',
      failureSource: const SourceLocation('tests/submit.test.yaml', 'steps[2]'),
      failedStep: TestStep(type: 'tap', args: {'id': 'submit'}),
      failure: const TestFailureDetails(
        kind: TestFailureKind.elementNotFound,
        message: 'submit was not found',
        target: {'id': 'submit'},
        phase: 'execution',
      ),
      secondaryFailures: const [
        TestFailureDetails(
          kind: TestFailureKind.cleanup,
          message: 'cleanup failed',
          phase: 'cleanup',
        ),
      ],
      capabilityStatus: const {'screenshots': false},
    );
    final expected = failed.toJson();
    final complete = TestReportDocument.buildComplete(
      EnsembleTestRunResult(results: [failed]),
      artifactRoot: tempDir.path,
      displayRoot: 'build/ensemble_test_runner',
    );
    final entry = (complete['tests'] as List).single as Map<String, dynamic>;

    for (final key in const [
      'failure',
      'secondaryFailures',
      'stackTrace',
      'failedStep',
      'failureOperation',
      'failureSource',
      'capabilities',
      'attempts',
      'retry',
      'metadata',
    ]) {
      expect(entry[key], expected[key],
          reason: '$key should match result JSON');
    }

    // The persisted, optimized report must expose the same diagnostics as
    // the in-memory document consumed by the HTML reporter.
    final persisted = ReportJsonOptimizer.expand(
      ReportJsonOptimizer.optimize(complete),
    );
    final persistedEntry =
        (persisted['tests'] as List).single as Map<String, dynamic>;
    for (final key in const [
      'failure',
      'secondaryFailures',
      'stackTrace',
      'failedStep',
      'failureOperation',
      'failureSource',
      'capabilities',
      'attempts',
      'retry',
      'metadata',
    ]) {
      expect(persistedEntry[key], expected[key],
          reason: '$key should survive report compression');
    }
  });

  test('stores screen details in the database report payload', () async {
    const displayRoot = 'build/ensemble_test_runner';

    final reporter = HtmlTestReporter();
    await reporter.write(
      EnsembleTestRunResult(
        results: [
          EnsembleSingleTestResult.passed(
            testId: 't1',
            durationMs: 10,
            report: EnsembleTestReportDetails(
              startScreen: 'Home',
              screensVisited: const ['Home', 'Login'],
              stepsOutline: const ['tap(a)'],
              stepDurationsMs: const [10],
              screens: {
                'Home': {
                  'debugTree': 'MaterialApp\n  Scaffold\n',
                  'performance': {
                    'screen': 'Home',
                    'totalFrames': 2,
                    'jankyFrames': 1,
                  },
                },
                'Login': {
                  'debugTree': 'LoginForm\n',
                  'performance': {
                    'screen': 'Login',
                    'totalFrames': 1,
                    'jankyFrames': 0,
                  },
                },
              },
            ),
          ),
        ],
      ),
      artifactRoot: tempDir.path,
      displayRoot: displayRoot,
    );

    final doc = await readExpandedResults();
    final test = (doc['tests'] as List).single as Map<String, dynamic>;
    expect(test.containsKey('performance'), isFalse);
    expect(test.containsKey('dumpTree'), isFalse);
    final screens = (test['report'] as Map)['screens'] as Map<String, dynamic>;
    expect(screens['Home']['debugTree'], contains('MaterialApp'));
    expect(screens['Home']['performance']['totalFrames'], 2);
    expect(screens['Login']['debugTree'], contains('LoginForm'));
    expect(screens['Login']['performance']['totalFrames'], 1);

    final html =
        File(p.join(tempDir.path, 'report', 'index.html')).readAsStringSync();
    expect(html, contains('openScreenDialog'));
    expect(html, isNot(contains('renderTestPerformance')));
    expect(html, isNot(contains('renderTestDumpTree')));
    expect(html, isNot(contains('modal-tab-performance')));
  });

  test('cleanTransientArtifacts keeps screenshot archive', () {
    final root = tempDir.path;
    Directory(p.join(root, 'logs')).createSync(recursive: true);
    File(p.join(root, 'logs', 'x_api_calls.json')).writeAsStringSync('{}');
    Directory(p.join(root, 'worker_progress')).createSync(recursive: true);
    Directory(p.join(root, 'worker_reports')).createSync(recursive: true);
    File(p.join(root, 'worker_reports', 'worker1.json'))
        .writeAsStringSync('{}');
    Directory(p.join(root, 'report')).createSync(recursive: true);
    File(p.join(root, 'report', EnsembleTestHistoryStore.fileName))
        .writeAsBytesSync([1, 2, 3]);
    File(p.join(root, 'report', 'index.html'))
        .writeAsStringSync('<html></html>');
    File(p.join(root, 'report', 'screenshots.zip')).writeAsBytesSync([1]);
    File(p.join(root, 'test_durations.json')).writeAsStringSync('{}');
    Directory(p.join(root, 'frames')).createSync(recursive: true);
    File(p.join(root, 'frames', 't_frames.json')).writeAsStringSync('{}');
    Directory(p.join(root, 'screenshots')).createSync(recursive: true);
    File(p.join(root, 'screenshots', 'legacy_frames.json'))
        .writeAsStringSync('{}');

    TestReportDocument.cleanTransientArtifacts(root);

    expect(Directory(p.join(root, 'logs')).existsSync(), isFalse);
    expect(Directory(p.join(root, 'worker_progress')).existsSync(), isFalse);
    expect(Directory(p.join(root, 'worker_reports')).existsSync(), isFalse);
    expect(Directory(p.join(root, 'frames')).existsSync(), isFalse);
    expect(Directory(p.join(root, 'screenshots')).existsSync(), isFalse);
    expect(
      File(p.join(root, 'report', EnsembleTestHistoryStore.fileName))
          .existsSync(),
      isTrue,
    );
    expect(File(p.join(root, 'report', 'index.html')).existsSync(), isTrue);
    expect(File(p.join(root, 'test_durations.json')).existsSync(), isFalse);
    expect(
        File(p.join(root, 'report', 'screenshots.zip')).existsSync(), isTrue);
  });
}
