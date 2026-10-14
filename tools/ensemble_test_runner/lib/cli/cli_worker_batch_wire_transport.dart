import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:ensemble_test_runner/discovery/ensemble_test_execution_planner.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/src/core/plan.dart';
import 'package:ensemble_test_runner/src/core/plan_wire_transport.dart';

/// The selected parser metadata and executable plans assigned to one worker.
final class CliWorkerBatch {
  const CliWorkerBatch({
    required this.plan,
    required this.serializedPlans,
  });

  final EnsembleTestExecutionPlan plan;
  final Map<String, String> serializedPlans;
}

/// Transfers selected parsed definitions and compiled plans to a worker.
///
/// The worker consumes this payload instead of decoding the same source files
/// and suite config again. Only process-boundary data lives in this adapter.
final class CliWorkerBatchWireTransport {
  const CliWorkerBatchWireTransport._();

  static const int maxPayloadBytes = 32 * 1024 * 1024;
  static const int maxCompressedPayloadBytes = 8 * 1024 * 1024;

  static String encode({
    required List<EnsembleTestDefinition> definitions,
    required EnsembleTestConfig config,
    required Map<String, ExecutionPlan> plans,
  }) {
    final testIds =
        definitions.map((definition) => definition.testCase.id).toSet();
    for (final entry in plans.entries) {
      if (entry.key != entry.value.id || !testIds.contains(entry.key)) {
        throw FormatException(
          'Worker plan "${entry.key}" has no matching selected definition.',
        );
      }
    }
    final bytes = utf8.encode(jsonEncode({
      'version': 1,
      'config': _encodeConfig(config),
      'definitions': [
        for (final definition in definitions) _encodeDefinition(definition),
      ],
      'plans': {
        for (final entry in plans.entries) entry.key: entry.value.toWire(),
      },
    }));
    if (bytes.length > maxPayloadBytes) {
      throw FormatException('Worker batch exceeds $maxPayloadBytes bytes.');
    }
    final compressed = gzip.encode(bytes);
    if (compressed.length > maxCompressedPayloadBytes) {
      throw FormatException(
        'Compressed worker batch exceeds $maxCompressedPayloadBytes bytes.',
      );
    }
    return base64Url.encode(compressed).replaceAll('=', '');
  }

  static CliWorkerBatch decode(String payload) {
    if (payload.isEmpty ||
        payload.length > (maxCompressedPayloadBytes * 4 ~/ 3) + 4) {
      throw const FormatException('Invalid worker batch payload.');
    }
    final padded = '$payload${'=' * ((4 - payload.length % 4) % 4)}';
    late final List<int> compressed;
    try {
      compressed = base64Url.decode(padded);
    } on FormatException {
      throw const FormatException('Invalid worker batch payload.');
    }
    if (compressed.length > maxCompressedPayloadBytes ||
        compressed.length < 2 ||
        compressed[0] != 0x1f ||
        compressed[1] != 0x8b) {
      throw const FormatException('Worker batch must be compressed.');
    }

    late final List<int> bytes;
    try {
      final bounded = _BoundedBytes(maxPayloadBytes);
      gzip.decoder.startChunkedConversion(bounded)
        ..add(compressed)
        ..close();
      bytes = bounded.takeBytes();
    } on Object catch (error) {
      throw FormatException('Invalid compressed worker batch: $error');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } on Object catch (error) {
      throw FormatException('Invalid worker batch JSON: $error');
    }
    final root = _map(decoded, 'worker batch');
    if (root['version'] != 1) {
      throw FormatException(
          'Unsupported worker batch version "${root['version']}".');
    }
    final config = _decodeConfig(root['config']);
    final definitions = <EnsembleTestDefinition>[];
    final definitionIds = <String>{};
    for (final value in _list(root['definitions'], 'definitions')) {
      final definition = _decodeDefinition(value);
      if (!definitionIds.add(definition.testCase.id)) {
        throw FormatException(
          'Duplicate worker definition "${definition.testCase.id}".',
        );
      }
      definitions.add(definition);
    }

    final encodedPlans = _map(root['plans'], 'plans');
    final plans = <String, String>{};
    for (final entry in encodedPlans.entries) {
      final id = entry.key;
      final plan =
          ExecutionPlan.fromWire(_stringMap(entry.value, 'plan "$id"'));
      if (plan.id != id || !definitionIds.contains(id)) {
        throw FormatException(
          'Worker plan "$id" does not match a selected definition.',
        );
      }
      plans[id] = ExecutionPlanWireTransport.encode(plan);
    }
    return CliWorkerBatch(
      plan: EnsembleTestExecutionPlan(
        ordered: List.unmodifiable(definitions),
        config: config,
      ),
      serializedPlans: Map.unmodifiable(plans),
    );
  }
}

