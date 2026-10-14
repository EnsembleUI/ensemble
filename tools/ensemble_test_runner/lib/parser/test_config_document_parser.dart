import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/parser/config_target_parser.dart';
import 'package:ensemble_test_runner/parser/parser_value_decoder.dart';
import 'package:yaml/yaml.dart';

/// Callback used by the config parser to normalize mock declarations.
typedef MocksNodeParser = ({List<String> files, Map<String, dynamic> inline})
    Function(
  dynamic node, {
  required String testId,
  required Map<String, dynamic> inputs,
  required Map<String, dynamic> scenario,
  String? scenarioId,
});

/// Parses and validates suite-level configuration documents.
///
/// The parser owns configuration shape and policy validation while the parent
/// parser supplies mock normalization. This keeps the public parser facade
/// stable and makes configuration parsing independently testable.
class TestConfigDocumentParser {
  static EnsembleTestConfig parse(
    YamlMap node, {
    required MocksNodeParser parseMocks,
  }) {
    const allowedKeys = {
      'mode',
      'services',
      'mocks',
      'profiles',
      'initialState',
      'devices',
      'screenshots',
      'performance',
      'timers',
      'dumpTree',
      'logApiCalls',
      'logStorage',
      'wifi',
    };
    for (final key in node.keys) {
      if (!allowedKeys.contains(key.toString())) {
        throw EnsembleTestFailure(
          'Unsupported test config key "$key". Supported keys: '
          '${allowedKeys.join(', ')}',
        );
      }
    }

    final modeNode = node['mode'];
    final servicesNode = node['services'];
    final mocksNode = node['mocks'];
    final profilesNode = node['profiles'];
    final initialStateNode = node['initialState'];
    final devicesNode = node['devices'];
    final screenshotsNode = node['screenshots'];
    final performanceNode = node['performance'];
    final timersNode = node['timers'];
    final dumpTreeNode = node['dumpTree'];
    final logApiCallsNode = node['logApiCalls'];
    final logStorageNode = node['logStorage'];
    final wifiNode = node['wifi'];
    if (modeNode != null &&
        modeNode.toString() != 'widget' &&
        modeNode.toString() != 'integration') {
      throw EnsembleTestFailure('"mode" must be "widget" or "integration"');
    }
    if (servicesNode != null && servicesNode is! YamlList) {
      throw EnsembleTestFailure('"services" must be a list');
    }
    if (mocksNode != null && mocksNode is! YamlList && mocksNode is! YamlMap) {
      throw EnsembleTestFailure(
        '"mocks" must be either a list of .mock.json files or an inline map '
        'of API mock responses.',
      );
    }
    if (profilesNode != null && profilesNode is! YamlMap) {
      throw EnsembleTestFailure('"profiles" must be a map');
    }
    if (initialStateNode != null && initialStateNode is! YamlMap) {
      throw EnsembleTestFailure('"initialState" must be a map');
    }
    if (devicesNode != null && devicesNode is! YamlList) {
      throw EnsembleTestFailure('"devices" must be a list');
    }
    if (screenshotsNode != null && screenshotsNode is! YamlMap) {
      throw EnsembleTestFailure('"screenshots" must be a map');
    }
    if (screenshotsNode is YamlMap) {
      for (final key in const ['platform', 'model', 'devices']) {
        if (screenshotsNode.containsKey(key)) {
          throw EnsembleTestFailure(
            '"screenshots.$key" is no longer supported. Define devices at the '
            'config root under "devices" (platform, model, optional locale/'
            'theme).',
          );
        }
      }
    }
    if (performanceNode != null && performanceNode is! YamlMap) {
      throw EnsembleTestFailure('"performance" must be a map');
    }
    if (timersNode != null && timersNode is! YamlMap) {
      throw EnsembleTestFailure('"timers" must be a map');
    }
    if (dumpTreeNode != null && dumpTreeNode is! YamlMap) {
      throw EnsembleTestFailure('"dumpTree" must be a map');
    }
    if (logApiCallsNode != null && logApiCallsNode is! YamlMap) {
      throw EnsembleTestFailure('"logApiCalls" must be a map');
    }
    if (logStorageNode != null && logStorageNode is! YamlMap) {
      throw EnsembleTestFailure('"logStorage" must be a map');
    }
    if (wifiNode != null && wifiNode is! YamlMap) {
      throw EnsembleTestFailure('"wifi" must be a map');
    }

    final parsedMocks = parseMocks(
      mocksNode,
      testId: 'tests/config.yaml',
      inputs: const {},
      scenario: const {},
    );

    final parsedProfiles = _parseProfilesConfig(
      profilesNode,
      parseMocks: parseMocks,
    );

    return EnsembleTestConfig(
      mode: modeNode?.toString() == 'integration'
          ? ExecutionMode.integration
          : ExecutionMode.widget,
      services: ConfigTargetParser.parseServices(servicesNode),
      mockFiles: parsedMocks.files,
      inlineMocks: parsedMocks.inline,
      initialState: ParserValueDecoder.toStringDynamicMap(
        initialStateNode,
        inputs: const {},
      ),
      defaultProfile: parsedProfiles.defaultProfile,
      profiles: parsedProfiles.definitions,
      profileGroups: parsedProfiles.groups,
      devices: ConfigTargetParser.parseDevices(devicesNode),
      screenshots: screenshotsNode == null
          ? const ScreenshotConfig()
          : ScreenshotConfig(
              enabled: screenshotsNode['enabled'] == true,
              includeSteps: ParserValueDecoder.toStringList(
                  screenshotsNode['includeSteps']),
              excludeSteps: ParserValueDecoder.toStringList(
                  screenshotsNode['excludeSteps']),
            ),
      performance: performanceNode == null
          ? const PerformanceConfig()
          : PerformanceConfig(
              enabled: performanceNode['enabled'] == true,
            ),
      timers: timersNode == null
          ? const TimerRewriteConfig()
          : TimerRewriteConfig(
              enabled: timersNode['enabled'] == true,
              maxStartAfterSeconds: optionalNonNegativeInt(
                timersNode['maxStartAfterSeconds'],
                fallback: 1,
                fieldName: 'timers.maxStartAfterSeconds',
              ),
              maxRepeatIntervalSeconds: optionalNonNegativeInt(
                timersNode['maxRepeatIntervalSeconds'],
                fallback: 1,
                fieldName: 'timers.maxRepeatIntervalSeconds',
              ),
              maxNumberOfTimes: timersNode['maxNumberOfTimes'] == null
                  ? null
                  : optionalNonNegativeInt(
                      timersNode['maxNumberOfTimes'],
                      fallback: 0,
                      fieldName: 'timers.maxNumberOfTimes',
                    ),
              maxNumberOfTimesByScreen:
                  _parseScreenTimerCaps(timersNode['maxNumberOfTimesByScreen']),
            ),
      dumpTree: dumpTreeNode == null
          ? const DumpTreeConfig()
          : DumpTreeConfig(
              enabled: dumpTreeNode['enabled'] == true,
            ),
      logApiCalls: logApiCallsNode == null
          ? const LogApiCallsConfig()
          : LogApiCallsConfig(
              enabled: logApiCallsNode['enabled'] != false,
            ),
      logStorage: logStorageNode == null
          ? const LogStorageConfig()
          : LogStorageConfig(
              enabled: logStorageNode['enabled'] == true,
              key: logStorageNode['key']?.toString(),
            ),
      wifi: _parseWifiConfig(
        wifiNode,
        sourceLabel: 'tests/config.yaml',
      ),
    );
  }

