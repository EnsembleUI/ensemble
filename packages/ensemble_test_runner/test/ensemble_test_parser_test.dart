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