Map<String, Object?> _encodeDefinition(EnsembleTestDefinition definition) => {
      'assetPath': definition.assetPath,
      'testCase': _encodeTestCase(definition.testCase),
    };

EnsembleTestDefinition _decodeDefinition(Object? value) {
  final map = _map(value, 'definition');
  return EnsembleTestDefinition(
    assetPath: _string(map['assetPath'], 'definition assetPath'),
    testCase: _decodeTestCase(map['testCase']),
  );
}

Map<String, Object?> _encodeTestCase(EnsembleTestCase test) => {
      'id': test.id,
      'sourcePath': test.sourcePath,
      'type': test.type,
      'feature': test.feature,
      'tags': test.tags,
      'description': test.description,
      'owner': test.owner,
      'priority': test.priority,
      'parallel': test.parallel,
      'retry': test.retry,
      'startScreen': test.startScreen,
      'startScreenInputs': test.startScreenInputs,
      'session': test.session,
      'profile': test.profile,
      'profiles': test.profiles,
      'scenarioId': test.scenarioId,
      'scenarioDescription': test.scenarioDescription,
      'mockFiles': test.mockFiles,
      'inlineMocks': test.inlineMocks,
      'scenarios': [
        for (final scenario in test.scenarios)
          {
            'id': scenario.id,
            'description': scenario.description,
            'vars': scenario.vars,
          },
      ],
      'initialState': test.initialState,
      'setupSteps': [for (final step in test.setupSteps) _encodeStep(step)],
      'mocks': _encodeMocks(test.mocks),
      'steps': [for (final step in test.steps) _encodeStep(step)],
      'deviceTarget':
          test.deviceTarget == null ? null : _encodeDevice(test.deviceTarget!),
      'screenshotSheetId': test.screenshotSheetId,
    };

EnsembleTestCase _decodeTestCase(Object? value) {
  final map = _map(value, 'testCase');
  final rawDevice = map['deviceTarget'];
  return EnsembleTestCase(
    id: _string(map['id'], 'testCase id'),
    sourcePath: _nullableString(map['sourcePath']),
    type: _nullableString(map['type']),
    feature: _nullableString(map['feature']),
    tags: _strings(map['tags'], 'testCase tags'),
    description: _nullableString(map['description']),
    owner: _nullableString(map['owner']),
    priority: _nullableString(map['priority']),
    parallel: _bool(map['parallel'], 'testCase parallel'),
    retry: _int(map['retry'], 'testCase retry'),
    startScreen: _nullableString(map['startScreen']),
    startScreenInputs:
        _dynamicMap(map['startScreenInputs'], 'startScreenInputs'),
    session: _nullableString(map['session']),
    profile: _nullableString(map['profile']),
    profiles: _strings(map['profiles'], 'testCase profiles'),
    scenarioId: _nullableString(map['scenarioId']),
    scenarioDescription: _nullableString(map['scenarioDescription']),
    mockFiles: _strings(map['mockFiles'], 'testCase mockFiles'),
    inlineMocks: _dynamicMap(map['inlineMocks'], 'testCase inlineMocks'),
    scenarios: [
      for (final item in _list(map['scenarios'], 'testCase scenarios'))
        _decodeScenario(item),
    ],
    initialState: _dynamicMap(map['initialState'], 'testCase initialState'),
    setupSteps: [
      for (final step in _list(map['setupSteps'], 'testCase setupSteps'))
        _decodeStep(step),
    ],
    mocks: _decodeMocks(map['mocks']),
    steps: [
      for (final step in _list(map['steps'], 'testCase steps'))
        _decodeStep(step),
    ],
    deviceTarget: rawDevice == null ? null : _decodeDevice(rawDevice),
    screenshotSheetId: _nullableString(map['screenshotSheetId']),
  );
}