  static ({
    String? defaultProfile,
    Map<String, List<String>> groups,
    Map<String, TestProfile> definitions,
  }) _parseProfilesConfig(
    dynamic node, {
    required MocksNodeParser parseMocks,
  }) {
    if (node == null) {
      return (
        defaultProfile: null,
        groups: const <String, List<String>>{},
        definitions: const <String, TestProfile>{},
      );
    }
    if (node is! YamlMap) {
      throw EnsembleTestFailure('"profiles" must be a map');
    }

    const allowedKeys = {'default', 'groups', 'definitions'};
    for (final key in node.keys) {
      if (!allowedKeys.contains(key.toString())) {
        throw EnsembleTestFailure(
          'Unsupported profiles key "$key". Supported keys: '
          '${allowedKeys.join(', ')}',
        );
      }
    }

    final defaultProfile = _optionalString(node['default']);
    final groups = _parseProfileGroups(node['groups']);
    final definitions = _parseProfileDefinitions(
      node['definitions'],
      parseMocks: parseMocks,
    );
    if (defaultProfile != null &&
        !definitions.containsKey(defaultProfile) &&
        !groups.containsKey(defaultProfile)) {
      throw EnsembleTestFailure(
        'profiles.default "$defaultProfile" must reference a profile from '
        'profiles.definitions or a group from profiles.groups.',
      );
    }
    _validateProfileGroups(groups, definitions);

    return (
      defaultProfile: defaultProfile,
      groups: groups,
      definitions: definitions,
    );
  }

