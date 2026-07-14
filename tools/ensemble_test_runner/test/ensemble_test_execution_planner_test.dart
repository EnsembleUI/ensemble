import 'package:ensemble_test_runner/discovery/ensemble_test_execution_planner.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/parser/ensemble_test_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EnsembleTestExecutionPlanner', () {
    test('orders prerequisite chain before independent startScreen tests', () {
      final byId = {
        'chain_root': _def('a/chain_root.test.yaml', '''
id: chain_root
startScreen: Home
steps:
  - expectVisible:
      id: x
'''),
        'chain_child': _def('b/chain_child.test.yaml', '''
id: chain_child
prerequisite: chain_root
steps:
  - expectVisible:
      id: y
'''),
        'standalone': _def('z/standalone.test.yaml', '''
id: standalone
startScreen: Other
steps:
  - expectVisible:
      id: z
'''),
      };

      final order = EnsembleTestExecutionPlanner.orderIdsForTest(byId);
      expect(
          order.indexOf('chain_root'), lessThan(order.indexOf('chain_child')));
      expect(
          order.indexOf('chain_child'), lessThan(order.indexOf('standalone')));
    });

    test('detects circular prerequisites', () {
      final byId = {
        'a': _def('a.test.yaml', '''
id: a
prerequisite: b
steps:
  - expectVisible:
      id: x
'''),
        'b': _def('b.test.yaml', '''
id: b
prerequisite: a
steps:
  - expectVisible:
      id: y
'''),
      };

      expect(
        () => EnsembleTestExecutionPlanner.orderIdsForTest(byId),
        throwsA(isA<EnsembleTestFailure>()),
      );
    });

    test('selection includes prerequisite chain', () {
      final byId = {
        'login': _def('auth/login.test.yaml', '''
id: login
feature: auth
tags: [smoke]
startScreen: Login
steps:
  - expectVisible:
      id: login_button
'''),
        'profile': _def('auth/profile.test.yaml', '''
id: profile
feature: profile
tags: [regression]
prerequisite: login
steps:
  - expectVisible:
      id: profile_title
'''),
        'settings': _def('settings/settings.test.yaml', '''
id: settings
feature: settings
startScreen: Settings
steps:
  - expectVisible:
      id: settings_title
'''),
      };

      final order = EnsembleTestExecutionPlanner.selectAndOrderIdsForTest(
        byId,
        const EnsembleTestSelection(features: {'profile'}),
      );

      expect(order, ['login', 'profile']);
    });

    test('expands scenarios with bracketed ids and prerequisite chain',
        () async {
      const yaml = '''
id: home_scenarios
prerequisite: signin_to_gateway
scenarios:
  - id: v12_online
    vars:
      expectedDeviceCount: 2
  - id: v14_empty
    vars:
      expectedDeviceCount: 0
steps:
  - expectText:
      text: \${scenario.expectedDeviceCount}
''';

      final definitions =
          await EnsembleTestExecutionPlanner.parseDefinitionsForTest(
        'ensemble/apps/inhome/tests/home.test.yaml',
        yaml,
      );

      expect(
        definitions.map((definition) => definition.testCase.id),
        [
          'home_scenarios[v12_online]',
          'home_scenarios[v14_empty]',
        ],
      );
      expect(
        definitions[0].testCase.prerequisite,
        'signin_to_gateway',
      );
      expect(
        definitions[1].testCase.prerequisite,
        'home_scenarios[v12_online]',
      );
      expect(definitions[0].testCase.steps.single.args['text'], 2);
      expect(definitions[1].testCase.steps.single.args['text'], 0);
    });

    test('skips empty discovered test files', () async {
      final definitions =
          await EnsembleTestExecutionPlanner.parseDefinitionsForTest(
        'ensemble/apps/inhome/tests/commented.test.yaml',
        '''
# id: disabled_test
# startScreen: Home
# steps:
#   - expectVisible:
#       id: home_body
''',
      );

      expect(definitions, isEmpty);
    });

    test('loads JSON mock files and applies override order', () async {
      const yaml = '''
id: home_scenarios
startScreen: Home
mocks:
  - mocks/common.mock.json
  - mocks/\${scenario.behavior}.mock.json
scenarios:
  - id: online
    vars:
      behavior: online
steps:
  - expectVisible:
      id: home
''';
      final assets = {
        'suite/tests/mocks/common.mock.json': '''
{
  "getDevices": {
    "statusCode": 200,
    "body": {"count": 1}
  },
  "rootApi": {
    "body": {"from": "layer"}
  }
}
''',
        'suite/tests/mocks/online.mock.json': '''
{
  "getDevices": {
    "statusCode": 200,
    "delayMs": 125,
    "body": {"count": 2}
  },
  "scenarioApi": {
    "body": {"from": "scenario-layer"}
  }
}
''',
      };

      final definitions =
          await EnsembleTestExecutionPlanner.parseDefinitionsForTest(
        'suite/tests/home.test.yaml',
        yaml,
        assetLoader: (path) async => assets[path]!,
      );

      final mocks = definitions.single.testCase.mocks.apis;
      expect((mocks['getDevices']!.body as Map)['count'], 2);
      expect(mocks['getDevices']!.delayMs, 125);
      expect((mocks['rootApi']!.body as Map)['from'], 'layer');
      expect((mocks['scenarioApi']!.body as Map)['from'], 'scenario-layer');
    });

    test('selection by base scenario suite id includes expanded scenarios',
        () async {
      const yaml = '''
id: home_scenarios
startScreen: Home
scenarios:
  - id: first
    vars: {}
  - id: second
    vars: {}
steps:
  - expectVisible:
      id: home
''';
      final definitions =
          await EnsembleTestExecutionPlanner.parseDefinitionsForTest(
        'suite/tests/home.test.yaml',
        yaml,
      );
      final byId = {
        for (final definition in definitions)
          definition.testCase.id: definition,
      };

      final order = EnsembleTestExecutionPlanner.selectAndOrderIdsForTest(
        byId,
        const EnsembleTestSelection(ids: {'home_scenarios'}),
      );

      expect(order, [
        'home_scenarios[first]',
        'home_scenarios[second]',
      ]);
    });
  });
}

EnsembleTestDefinition _def(String assetPath, String yaml) {
  return EnsembleTestDefinition(
    assetPath: assetPath,
    testCase: EnsembleTestParser.parseString(yaml),
  );
}