TestScenario _decodeScenario(Object? value) {
  final map = _map(value, 'scenario');
  return TestScenario(
    id: _string(map['id'], 'scenario id'),
    description: _nullableString(map['description']),
    vars: _dynamicMap(map['vars'], 'scenario vars'),
  );
}

Map<String, Object?> _encodeStep(TestStep step) => {
      'type': step.type,
      'args': step.args,
      'mocks': _encodeMocks(step.mocks),
      'nestedSteps': [
        for (final nested in step.nestedSteps) _encodeStep(nested)
      ],
    };

TestStep _decodeStep(Object? value) {
  final map = _map(value, 'step');
  return TestStep(
    type: _string(map['type'], 'step type'),
    args: _dynamicMap(map['args'], 'step args'),
    mocks: _decodeMocks(map['mocks']),
    nestedSteps: [
      for (final nested in _list(map['nestedSteps'], 'step nestedSteps'))
        _decodeStep(nested),
    ],
  );
}

Map<String, Object?> _encodeMocks(TestMocks mocks) => {
      'apis': {
        for (final entry in mocks.apis.entries)
          entry.key: _encodeMockResponse(entry.value),
      },
    };

TestMocks _decodeMocks(Object? value) {
  final map = _map(value, 'mocks');
  final apis = _map(map['apis'], 'mock APIs');
  return TestMocks(
    apis: {
      for (final entry in apis.entries)
        entry.key: _decodeMockResponse(entry.value),
    },
  );
}

Map<String, Object?> _encodeMockResponse(MockAPIResponse response) => {
      'statusCode': response.statusCode,
      'body': response.body,
      'headers': response.headers,
      'delayMs': response.delayMs,
      'responses': [
        for (final item in response.responses) _encodeMockResponse(item),
      ],
    };

MockAPIResponse _decodeMockResponse(Object? value) {
  final map = _map(value, 'mock response');
  final rawHeaders = map['headers'];
  return MockAPIResponse(
    statusCode: _int(map['statusCode'], 'mock response statusCode'),
    body: map['body'],
    headers: rawHeaders == null
        ? null
        : _stringValueMap(rawHeaders, 'mock response headers'),
    delayMs: map['delayMs'] == null ? null : _int(map['delayMs'], 'delayMs'),
    responses: [
      for (final item in _list(map['responses'], 'mock responses'))
        _decodeMockResponse(item),
    ],
  );
}

Map<String, Object?> _encodeDevice(TestDeviceTarget device) => {
      'id': device.id,
      'platform': device.platform,
      'model': device.model,
      'locale': device.locale,
      'theme': device.theme,
    };

TestDeviceTarget _decodeDevice(Object? value) {
  final map = _map(value, 'device target');
  return TestDeviceTarget(
    id: _string(map['id'], 'device id'),
    platform: _string(map['platform'], 'device platform'),
    model: _string(map['model'], 'device model'),
    locale: _nullableString(map['locale']),
    theme: _nullableString(map['theme']),
  );
}