  static Map<String, TestProfile> _parseProfileDefinitions(
    dynamic node, {
    required MocksNodeParser parseMocks,
  }) {
    if (node == null) return const {};
    if (node is! YamlMap) {
      throw EnsembleTestFailure('"profiles.definitions" must be a map');
    }

    final profiles = <String, TestProfile>{};
    for (final entry in node.entries) {
      final id = entry.key.toString().trim();
      if (id.isEmpty) {
        throw EnsembleTestFailure('Profile id must not be empty');
      }
      final value = entry.value;
      if (value is! YamlMap) {
        throw EnsembleTestFailure('Profile "$id" must be a map');
      }
      const allowedKeys = {'mocks', 'initialState'};
      for (final key in value.keys) {
        if (!allowedKeys.contains(key.toString())) {
          throw EnsembleTestFailure(
            'Unsupported profile key "$key" in profile "$id". Supported keys: '
            '${allowedKeys.join(', ')}',
          );
        }
      }
      final mocksNode = value['mocks'];
      if (mocksNode != null &&
          mocksNode is! YamlList &&
          mocksNode is! YamlMap) {
        throw EnsembleTestFailure(
          'Profile "$id" mocks must be either a list of .mock.json files or '
          'an inline map of API mock responses.',
        );
      }
      final initialStateNode = value['initialState'];
      if (initialStateNode != null && initialStateNode is! YamlMap) {
        throw EnsembleTestFailure('Profile "$id" initialState must be a map');
      }

      final parsedMocks = parseMocks(
        mocksNode,
        testId: 'tests/config.yaml profiles.definitions "$id"',
        inputs: const {},
        scenario: const {},
      );
      profiles[id] = TestProfile(
        mockFiles: parsedMocks.files,
        inlineMocks: parsedMocks.inline,
        initialState: ParserValueDecoder.toStringDynamicMap(
          initialStateNode,
          inputs: const {},
        ),
      );
    }
    return profiles;
  }

  static Map<String, List<String>> _parseProfileGroups(dynamic node) {
    if (node == null) return const {};
    if (node is! YamlMap) {
      throw EnsembleTestFailure('"profiles.groups" must be a map');
    }

    final groups = <String, List<String>>{};
    for (final entry in node.entries) {
      final id = entry.key.toString().trim();
      if (id.isEmpty) {
        throw EnsembleTestFailure('Profile group id must not be empty');
      }
      final profiles = ParserValueDecoder.toStringList(entry.value);
      if (profiles.isEmpty) {
        throw EnsembleTestFailure(
          'profiles.groups "$id" must list at least one profile.',
        );
      }
      groups[id] = profiles;
    }
    return groups;
  }

  static void _validateProfileGroups(
    Map<String, List<String>> profileGroups,
    Map<String, TestProfile> profiles,
  ) {
    for (final entry in profileGroups.entries) {
      for (final profile in entry.value) {
        if (!profiles.containsKey(profile)) {
          throw EnsembleTestFailure(
            'profiles.groups "${entry.key}" references unknown profile '
            '"$profile". Define it under profiles.definitions.',
          );
        }
      }
    }
  }

  static WifiTestConfig _parseWifiConfig(
    dynamic node, {
    required String sourceLabel,
  }) {
    if (node == null) return const WifiTestConfig();
    if (node is! YamlMap) {
      throw EnsembleTestFailure('"$sourceLabel" wifi must be a map');
    }
    const allowedKeys = {'ssid', 'verifyFailSsid', 'modeStorageKey'};
    for (final key in node.keys) {
      if (!allowedKeys.contains(key.toString())) {
        throw EnsembleTestFailure(
          'Unsupported wifi key "$key" in $sourceLabel',
        );
      }
    }
    final ssid = node['ssid']?.toString().trim() ?? '';
    final verifyFailSsid =
        node['verifyFailSsid']?.toString().trim() ?? 'Wrong_Network';
    final modeStorageKey = node['modeStorageKey']?.toString().trim();
    if (ssid.isEmpty) {
      throw EnsembleTestFailure(
        '$sourceLabel wifi.ssid is required',
      );
    }
    if (modeStorageKey != null && modeStorageKey.isEmpty) {
      throw EnsembleTestFailure(
        '$sourceLabel wifi.modeStorageKey must not be empty',
      );
    }
    return WifiTestConfig(
      ssid: ssid,
      verifyFailSsid: verifyFailSsid,
      modeStorageKey: modeStorageKey ?? WifiTestConfig.defaultModeStorageKey,
    );
  }

  static int optionalNonNegativeInt(
    dynamic value, {
    required int fallback,
    required String fieldName,
  }) {
    if (value == null) return fallback;
    final parsed = value is int ? value : int.tryParse(value.toString());
    if (parsed == null || parsed < 0) {
      throw EnsembleTestFailure('"$fieldName" must be a non-negative integer');
    }
    return parsed;
  }

  static Map<String, int> _parseScreenTimerCaps(dynamic value) {
    if (value == null) return const {};
    if (value is! YamlMap) {
      throw EnsembleTestFailure(
        '"timers.maxNumberOfTimesByScreen" must be a map',
      );
    }
    return value.map((key, cap) {
      final screen = key.toString().trim();
      if (screen.isEmpty) {
        throw EnsembleTestFailure(
          '"timers.maxNumberOfTimesByScreen" keys must not be empty',
        );
      }
      return MapEntry(
        screen,
        optionalNonNegativeInt(
          cap,
          fallback: 0,
          fieldName: 'timers.maxNumberOfTimesByScreen.$screen',
        ),
      );
    });
  }

  static String? _optionalString(dynamic value) {
    final string = value?.toString().trim();
    return string == null || string.isEmpty ? null : string;
  }
}
