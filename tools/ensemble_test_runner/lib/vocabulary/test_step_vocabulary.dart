import 'package:ensemble_test_runner/vocabulary/test_step_arg_kind.dart';
import 'package:ensemble_test_runner/vocabulary/test_step_registry.dart';

/// Official Ensemble declarative test step vocabulary.
///
/// Single source of truth for step metadata and JSON Schema args:
/// [TestStepRegistry.entries]. Executor aliases are declared via
/// [TestStepRegistryEntry.executorCanonical].
export 'test_step_arg_kind.dart';
export 'test_step_registry.dart';

enum TestStepCategory {
  lifecycle,
  interaction,
  formControl,
  gesture,
  wait,
  uiAssertion,
  valueAssertion,
  listAssertion,
  navigation,
  apiMock,
  apiAssertion,
  storage,
  runtime,
  script,
  network,
  control,
  debug,
  quality,
}

enum TestStepTier {
  core,
  extended,
}

/// Execution route class generated for every declarative test step.
enum TestStepExecutionKind {
  interaction,
  wait,
  assertion,
  lifecycle,
  environment,
  diagnostic,
  control,
}

/// The specific plan node represented by a control-flow step.
enum TestStepControlKind { group, repeat, optional, ifVisible }

class TestStepDefinition {
  TestStepDefinition({
    required this.name,
    required this.category,
    required this.executionKind,
    required this.tier,
    required this.argKind,
    required Map<String, dynamic> argumentSchema,
    required this.description,
    required Map<String, dynamic> example,
    List<String> aliases = const [],
  })  : argumentSchema = _freezeMetadata(argumentSchema),
        example = _freezeMetadata(example),
        aliases = List.unmodifiable(aliases);

  final String name;
  final TestStepCategory category;
  final TestStepExecutionKind executionKind;
  final TestStepTier tier;
  final TestStepArgKind argKind;
  final Map<String, dynamic> argumentSchema;
  final String description;
  final Map<String, dynamic> example;
  final List<String> aliases;
}

Map<String, dynamic> _freezeMetadata(Map<String, dynamic> value) =>
    Map.unmodifiable({
      for (final entry in value.entries)
        entry.key: _freezeMetadataValue(entry.value),
    });

Object? _freezeMetadataValue(Object? value) => switch (value) {
      Map<String, dynamic>() => _freezeMetadata(value),
      Map() => _freezeDynamicMap(value),
      List() => List.unmodifiable(value.map(_freezeMetadataValue)),
      _ => value,
    };

Map<String, Object?> _freezeDynamicMap(Map value) {
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) {
      throw ArgumentError.value(
        entry.key,
        'metadata key',
        'Vocabulary metadata maps must use string keys.',
      );
    }
    result[entry.key as String] = _freezeMetadataValue(entry.value);
  }
  return Map.unmodifiable(result);
}

/// Canonical step names, aliases, and JSON Schema args.
class TestStepVocabulary {
  TestStepVocabulary._();

  static final Map<String, TestStepDefinition> definitions = Map.unmodifiable({
    for (final e in TestStepRegistry.entries.entries)
      e.key: TestStepDefinition(
        name: e.key,
        category: e.value.category,
        executionKind: e.value.executionKind,
        tier: e.value.tier,
        argKind: e.value.argKind,
        argumentSchema: e.value.argumentSchema,
        description: e.value.description,
        example: e.value.example,
      ),
  });

  static final Map<String, String> _aliasToCanonical = () {
    final map = <String, String>{};
    for (final e in TestStepRegistry.entries.entries) {
      map[e.key] = e.value.executorCanonical ?? e.key;
    }
    return map;
  }();

  /// Maps step keys (including aliases) to canonical handler names.
  static String resolveStepType(String stepKey) =>
      _aliasToCanonical[stepKey] ?? stepKey;

  static TestStepDefinition? lookup(String stepKey) {
    final entry = TestStepRegistry.entries[stepKey];
    if (entry != null) {
      return definitions[stepKey];
    }
    final canonical = resolveStepType(stepKey);
    return definitions[canonical];
  }

  static Iterable<TestStepDefinition> byTier(TestStepTier tier) =>
      definitions.values.where((d) => d.tier == tier);

  static Iterable<TestStepDefinition> get coreSteps =>
      byTier(TestStepTier.core);

  /// Every step key that may appear as a single-key step map.
  static Iterable<String> get stepKeys => TestStepRegistry.entries.keys;

  /// JSON Schema object for a step's argument map (by step key).
  static Map<String, dynamic> argJsonSchemaForKey(String stepKey) {
    final entry = TestStepRegistry.entries[stepKey];
    if (entry != null) {
      return entry.argumentSchema;
    }
    final canonical = resolveStepType(stepKey);
    return definitions[canonical]?.argumentSchema ??
        TestStepArgKind.empty.jsonSchema;
  }

  /// JSON Schema for a canonical executor step name.
  static Map<String, dynamic> argJsonSchemaFor(String canonicalStep) =>
      definitions[canonicalStep]?.argumentSchema ??
      TestStepArgKind.empty.jsonSchema;
}