Map<String, Object?> _encodeConfig(EnsembleTestConfig config) => {
      'mode': config.mode.name,
      'services': [
        for (final service in config.services)
          {
            'name': service.name,
            'command': service.command,
            'url': service.url,
            'arguments': service.arguments,
            'workingDirectory': service.workingDirectory,
            'environment': service.environment,
            'readyUrl': service.readyUrl,
            'readyTimeoutMs': service.readyTimeoutMs,
          },
      ],
      'mockFiles': config.mockFiles,
      'inlineMocks': config.inlineMocks,
      'initialState': config.initialState,
      'defaultProfile': config.defaultProfile,
      'profiles': {
        for (final entry in config.profiles.entries)
          entry.key: {
            'mockFiles': entry.value.mockFiles,
            'inlineMocks': entry.value.inlineMocks,
            'initialState': entry.value.initialState,
          },
      },
      'profileGroups': config.profileGroups,
      'devices': [for (final device in config.devices) _encodeDevice(device)],
      'screenshots': {
        'enabled': config.screenshots.enabled,
        'includeSteps': config.screenshots.includeSteps,
        'excludeSteps': config.screenshots.excludeSteps,
      },
      'performance': {'enabled': config.performance.enabled},
      'dumpTree': {'enabled': config.dumpTree.enabled},
      'logApiCalls': {'enabled': config.logApiCalls.enabled},
      'logStorage': {
        'enabled': config.logStorage.enabled,
        'key': config.logStorage.key,
      },
      'timers': {
        'enabled': config.timers.enabled,
        'maxStartAfterSeconds': config.timers.maxStartAfterSeconds,
        'maxRepeatIntervalSeconds': config.timers.maxRepeatIntervalSeconds,
        'maxNumberOfTimes': config.timers.maxNumberOfTimes,
        'maxNumberOfTimesByScreen': config.timers.maxNumberOfTimesByScreen,
      },
      'wifi': {
        'ssid': config.wifi.ssid,
        'verifyFailSsid': config.wifi.verifyFailSsid,
        'modeStorageKey': config.wifi.modeStorageKey,
      },
    };

EnsembleTestConfig _decodeConfig(Object? value) {
  final map = _map(value, 'config');
  final rawProfiles = _map(map['profiles'], 'config profiles');
  final rawGroups = _map(map['profileGroups'], 'config profileGroups');
  final screenshots = _map(map['screenshots'], 'config screenshots');
  final performance = _map(map['performance'], 'config performance');
  final dumpTree = _map(map['dumpTree'], 'config dumpTree');
  final logApiCalls = _map(map['logApiCalls'], 'config logApiCalls');
  final logStorage = _map(map['logStorage'], 'config logStorage');
  final timers = _map(map['timers'], 'config timers');
  final wifi = _map(map['wifi'], 'config wifi');
  return EnsembleTestConfig(
    mode: ExecutionMode.values.byName(_string(map['mode'], 'config mode')),
    services: [
      for (final value in _list(map['services'], 'config services'))
        _decodeService(value),
    ],
    mockFiles: _strings(map['mockFiles'], 'config mockFiles'),
    inlineMocks: _dynamicMap(map['inlineMocks'], 'config inlineMocks'),
    initialState: _dynamicMap(map['initialState'], 'config initialState'),
    defaultProfile: _nullableString(map['defaultProfile']),
    profiles: {
      for (final entry in rawProfiles.entries)
        entry.key: _decodeProfile(entry.value),
    },
    profileGroups: {
      for (final entry in rawGroups.entries)
        entry.key: _strings(entry.value, 'profile group ${entry.key}'),
    },
    devices: [
      for (final device in _list(map['devices'], 'config devices'))
        _decodeDevice(device),
    ],
    screenshots: ScreenshotConfig(
      enabled: _bool(screenshots['enabled'], 'screenshots enabled'),
      includeSteps: _strings(screenshots['includeSteps'], 'includeSteps'),
      excludeSteps: _strings(screenshots['excludeSteps'], 'excludeSteps'),
    ),
    performance: PerformanceConfig(
      enabled: _bool(performance['enabled'], 'performance enabled'),
    ),
    dumpTree: DumpTreeConfig(
      enabled: _bool(dumpTree['enabled'], 'dumpTree enabled'),
    ),
    logApiCalls: LogApiCallsConfig(
      enabled: _bool(logApiCalls['enabled'], 'logApiCalls enabled'),
    ),
    logStorage: LogStorageConfig(
      enabled: _bool(logStorage['enabled'], 'logStorage enabled'),
      key: _nullableString(logStorage['key']),
    ),
    timers: TimerRewriteConfig(
      enabled: _bool(timers['enabled'], 'timers enabled'),
      maxStartAfterSeconds:
          _int(timers['maxStartAfterSeconds'], 'maxStartAfterSeconds'),
      maxRepeatIntervalSeconds:
          _int(timers['maxRepeatIntervalSeconds'], 'maxRepeatIntervalSeconds'),
      maxNumberOfTimes: timers['maxNumberOfTimes'] == null
          ? null
          : _int(timers['maxNumberOfTimes'], 'maxNumberOfTimes'),
      maxNumberOfTimesByScreen: {
        for (final entry
            in _map(timers['maxNumberOfTimesByScreen'], 'timer screen limits')
                .entries)
          entry.key: _int(entry.value, 'timer screen limit ${entry.key}'),
      },
    ),
    wifi: WifiTestConfig(
      ssid: _string(wifi['ssid'], 'wifi ssid'),
      verifyFailSsid: _string(wifi['verifyFailSsid'], 'wifi verifyFailSsid'),
      modeStorageKey: _string(wifi['modeStorageKey'], 'wifi modeStorageKey'),
    ),
  );
}

