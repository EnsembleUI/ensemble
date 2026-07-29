import 'package:ensemble_test_runner/discovery/ensemble_test_execution_planner.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/parser/ensemble_test_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EnsembleTestExecutionPlanner', () {
    test('orders session producer before session consumers', () {
      final byId = {
        'signin': _def('a/signin.test.yaml', '''
id: signin
startScreen: Home
steps:
  - expectVisible:
      id: x
'''),
        'home': _def('b/home.test.yaml', '''
id: home
session: signin
startScreen: Home
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
      expect(order.indexOf('signin'), lessThan(order.indexOf('home')));
    });

    test('detects circular sessions', () {
      final byId = {
        'a': _def('a.test.yaml', '''
id: a
session: b
startScreen: Home
steps:
  - expectVisible:
      id: x
'''),
        'b': _def('b.test.yaml', '''
id: b
session: a
startScreen: Home
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

    test('selection includes session producer', () {
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
session: login
startScreen: Profile
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

    test('orders and selects a reusable session producer', () {
      final byId = {
        'signin': _def('auth/signin.test.yaml', '''
id: signin
startScreen: Login
steps:
  - expectVisible: {id: login}
'''),
        'home': _def('home/home.test.yaml', '''
id: home
session: signin
startScreen: Home
steps:
  - expectVisible: {id: home}
'''),
      };

      final order = EnsembleTestExecutionPlanner.selectAndOrderIdsForTest(
        byId,
        const EnsembleTestSelection(ids: {'home'}),
      );

      expect(order, ['signin', 'home']);
    });

    test('expands scenarios with bracketed ids', () async {
      const yaml = '''
id: home_scenarios
session: signin_to_gateway
startScreen: Home
scenarios:
  - id: v12_online
    description: V12 online state.
    vars:
      expectedDeviceCount: 2
  - id: v14_empty
    description: V14 empty state.
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
      expect(definitions[0].testCase.session, 'signin_to_gateway');
      expect(definitions[1].testCase.session, 'signin_to_gateway');
      expect(definitions[0].testCase.scenarioId, 'v12_online');
      expect(definitions[0].testCase.scenarioDescription, 'V12 online state.');
      expect(definitions[1].testCase.scenarioId, 'v14_empty');
      expect(definitions[1].testCase.scenarioDescription, 'V14 empty state.');
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

    test('resolves service URLs in test values', () async {
      final definitions =
          await EnsembleTestExecutionPlanner.parseDefinitionsForTest(
        'suite/tests/service.test.yaml',
        '''
id: service_url
startScreen: Login
steps:
  - httpRequest:
      url: \${services.modemStub.url}/reset
''',
        services: const [
          TestServiceConfig(
            name: 'modemStub',
            command: 'python',
            url: 'http://127.0.0.1:5001',
          ),
        ],
      );

      expect(
        definitions.single.testCase.steps.single.args['url'],
        'http://127.0.0.1:5001/reset',
      );
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

    test('resolves mocks directory from suite root for nested test files',
        () async {
      const yaml = '''
id: nested_mock_test
startScreen: Home
mocks:
  - mocks/common/common.mock.json
  - mocks/extender-positioning/weak.mock.json
steps:
  - expectVisible:
      id: home
''';
      final assets = {
        'suite/tests/mocks/common/common.mock.json': '''
{
  "getDevices": {
    "body": {"count": 1}
  }
}
''',
        'suite/tests/mocks/extender-positioning/base.mock.json': '''
{
  "getSignal": {
    "body": {"signal": "good"}
  }
}
''',
        'suite/tests/mocks/extender-positioning/weak.mock.json': '''
{
  "\$extends": "mocks/extender-positioning/base.mock.json",
  "getSignal": {
    "\$merge": {
      "body.signal": "weak"
    }
  }
}
''',
      };

      final definitions =
          await EnsembleTestExecutionPlanner.parseDefinitionsForTest(
        'suite/tests/extender-positioning/extender-too-far.test.yaml',
        yaml,
        assetLoader: (path) async => assets[path]!,
      );

      final mocks = definitions.single.testCase.mocks.apis;
      expect((mocks['getDevices']!.body as Map)['count'], 1);
      expect((mocks['getSignal']!.body as Map)['signal'], 'weak');
    });

    test('applies suite mocks before test mocks', () async {
      const yaml = '''
id: home_suite_mocks
startScreen: Home
mocks:
  - mocks/test.mock.json
steps:
  - expectVisible:
      id: home
''';
      final assets = {
        'suite/tests/mocks/suite.mock.json': '''
{
  "getDevices": {
    "body": {"count": 1}
  },
  "suiteOnly": {
    "body": {"from": "suite"}
  }
}
''',
        'suite/tests/mocks/test.mock.json': '''
{
  "getDevices": {
    "body": {"count": 2}
  }
}
''',
      };

      final definitions =
          await EnsembleTestExecutionPlanner.parseDefinitionsForTest(
        'suite/tests/home.test.yaml',
        yaml,
        suiteMockFiles: const ['mocks/suite.mock.json'],
        assetLoader: (path) async => assets[path]!,
      );

      final mocks = definitions.single.testCase.mocks.apis;
      expect((mocks['getDevices']!.body as Map)['count'], 2);
      expect((mocks['suiteOnly']!.body as Map)['from'], 'suite');
    });

    test('applies suite initialState before test initialState', () async {
      const yaml = '''
id: home_suite_initial_state
startScreen: Home
initialState:
  storage:
    targetExtenderSerial: JB1
  env:
    DEBUG: true
steps:
  - expectVisible:
      id: home
''';

      final definitions =
          await EnsembleTestExecutionPlanner.parseDefinitionsForTest(
        'suite/tests/home.test.yaml',
        yaml,
        suiteInitialState: const {
          'storage': {
            'apiUrl': 'http://ensemble.test/ws',
            'targetExtenderSerial': 'SUITE',
          },
          'env': {'APP_LOCALE': 'nl'},
        },
      );

      final initialState = definitions.single.testCase.initialState;
      expect(
        (initialState['storage'] as Map)['apiUrl'],
        'http://ensemble.test/ws',
      );
      expect(
        (initialState['storage'] as Map)['targetExtenderSerial'],
        'JB1',
      );
      expect((initialState['env'] as Map)['APP_LOCALE'], 'nl');
      expect((initialState['env'] as Map)['DEBUG'], true);
    });

    test('applies suite profile when test omits profile', () async {
      const yaml = '''
id: home_suite_profile
startScreen: Home
initialState:
  storage:
    screen: home
steps:
  - expectVisible:
      id: home
''';
      final assets = {
        'suite/tests/mocks/hgw/common.mock.json': '''
{
  "getDevices": {
    "body": {"count": 2}
  }
}
''',
      };

      final definitions =
          await EnsembleTestExecutionPlanner.parseDefinitionsForTest(
        'suite/tests/home.test.yaml',
        yaml,
        suiteDefaultProfile: 'hgw_v12',
        suiteProfiles: const {
          'hgw_v12': TestProfile(
            mockFiles: ['mocks/hgw/common.mock.json'],
            initialState: {
              'storage': {'deviceType': 'HGW_SAH'},
              'keychain': {'adminPassword': 'dummyPassword'},
            },
          ),
        },
        assetLoader: (path) async => assets[path]!,
      );

      final test = definitions.single.testCase;
      expect((test.mocks.apis['getDevices']!.body as Map)['count'], 2);
      expect((test.initialState['storage'] as Map)['deviceType'], 'HGW_SAH');
      expect((test.initialState['storage'] as Map)['screen'], 'home');
      expect(
        (test.initialState['keychain'] as Map)['adminPassword'],
        'dummyPassword',
      );
    });

    test('explicit profile overrides suite profile', () async {
      const yaml = '''
id: home_fwa_profile
profiles: fwa_arc
startScreen: Home_FWA
steps:
  - expectVisible:
      id: home
''';
      final assets = {
        'suite/tests/mocks/hgw/common.mock.json': '''
{
  "getDevices": {
    "body": {"source": "hgw"}
  }
}
''',
        'suite/tests/mocks/fwa/common.mock.json': '''
{
  "getDevices": {
    "body": {"source": "fwa"}
  },
  "getFWAStatus": {
    "body": {"mobile_status": {"Status": "True"}}
  }
}
''',
      };

      final definitions =
          await EnsembleTestExecutionPlanner.parseDefinitionsForTest(
        'suite/tests/fwa/home.test.yaml',
        yaml,
        suiteDefaultProfile: 'hgw_v12',
        suiteProfiles: const {
          'hgw_v12': TestProfile(
            mockFiles: ['mocks/hgw/common.mock.json'],
            initialState: {
              'storage': {'deviceType': 'HGW_SAH'},
            },
          ),
          'fwa_arc': TestProfile(
            mockFiles: ['mocks/fwa/common.mock.json'],
            initialState: {
              'storage': {'deviceType': 'FWA_ARC'},
              'keychain': {'fwaPassword': 'dummyPassword'},
            },
          ),
        },
        assetLoader: (path) async => assets[path]!,
      );

      final test = definitions.single.testCase;
      expect(test.profile, 'fwa_arc');
      expect((test.mocks.apis['getDevices']!.body as Map)['source'], 'fwa');
      expect(test.mocks.apis, contains('getFWAStatus'));
      expect((test.initialState['storage'] as Map)['deviceType'], 'FWA_ARC');
      expect(
        (test.initialState['keychain'] as Map)['fwaPassword'],
        'dummyPassword',
      );
    });

    test('expands test profiles into profile-specific runs', () async {
      const yaml = '''
id: hgw_home
profiles:
  - hgw_v12
  - hgw_v10
startScreen: Home
session: signed_in
steps:
  - expectVisible:
      id: home
''';
      final assets = {
        'suite/tests/mocks/hgw/v12.mock.json': '''
{
  "getDeviceInfo": {
    "body": {"device": "v12"}
  }
}
''',
        'suite/tests/mocks/hgw/v10.mock.json': '''
{
  "getDeviceInfo": {
    "body": {"device": "v10"}
  }
}
''',
      };

      final definitions =
          await EnsembleTestExecutionPlanner.parseDefinitionsForTest(
        'suite/tests/home.test.yaml',
        yaml,
        suiteProfiles: const {
          'hgw_v12': TestProfile(
            mockFiles: ['mocks/hgw/v12.mock.json'],
            initialState: {
              'storage': {'deviceType': 'v12'},
            },
          ),
          'hgw_v10': TestProfile(
            mockFiles: ['mocks/hgw/v10.mock.json'],
            initialState: {
              'storage': {'deviceType': 'v10'},
            },
          ),
        },
        assetLoader: (path) async => assets[path]!,
      );

      expect(
        definitions.map((definition) => definition.testCase.id),
        ['hgw_home[hgw_v12]', 'hgw_home[hgw_v10]'],
      );
      expect(
        definitions.map((definition) => definition.testCase.session),
        ['signed_in[hgw_v12]', 'signed_in[hgw_v10]'],
      );
      expect(
        definitions.map((definition) {
          final api = definition.testCase.mocks.apis['getDeviceInfo']!;
          return (api.body as Map)['device'];
        }),
        ['v12', 'v10'],
      );
    });

    test('profile selection keeps only matching expanded profile runs',
        () async {
      final plan = await EnsembleTestExecutionPlanner.buildForTest(
        assetContents: {
          'suite/tests/signin.test.yaml': '''
id: signed_in
startScreen: Login
steps:
  - expectVisible:
      id: login
''',
          'suite/tests/home.test.yaml': '''
id: hgw_home
session: signed_in
startScreen: Home
steps:
  - expectVisible:
      id: home
''',
        },
        config: const EnsembleTestConfig(
          defaultProfile: 'hgw_sah',
          profileGroups: {
            'hgw_sah': ['hgw_v12', 'hgw_v10'],
          },
          profiles: {
            'hgw_v12': TestProfile(),
            'hgw_v10': TestProfile(),
          },
        ),
        selection: const EnsembleTestSelection(profiles: {'hgw_v10'}),
      );

      expect(
        plan.ordered.map((definition) => definition.testCase.id),
        ['signed_in[hgw_v10]', 'hgw_home[hgw_v10]'],
      );
      expect(
        plan.ordered.map((definition) => definition.testCase.profile),
        ['hgw_v10', 'hgw_v10'],
      );
    });

    test('profile group selection expands to matching concrete profiles',
        () async {
      final plan = await EnsembleTestExecutionPlanner.buildForTest(
        assetContents: {
          'suite/tests/home.test.yaml': '''
id: hgw_home
startScreen: Home
steps:
  - expectVisible:
      id: home
''',
          'suite/tests/fwa.test.yaml': '''
id: fwa_home
profiles: fwa_arc
startScreen: Home
steps:
  - expectVisible:
      id: home
''',
        },
        config: const EnsembleTestConfig(
          defaultProfile: 'hgw_sah',
          profileGroups: {
            'hgw_sah': ['hgw_v12'],
          },
          profiles: {
            'hgw_v12': TestProfile(),
            'fwa_arc': TestProfile(),
          },
        ),
        selection: const EnsembleTestSelection(profiles: {'hgw_sah'}),
      );

      expect(
        plan.ordered.map((definition) => definition.testCase.id),
        ['hgw_home'],
      );
      expect(plan.ordered.single.testCase.profile, 'hgw_v12');
    });

    test('expands suite default group for tests without profile selectors',
        () async {
      const yaml = '''
id: hgw_home
startScreen: Home
steps:
  - expectVisible:
      id: home
''';
      final assets = {
        'suite/tests/mocks/hgw/v12.mock.json': '''
{
  "getDeviceInfo": {
    "body": {"device": "v12"}
  }
}
''',
        'suite/tests/mocks/hgw/v10.mock.json': '''
{
  "getDeviceInfo": {
    "body": {"device": "v10"}
  }
}
''',
      };

      final definitions =
          await EnsembleTestExecutionPlanner.parseDefinitionsForTest(
        'suite/tests/home.test.yaml',
        yaml,
        suiteDefaultProfile: 'hgw_sah',
        suiteProfileGroups: const {
          'hgw_sah': ['hgw_v12', 'hgw_v10'],
        },
        suiteProfiles: const {
          'hgw_v12': TestProfile(
            mockFiles: ['mocks/hgw/v12.mock.json'],
          ),
          'hgw_v10': TestProfile(
            mockFiles: ['mocks/hgw/v10.mock.json'],
          ),
        },
        assetLoader: (path) async => assets[path]!,
      );

      expect(
        definitions.map((definition) => definition.testCase.id),
        ['hgw_home[hgw_v12]', 'hgw_home[hgw_v10]'],
      );
    });

    test('test profiles selector overrides suite default group', () async {
      const yaml = '''
id: fwa_home
profiles: fwa
startScreen: FwaHome
steps:
  - expectVisible:
      id: home
''';
      final assets = {
        'suite/tests/mocks/fwa/arc.mock.json': '''
{
  "getFwaStatus": {
    "body": {"device": "fwa"}
  }
}
''',
      };

      final definitions =
          await EnsembleTestExecutionPlanner.parseDefinitionsForTest(
        'suite/tests/fwa/home.test.yaml',
        yaml,
        suiteDefaultProfile: 'hgw_sah',
        suiteProfileGroups: const {
          'hgw_sah': ['hgw_v12'],
          'fwa': ['fwa_arc'],
        },
        suiteProfiles: const {
          'hgw_v12': TestProfile(),
          'fwa_arc': TestProfile(
            mockFiles: ['mocks/fwa/arc.mock.json'],
          ),
        },
        assetLoader: (path) async => assets[path]!,
      );

      final test = definitions.single.testCase;
      expect(test.id, 'fwa_home');
      expect(test.profile, 'fwa_arc');
      expect(test.mocks.apis, contains('getFwaStatus'));
    });

    test('fails clearly for unknown explicit profile', () async {
      const yaml = '''
id: missing_profile_test
profiles: missing
startScreen: Home
steps:
  - expectVisible:
      id: home
''';

      expect(
        () => EnsembleTestExecutionPlanner.parseDefinitionsForTest(
          'suite/tests/home.test.yaml',
          yaml,
          suiteProfiles: const {
            'hgw_v12': TestProfile(),
          },
        ),
        throwsA(
          isA<EnsembleTestFailure>().having(
            (error) => error.message,
            'message',
            contains('references unknown profile "missing"'),
          ),
        ),
      );
    });

    test('expands devices into per-device runs', () async {
      const yaml = '''
id: home_devices
startScreen: Home
session: signed_in
steps:
  - expectVisible:
      id: home
''';

      final definitions =
          await EnsembleTestExecutionPlanner.parseDefinitionsForTest(
        'suite/tests/home.test.yaml',
        yaml,
        suiteInitialState: const {
          'env': {'APP_LOCALE': 'nl'},
        },
        suiteDevices: const [
          TestDeviceTarget(
            id: 'android_nl',
            platform: 'android',
            model: 'Samsung Galaxy S20',
            locale: 'nl',
            theme: 'light',
          ),
          TestDeviceTarget(
            id: 'iphone_en',
            platform: 'ios',
            model: 'iPhone 15 Pro',
            locale: 'en',
            theme: 'dark',
          ),
        ],
      );

      expect(definitions.map((d) => d.testCase.id), [
        'home_devices[android_nl]',
        'home_devices[iphone_en]',
      ]);
      expect(
        definitions.map((d) => d.testCase.session),
        ['signed_in[android_nl]', 'signed_in[iphone_en]'],
      );
      expect(
        definitions.map((d) => d.testCase.resolvedScreenshotSheetId).toList(),
        ['home_devices[android_nl]', 'home_devices[iphone_en]'],
      );
      expect(
        definitions.map((d) => d.testCase.deviceTarget?.theme),
        ['light', 'dark'],
      );
      expect(
        definitions.every(
          (d) => !d.testCase.startScreenInputs.containsKey('themeMode'),
        ),
        isTrue,
      );
      expect(
        (definitions[0].testCase.initialState['env'] as Map)['APP_LOCALE'],
        'nl',
      );
      expect(
        (definitions[1].testCase.initialState['env'] as Map)['APP_LOCALE'],
        'en',
      );
      expect(definitions[0].testCase.deviceTarget?.model, 'Samsung Galaxy S20');
      expect(definitions[1].testCase.deviceTarget?.model, 'iPhone 15 Pro');
      expect(definitions[0].testCase.metadataJson['device'], {
        'id': 'android_nl',
        'platform': 'android',
        'model': 'Samsung Galaxy S20',
        'locale': 'nl',
        'theme': 'light',
        'label': 'Samsung Galaxy S20 · nl · light',
      });
    });

    test('exact selection filters after device expansion and keeps session',
        () async {
      final plan = await EnsembleTestExecutionPlanner.buildForTest(
        assetContents: const {
          'suite/tests/login.test.yaml': '''
id: login
startScreen: Login
steps:
  - expectVisible:
      id: login_button
''',
          'suite/tests/home.test.yaml': '''
id: home
session: login
startScreen: Home
steps:
  - expectVisible:
      id: home_body
''',
        },
        config: const EnsembleTestConfig(
          devices: [
            TestDeviceTarget(
              id: 'iphone',
              platform: 'ios',
              model: 'iPhone 15 Pro',
            ),
            TestDeviceTarget(
              id: 'android',
              platform: 'android',
              model: 'Samsung Galaxy S20',
            ),
          ],
        ),
        selection: const EnsembleTestSelection(
          exactIds: {'home[android]'},
        ),
      );

      expect(
        plan.ordered.map((definition) => definition.testCase.id),
        ['login[android]', 'home[android]'],
      );
    });

    test('device matrix leaves startScreenInputs languageCode unchanged',
        () async {
      const yaml = '''
id: init_locale
startScreen: InitApp
startScreenInputs:
  languageCode: nl-NL
  token: abc
steps:
  - expectVisible:
      id: home
''';

      final definitions =
          await EnsembleTestExecutionPlanner.parseDefinitionsForTest(
        'suite/tests/init.test.yaml',
        yaml,
        suiteDevices: const [
          TestDeviceTarget(
            id: 'android_nl',
            platform: 'android',
            model: 'Samsung Galaxy S20',
            locale: 'nl',
          ),
          TestDeviceTarget(
            id: 'iphone_en',
            platform: 'ios',
            model: 'iPhone 15 Pro',
            locale: 'en',
          ),
        ],
      );

      expect(
        definitions.map((d) => d.testCase.startScreenInputs['languageCode']),
        ['nl-NL', 'nl-NL'],
      );
      expect(definitions[0].testCase.startScreenInputs['token'], 'abc');
      expect(
        (definitions[0].testCase.initialState['env'] as Map?)?['APP_LOCALE'],
        'nl',
      );
      expect(
        (definitions[1].testCase.initialState['env'] as Map?)?['APP_LOCALE'],
        'en',
      );
    });

    test('merges file and inline mocks with inline overrides', () async {
      const yaml = '''
id: home_inline_mocks
startScreen: Home
mocks:
  - mocks/common.mock.json
  - getDevices:
      body: {count: 3}
    inlineOnly:
      delayMs: 25
      body: {from: inline}
steps:
  - expectVisible:
      id: home
''';
      final assets = {
        'suite/tests/mocks/common.mock.json': '''
{
  "getDevices": {
    "body": {"count": 1}
  },
  "fileOnly": {
    "body": {"from": "file"}
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
      expect((mocks['getDevices']!.body as Map)['count'], 3);
      expect((mocks['fileOnly']!.body as Map)['from'], 'file');
      expect(mocks['inlineOnly']!.delayMs, 25);
      expect((mocks['inlineOnly']!.body as Map)['from'], 'inline');
    });

    test('resolves \$extends and \$merge mock composition', () async {
      const yaml = '''
id: home_extends_merge
startScreen: Home
mocks:
  - mocks/patch.mock.json
steps:
  - expectVisible:
      id: home
''';
      final assets = {
        'suite/tests/mocks/base.mock.json': '''
{
  "getDevices": {
    "body": {
      "status": [
        { "Name": "A", "Active": true, "SignalStrength": -70 }
      ]
    }
  }
}
''',
        'suite/tests/mocks/patch.mock.json': '''
{
  "\$extends": "mocks/base.mock.json",
  "getDevices": {
    "\$merge": {
      "body.status[0].SignalStrength": -26,
      "body.status[0].Active": false
    }
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

      final device = (((definitions.single.testCase.mocks.apis['getDevices']!
              .body as Map)['status'] as List)
          .single) as Map;
      expect(device['Name'], 'A');
      expect(device['SignalStrength'], -26);
      expect(device['Active'], isFalse);
    });

    test('applies inline \$merge onto prior mock files', () async {
      const yaml = '''
id: home_inline_merge
startScreen: Home
mocks:
  - mocks/base.mock.json
  - getDevices:
      \$merge:
        body.status[0].SignalStrength: -65
steps:
  - expectVisible:
      id: home
''';
      final assets = {
        'suite/tests/mocks/base.mock.json': '''
{
  "getDevices": {
    "body": {
      "status": [
        { "Name": "A", "SignalStrength": -78 }
      ]
    }
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

      final device = (((definitions.single.testCase.mocks.apis['getDevices']!
              .body as Map)['status'] as List)
          .single) as Map;
      expect(device['Name'], 'A');
      expect(device['SignalStrength'], -65);
    });

    test('loads sequential JSON mock responses', () async {
      const yaml = '''
id: recommendation_flow
startScreen: Home
mocks:
  - mocks/recommendations.mock.json
steps:
  - expectVisible:
      id: home
''';
      final assets = {
        'suite/tests/mocks/recommendations.mock.json': '''
{
  "listenForRecommendations": {
    "responses": [
      {"body": {"active": [{"type": "first"}]}},
      {"delayMs": 50, "body": {"active": [{"type": "second"}]}}
    ]
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

      final responses = definitions
          .single.testCase.mocks.apis['listenForRecommendations']!.responses;

      expect(responses, hasLength(2));
      expect((responses.first.body as Map)['active'], [
        {'type': 'first'},
      ]);
      expect(responses.last.delayMs, 50);
      expect((responses.last.body as Map)['active'], [
        {'type': 'second'},
      ]);
    });

    test('loads inline step mocks', () async {
      const yaml = '''
id: step_inline_mocks
startScreen: Home
steps:
  - mocks:
      getDevices:
        delayMs: 10
        body: {count: 2}
  - waitForApi:
      name: getDevices
''';

      final definitions =
          await EnsembleTestExecutionPlanner.parseDefinitionsForTest(
        'suite/tests/home.test.yaml',
        yaml,
      );

      final step = definitions.single.testCase.steps.first;
      expect(step.type, 'mocks');
      expect(step.mocks.apis['getDevices']!.delayMs, 10);
      expect((step.mocks.apis['getDevices']!.body as Map)['count'], 2);
    });

    test('loads file-based step mocks', () async {
      const yaml = '''
id: step_file_mocks
startScreen: Home
steps:
  - mocks:
      - mocks/devices.mock.json
  - waitForApi:
      name: getDevices
''';
      final assets = {
        'suite/tests/mocks/devices.mock.json': '''
{
  "getDevices": {
    "body": {"count": 4}
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

      final step = definitions.single.testCase.steps.first;
      expect(step.type, 'mocks');
      expect((step.mocks.apis['getDevices']!.body as Map)['count'], 4);
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

    test('selection ignores missing CLI inputs in unrelated tests', () async {
      final assets = <String, String>{
        'suite/tests/selected.test.yaml': '''
id: selected_test
startScreen: Home
steps:
  - expectVisible:
      id: home
''',
        'suite/tests/unrelated.test.yaml': r'''
id: unrelated_test
startScreen: Login
initialState:
  keychain:
    adminPassword: ${inputs.password}
steps:
  - expectVisible:
      id: login
''',
      };

      final plan = await EnsembleTestExecutionPlanner.buildForTest(
        assetContents: assets,
        selection: const EnsembleTestSelection(ids: {'selected_test'}),
      );

      expect(
        plan.ordered.map((definition) => definition.testCase.id).toList(),
        ['selected_test'],
      );
    });

    test('path selection keeps device-expanded ids (parallel shard case)',
        () async {
      final assets = <String, String>{
        'suite/tests/home.test.yaml': '''
id: home_wifi
startScreen: Home
steps:
  - expectVisible:
      id: home
''',
        'suite/tests/other.test.yaml': '''
id: other_flow
startScreen: Other
steps:
  - expectVisible:
      id: other
''',
      };

      final plan = await EnsembleTestExecutionPlanner.buildForTest(
        assetContents: assets,
        config: const EnsembleTestConfig(
          devices: [
            TestDeviceTarget(
              id: 'android_nl',
              platform: 'android',
              model: 'Samsung Galaxy S20',
              locale: 'nl',
            ),
            TestDeviceTarget(
              id: 'iphone_en',
              platform: 'ios',
              model: 'iPhone 15 Pro',
              locale: 'en',
            ),
          ],
        ),
        selection: const EnsembleTestSelection(
          paths: {'suite/tests/home.test.yaml'},
        ),
      );

      expect(
        plan.ordered.map((definition) => definition.testCase.id).toList(),
        ['home_wifi[android_nl]', 'home_wifi[iphone_en]'],
      );
    });
  });
}

EnsembleTestDefinition _def(String assetPath, String yaml) {
  return EnsembleTestDefinition(
    assetPath: assetPath,
    testCase: EnsembleTestParser.parseString(yaml),
  );
}
