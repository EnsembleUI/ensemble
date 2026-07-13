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

    test('parses API mocks', () {
      const yaml = '''
id: login_success
startScreen: Login
mocks:
  apis:
    loginApi:
      delayMs: 100
      response:
        statusCode: 200
        body:
          token: test-token
steps:
  - expectApiCalled:
      name: loginApi
      times: 1
''';

      final test = EnsembleTestParser.parseString(yaml);
      expect(test.mocks.apis['loginApi']?.statusCode, 200);
      expect(test.mocks.apis['loginApi']?.delayMs, 100);
      expect(
        (test.mocks.apis['loginApi']?.body as Map)['token'],
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

    test('rejects root-level options in test files', () {
      const yaml = '''
id: visual_debug
startScreen: Home
options:
  screenshots:
    enabled: true
    platform: android
    model: Samsung Galaxy S20
    includeSteps: [tap, waitForNavigation]
    excludeSteps: [wait]
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
            contains('Move shared screenshots/performance settings'),
          ),
        ),
      );
    });

    test('parses suite config screenshots', () {
      const yaml = '''
screenshots:
  enabled: true
  platform: android
  model: Samsung Galaxy S20
  includeSteps: [tap, waitForNavigation]
  excludeSteps: [wait]
''';

      final config = EnsembleTestParser.parseConfigString(yaml);
      final screenshots = config.screenshots;
      expect(screenshots.enabled, isTrue);
      expect(screenshots.platform, 'android');
      expect(screenshots.model, 'Samsung Galaxy S20');
      expect(screenshots.includeSteps, ['tap', 'waitForNavigation']);
      expect(screenshots.excludeSteps, ['wait']);
      expect(screenshots.shouldCaptureStep('tap'), isTrue);
      expect(screenshots.shouldCaptureStep('wait'), isFalse);
      expect(screenshots.shouldCaptureStep('settle'), isFalse);
    });

    test('parses suite config performance', () {
      const yaml = '''
performance:
  enabled: true
''';

      final config = EnsembleTestParser.parseConfigString(yaml);
      expect(config.performance.enabled, isTrue);
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

  group('prerequisite and startScreen XOR', () {
    test('parses prerequisite-only test', () {
      const yaml = '''
id: continuation_flow
prerequisite: hello_home_renders
steps:
  - expectVisible:
      id: goodbye_title
''';

      final test = EnsembleTestParser.parseString(yaml);
      expect(test.id, 'continuation_flow');
      expect(test.startScreen, isNull);
      expect(test.prerequisite, 'hello_home_renders');
      expect(test.steps.single.type, 'expectVisible');
    });

    test('rejects when both startScreen and prerequisite are set', () {
      const yaml = '''
id: invalid_both
startScreen: Home
prerequisite: other
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

    test('rejects when neither startScreen nor prerequisite is set', () {
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