TestServiceConfig _decodeService(Object? value) {
  final map = _map(value, 'service');
  return TestServiceConfig(
    name: _string(map['name'], 'service name'),
    command: _string(map['command'], 'service command'),
    url: _nullableString(map['url']),
    arguments: _strings(map['arguments'], 'service arguments'),
    workingDirectory: _nullableString(map['workingDirectory']),
    environment: _stringValueMap(map['environment'], 'service environment'),
    readyUrl: _nullableString(map['readyUrl']),
    readyTimeoutMs: _int(map['readyTimeoutMs'], 'service readyTimeoutMs'),
  );
}

TestProfile _decodeProfile(Object? value) {
  final map = _map(value, 'profile');
  return TestProfile(
    mockFiles: _strings(map['mockFiles'], 'profile mockFiles'),
    inlineMocks: _dynamicMap(map['inlineMocks'], 'profile inlineMocks'),
    initialState: _dynamicMap(map['initialState'], 'profile initialState'),
  );
}

Map<String, dynamic> _dynamicMap(Object? value, String field) =>
    _map(value, field).cast<String, dynamic>();

Map<String, String> _stringValueMap(Object? value, String field) => {
      for (final entry in _map(value, field).entries)
        entry.key: _string(entry.value, '$field.${entry.key}'),
    };

Map<String, Object?> _stringMap(Object? value, String field) => {
      for (final entry in _map(value, field).entries) entry.key: entry.value,
    };

Map<String, dynamic> _map(Object? value, String field) {
  if (value is! Map) throw FormatException('Worker $field must be an object.');
  final result = <String, dynamic>{};
  for (final entry in value.entries) {
    if (entry.key is! String) {
      throw FormatException('Worker $field keys must be strings.');
    }
    result[entry.key as String] = entry.value;
  }
  return result;
}

List<Object?> _list(Object? value, String field) {
  if (value is! List) throw FormatException('Worker $field must be a list.');
  return value.cast<Object?>();
}

List<String> _strings(Object? value, String field) => [
      for (final item in _list(value, field)) _string(item, field),
    ];

String _string(Object? value, String field) {
  if (value is! String)
    throw FormatException('Worker $field must be a string.');
  return value;
}

String? _nullableString(Object? value) =>
    value == null ? null : _string(value, 'value');

int _int(Object? value, String field) {
  if (value is! int) throw FormatException('Worker $field must be an integer.');
  return value;
}

bool _bool(Object? value, String field) {
  if (value is! bool) throw FormatException('Worker $field must be a boolean.');
  return value;
}

final class _BoundedBytes with ByteConversionSink {
  _BoundedBytes(this.maxBytes);

  final int maxBytes;
  final BytesBuilder _builder = BytesBuilder(copy: false);
  int _length = 0;

  @override
  void add(List<int> chunk) {
    _length += chunk.length;
    if (_length > maxBytes) {
      throw const FormatException('Worker batch exceeds decoded size limit.');
    }
    _builder.add(chunk);
  }

  @override
  void close() {}

  List<int> takeBytes() => _builder.takeBytes();
}
