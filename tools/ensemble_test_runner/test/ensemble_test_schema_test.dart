import 'dart:convert';

import 'package:ensemble_test_runner/schema/ensemble_test_schema_builder.dart';
import 'package:ensemble_test_runner/vocabulary/test_step_registry.dart';
import 'package:ensemble_test_runner/vocabulary/test_step_vocabulary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('schema includes all vocabulary steps', () {
    final schema = EnsembleTestSchemaBuilder.build();
    final stepDef = schema['\$defs']['step'] as Map<String, dynamic>;
    final oneOf = stepDef['oneOf'] as List<dynamic>;

    final yamlKeys = oneOf.map((e) {
      final props = (e as Map)['properties'] as Map;
      return props.keys.first as String;
    }).toSet();

    for (final name in TestStepRegistry.entries.keys.where(
      (name) => name != 'runCommand',
    )) {
      expect(yamlKeys, contains(name), reason: 'missing step $name in schema');
    }
    expect(yamlKeys, isNot(contains('runCommand')));

    final setupDef = schema['\$defs']['setupStep'] as Map<String, dynamic>;
    final setupKeys = (setupDef['oneOf'] as List<dynamic>).map((variant) {
      final properties = (variant as Map)['properties'] as Map;
      return properties.keys.first as String;
    });
    expect(setupKeys, contains('runCommand'));

    for (final variant in oneOf) {
      final map = variant as Map<String, dynamic>;
      expect(map['description'], isNotEmpty);
      expect(map['examples'], isNotEmpty);
      final yamlKey = (map['properties'] as Map).keys.first as String;
      final entry = TestStepRegistry.entries[yamlKey]!;
      final argsDefName = 'args_$yamlKey';
      final argsDef = schema['\$defs'][argsDefName] as Map<String, dynamic>;
      expect(argsDef['description'], map['description']);
      expect(argsDef['examples'], [entry.example]);
      expect(map['examples'], [
        {yamlKey: entry.example},
      ]);
    }
  });

  test(
      'generated JSON is valid and requires id, steps with XOR start/prerequisite',
      () {
    final json = EnsembleTestSchemaBuilder.buildJson();
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    expect(decoded['\$schema'], EnsembleTestSchemaBuilder.schemaVersion);
    expect(decoded['required'], containsAll(<String>['id', 'steps']));
    expect((decoded['required'] as List), isNot(contains('startScreen')));
    expect(decoded['properties'], contains('id'));
    expect(decoded['properties'], isNot(contains('tests')));
    expect(decoded['properties'], isNot(contains('options')));
    expect(decoded['properties'], contains('mocks'));
    expect(decoded['properties'], contains('retry'));
    expect(decoded['properties'], contains('startScreen'));
    expect(decoded['properties'], contains('prerequisite'));
    expect(decoded['properties'], isNot(contains('mockLayers')));
    expect(decoded['properties'], contains('scenarios'));
    expect(decoded['oneOf'], isA<List>());
  });

  test('schema keeps mocks at the root only', () {
    final schema = EnsembleTestSchemaBuilder.build();
    final defs = schema['\$defs'] as Map<String, dynamic>;
    final scenario = defs['scenario'] as Map<String, dynamic>;
    final scenarioProperties = scenario['properties'] as Map<String, dynamic>;

    expect(scenarioProperties, contains('vars'));
    expect(scenarioProperties, isNot(contains('mocks')));
  });

  test('config schema includes suite screenshots and performance settings', () {
    final json = EnsembleTestSchemaBuilder.buildConfigJson();
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    final properties = decoded['properties'] as Map<String, dynamic>;

    expect(decoded['\$schema'], EnsembleTestSchemaBuilder.schemaVersion);
    expect(properties, contains('screenshots'));
    expect(properties, contains('services'));
    expect(properties, isNot(contains('record')));
    expect(properties, contains('performance'));
    expect(properties, contains('timers'));
    expect(properties, contains('dumpTree'));
    expect(properties, contains('logApiCalls'));
    expect(properties, contains('logStorage'));
    expect(
      (properties['screenshots'] as Map<String, dynamic>)['properties'],
      containsPair('model', {'type': 'string'}),
    );
    final serviceItems = (properties['services']
        as Map<String, dynamic>)['items'] as Map<String, dynamic>;
    expect(serviceItems['properties'], contains('url'));
  });

  test('initialState schema accepts storage, keychain, and env maps', () {
    final schema = EnsembleTestSchemaBuilder.build();
    final initialState =
        schema['\$defs']['initialState'] as Map<String, dynamic>;
    final properties = initialState['properties'] as Map<String, dynamic>;

    expect(properties, contains('storage'));
    expect(properties, contains('keychain'));
    expect(properties, contains('env'));
    expect(properties['keychain'], {
      'type': 'object',
      'additionalProperties': true,
    });
  });
}
