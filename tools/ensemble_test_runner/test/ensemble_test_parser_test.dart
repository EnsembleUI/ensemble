import 'package:ensemble_test_runner/ensemble_test_runner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EnsembleTestParser', () {
    test('parses minimal test file', () {
      const yaml = '''
id: login_screen_renders
startScreen: LoginScreen
steps:
  - expectVisible:
      id: emailInput
''';

      final test = EnsembleTestParser.parseString(yaml);
      expect(test.id, 'login_screen_renders');
      expect(test.startScreen, 'LoginScreen');
      expect(test.steps.length, 1);
      expect(test.steps.first.type, 'expectVisible');
      expect(test.steps.first.args['id'], 'emailInput');
    });

    test('parses retry count', () {
      const yaml = '''
id: signin_to_gateway
startScreen: Login
retry: 3
steps:
  - tap:
      id: login_with_test_token
''';

      final test = EnsembleTestParser.parseString(yaml);
      expect(test.retry, 3);
    });

    test('rejects negative retry count', () {
      const yaml = '''
id: signin_to_gateway
startScreen: Login
retry: -1
steps:
  - tap:
      id: login_with_test_token
''';

      expect(
        () => EnsembleTestParser.parseString(yaml),
        throwsA(
          isA<EnsembleTestFailure>().having(
            (error) => error.message,
            'message',
            contains(
                '"signin_to_gateway.retry" must be a non-negative integer'),
          ),
        ),
      );
    });

    test('parses start screen inputs', () {
      const yaml = '''
id: offline_result
startScreen: ZTP_Connection_Result_State
startScreenInputs:
  signalStrength: offline
  apiUrl: \${inputs.apiUrl}
steps:
  - expectVisible:
      id: retry_button
''';

      final test = EnsembleTestParser.parseString(
        yaml,
        inputs: const {'apiUrl': 'http://127.0.0.1:5001'},
      );
      expect(test.startScreenInputs, {
        'signalStrength': 'offline',
        'apiUrl': 'http://127.0.0.1:5001',
      });
    });

    test('parses inline root-level mocks', () {
      const yaml = '''
id: login_success
startScreen: Login
mocks:
  loginApi:
    delayMs: 100
    statusCode: 200
    body:
      token: test-token
steps:
  - expectApiCalled:
      name: loginApi
      times: 1
''';

      final test = EnsembleTestParser.parseString(yaml);

      expect(test.mockFiles, isEmpty);
      expect((test.inlineMocks['loginApi'] as Map)['delayMs'], 100);
      expect(
        ((test.inlineMocks['loginApi'] as Map)['body'] as Map)['token'],
        'test-token',
      );
    });

    test('parses initial keychain state', () {
      const yaml = '''
id: resumes_session
startScreen: Login
initialState:
  storage:
    languageSet: true
  keychain:
    kpnPsi: test-psi
    authPayload:
      token: abc
steps:
  - expectVisible:
      id: login_button
''';

      final test = EnsembleTestParser.parseString(yaml);
      expect(test.initialState['keychain'], isA<Map>());
      expect((test.initialState['keychain'] as Map)['kpnPsi'], 'test-psi');
      expect(
        ((test.initialState['keychain'] as Map)['authPayload'] as Map)['token'],
        'abc',
      );
    });

    test('parses a reusable session and pre-screen setup', () {
      const yaml = '''
id: home_from_session
session: signin
startScreen: Home
setup:
  - httpRequest:
      method: POST
      url: http://127.0.0.1:5001/reset
steps:
  - expectVisible:
      id: home
''';

      final test = EnsembleTestParser.parseString(yaml);
      expect(test.session, 'signin');
      expect(test.setupSteps.map((step) => step.type), [
        'httpRequest',
      ]);
    });

    test('rejects widget actions in pre-screen setup', () {
      const yaml = '''
id: invalid_setup
startScreen: Home
setup:
  - tap:
      id: button
steps:
  - expectVisible:
      id: home
''';

      expect(
        () => EnsembleTestParser.parseString(yaml),
        throwsA(
          isA<EnsembleTestFailure>().having(
            (error) => error.message,
            'message',
            contains('setup only supports httpRequest, group, and optional'),
          ),
        ),
      );
    });

    test('rejects session without a start screen', () {
      const yaml = '''
id: invalid_session
session: signin
steps:
  - expectVisible:
      id: home
''';

      expect(
        () => EnsembleTestParser.parseString(yaml),
        throwsA(
          isA<EnsembleTestFailure>().having(
            (error) => error.message,
            'message',
            contains('must have "startScreen"'),
          ),
        ),
      );
    });

    test('resolves CLI inputs in initial state and steps', () {
      const yaml = '''
id: input_test
startScreen: Login
initialState:
  keychain:
    adminPassword: \${inputs.adminPassword}
steps:
  - expectText:
      text: \${inputs.expectedDeviceCount}
  - expectText:
      text: "Devices: \${inputs.expectedDeviceCount}"
''';

      final test = EnsembleTestParser.parseString(
        yaml,
        inputs: {
          'adminPassword': 's4C>M7U6t~',
          'expectedDeviceCount': 2,
        },
      );

      expect(
        (test.initialState['keychain'] as Map)['adminPassword'],
        's4C>M7U6t~',
      );
      expect(test.steps[0].args['text'], 2);
      expect(test.steps[1].args['text'], 'Devices: 2');
    });

    test('fails clearly when CLI input is missing', () {
      const yaml = '''
id: input_test
startScreen: Login
steps:
  - expectText:
      text: \${inputs.expectedDeviceCount}
''';

      expect(
        () => EnsembleTestParser.parseString(yaml),
        throwsA(
          isA<EnsembleTestFailure>().having(
            (error) => error.message,
            'message',
            contains('Missing CLI input "expectedDeviceCount"'),
          ),
        ),
      );
    });

    test('parses scenarios and resolves scenario placeholders', () {
      const yaml = '''
id: home_scenarios
startScreen: Home
mocks:
  - mocks/\${scenario.device}.mock.json
scenarios:
  - id: v14_online
    vars:
      device: v14
      expectedDeviceCount: 2
steps:
  - expectText:
      text: \${scenario.expectedDeviceCount}
''';

      final base = EnsembleTestParser.parseString(yaml);
      expect(base.scenarios.single.id, 'v14_online');
      expect(base.scenarios.single.vars['device'], 'v14');
      expect(base.mockFiles.single, 'mocks/\${scenario.device}.mock.json');

      final expanded = EnsembleTestParser.parseString(
        yaml,
        scenario: base.scenarios.single.vars,
        scenarioId: base.scenarios.single.id,
      );
      expect(expanded.mockFiles.single, 'mocks/v14.mock.json');
      expect(expanded.steps.single.args['text'], 2);
    });

    test('fails clearly when scenario value is missing', () {
      const yaml = '''
id: home_scenarios
startScreen: Home
scenarios:
  - id: missing_value
    vars: {}
steps:
  - expectText:
      text: \${scenario.expectedDeviceCount}
''';

      final base = EnsembleTestParser.parseString(yaml);
      expect(
        () => EnsembleTestParser.parseString(
          yaml,
          scenario: base.scenarios.single.vars,
          scenarioId: base.scenarios.single.id,
        ),
        throwsA(
          isA<EnsembleTestFailure>().having(
            (error) => error.message,
            'message',
            contains(
              'Missing scenario value "expectedDeviceCount" in scenario "missing_value"',
            ),
          ),
        ),
      );
    });

    test('rejects unsupported root keys in test files', () {
      const yaml = '''
id: visual_debug
startScreen: Home
unknownSetting: true
steps:
  - tap:
      id: start_button
''';

      expect(
        () => EnsembleTestParser.parseString(yaml),
        throwsA(
          isA<EnsembleTestFailure>().having(
            (error) => error.message,
            'message',
            contains('Unsupported root key "unknownSetting"'),
          ),
        ),
      );
    });

    test('parses suite config screenshots', () {
      const yaml = '''
screenshots:
  enabled: true
  includeSteps: [tap, waitForNavigation]
  excludeSteps: [wait]
''';

      final config = EnsembleTestParser.parseConfigString(yaml);
      final screenshots = config.screenshots;
      expect(screenshots.enabled, isTrue);
      expect(screenshots.includeSteps, ['tap', 'waitForNavigation']);
      expect(screenshots.excludeSteps, ['wait']);
      expect(screenshots.shouldCaptureStep('tap'), isTrue);
      expect(screenshots.shouldCaptureStep('wait'), isFalse);
      expect(screenshots.shouldCaptureStep('settle'), isFalse);
    });

    test('parses suite devices matrix', () {
      const yaml = '''
devices:
  - id: android_nl
    platform: android
    model: Samsung Galaxy S20
    locale: nl
    theme: light
  - platform: ios
    model: iPhone 15 Pro
    locale: en
    theme: dark
''';

      final devices = EnsembleTestParser.parseConfigString(yaml).devices;
      expect(devices, hasLength(2));
      expect(devices[0].id, 'android_nl');
      expect(devices[0].platform, 'android');
      expect(devices[0].model, 'Samsung Galaxy S20');
      expect(devices[0].locale, 'nl');
      expect(devices[0].theme, 'light');
      expect(devices[0].displayLabel, 'Samsung Galaxy S20 · nl · light');
      expect(devices[1].id, 'ios_en');
      expect(devices[1].platform, 'ios');
      expect(devices[1].locale, 'en');
      expect(devices[1].theme, 'dark');
    });

    test('rejects screenshots.platform/model/devices', () {
      const yaml = '''
screenshots:
  enabled: true
  platform: ios
''';
      expect(
        () => EnsembleTestParser.parseConfigString(yaml),
        throwsA(
          isA<EnsembleTestFailure>().having(
            (error) => error.message,
            'message',
            contains('screenshots.platform'),
          ),
        ),
      );
    });

    test('parses suite test services', () {
      const yaml = '''
services:
  - name: modemStub
    command: .venv/bin/python
    arguments: [modemstub/app.py]
    workingDirectory: ensemble/apps/inhome/autotests
    readyUrl: /ping
    readyTimeoutMs: 15000
''';

      final service =
          EnsembleTestParser.parseConfigString(yaml).services.single;
      expect(service.name, 'modemStub');
      expect(service.command, '.venv/bin/python');
      expect(service.url, isNull);
      expect(service.arguments, ['modemstub/app.py']);
      expect(service.workingDirectory, 'ensemble/apps/inhome/autotests');
      expect(service.environment, isEmpty);
      expect(service.resolvedEnvironment, isEmpty);
      expect(service.readyUrl, '/ping');
      expect(service.resolvedReadyUrl, '/ping');
      expect(service.readyTimeoutMs, 15000);
    });

    test('parses suite mocks', () {
      const yaml = '''
mocks:
  - mocks/common.mock.json
  - getDevices:
      body: {count: 3}
''';

      final config = EnsembleTestParser.parseConfigString(yaml);
      expect(config.mockFiles, ['mocks/common.mock.json']);
      expect(
        config.inlineMocks['getDevices'],
        {
          'body': {'count': 3}
        },
      );
    });

    test('parses suite initialState', () {
      const yaml = '''
initialState:
  storage:
    apiUrl: http://ensemble.test/ws
  env:
    APP_LOCALE: nl
''';

      final config = EnsembleTestParser.parseConfigString(yaml);
      expect(
        (config.initialState['storage'] as Map)['apiUrl'],
        'http://ensemble.test/ws',
      );
      expect((config.initialState['env'] as Map)['APP_LOCALE'], 'nl');
    });

    test('parses suite config performance', () {
      const yaml = '''
performance:
  enabled: true
''';

      final config = EnsembleTestParser.parseConfigString(yaml);
      expect(config.performance.enabled, isTrue);
    });

    test('parses suite config timer rewrites', () {
      const yaml = '''
timers:
  enabled: true
  maxStartAfterSeconds: 2
  maxRepeatIntervalSeconds: 3
''';

      final config = EnsembleTestParser.parseConfigString(yaml);
      expect(config.timers.enabled, isTrue);
      expect(config.timers.maxStartAfterSeconds, 2);
      expect(config.timers.maxRepeatIntervalSeconds, 3);
    });

    test('rejects removed record config', () {
      const yaml = '''
record:
  enabled: true
''';

      expect(
        () => EnsembleTestParser.parseConfigString(yaml),
        throwsA(
          isA<EnsembleTestFailure>().having(
            (error) => error.message,
            'message',
            contains('Unsupported test config key "record"'),
          ),
        ),
      );
    });

    test('parses suite config debug artifacts', () {
      const yaml = '''
dumpTree:
  enabled: true
logApiCalls:
  enabled: true
logStorage:
  enabled: true
  key: auth
''';

      final config = EnsembleTestParser.parseConfigString(yaml);
      expect(config.dumpTree.enabled, isTrue);
      expect(config.logApiCalls.enabled, isTrue);
      expect(config.logStorage.enabled, isTrue);
      expect(config.logStorage.key, 'auth');
    });

    test('parses AI-friendly metadata fields', () {
      const yaml = '''
id: login_valid
feature: login
tags: [smoke, auth]
description: Valid user can log in
owner: qa
priority: high
startScreen: Login
steps:
  - expectVisible:
      id: login_button
''';

      final test = EnsembleTestParser.parseString(yaml);
      expect(test.feature, 'login');
      expect(test.tags, ['smoke', 'auth']);
      expect(test.description, 'Valid user can log in');
      expect(test.owner, 'qa');
      expect(test.priority, 'high');
      expect(test.metadataJson['feature'], 'login');
    });

    test('rejects legacy tests wrapper', () {
      expect(
        () => EnsembleTestParser.parseString('''
tests:
  - id: old_format
    startScreen: Home
    steps:
      - expectVisible:
          id: x
'''),
        throwsA(
          isA<EnsembleTestFailure>().having(
            (e) => e.message,
            'message',
            contains('tests'),
          ),
        ),
      );
    });
  });

  group('startScreen', () {
    test('rejects when startScreen is missing', () {
      const yaml = '''
id: invalid_neither
steps:
  - expectVisible:
      id: x
''';

      expect(
        () => EnsembleTestParser.parseString(yaml),
        throwsA(
          isA<EnsembleTestFailure>().having(
            (e) => e.message,
            'message',
            contains('startScreen'),
          ),
        ),
      );
    });
  });

  group('EnsembleTestRunResult', () {
    test('summary counts pass and fail', () {
      final result = EnsembleTestRunResult(
        results: [
          EnsembleSingleTestResult.passed(testId: 'a', durationMs: 1),
          EnsembleSingleTestResult.failed(
            testId: 'b',
            durationMs: 2,
            error: 'oops',
          ),
        ],
      );
      expect(result.passedCount, 1);
      expect(result.failedCount, 1);
      expect(result.summary, '1 passed, 1 failed (2 total)');
    });
  });
}
