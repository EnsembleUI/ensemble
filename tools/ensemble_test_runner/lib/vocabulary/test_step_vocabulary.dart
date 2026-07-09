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
  fixture,
  control,
  debug,
  quality,
}

enum TestStepTier {
  core,
  extended,
}

class TestStepDefinition {
  final String name;
  final TestStepCategory category;
  final TestStepTier tier;
  final TestStepArgKind argKind;
  final String description;
  final Map<String, dynamic> example;
  final List<String> aliases;

  const TestStepDefinition({
    required this.name,
    required this.category,
    required this.tier,
    required this.argKind,
    required this.description,
    required this.example,
    this.aliases = const [],
  });
}

/// Canonical step names, aliases, and JSON Schema args.
class TestStepVocabulary {
  TestStepVocabulary._();

  static final Map<String, TestStepDefinition> definitions = {
    for (final e in TestStepRegistry.entries.entries)
      e.key: TestStepDefinition(
        name: e.key,
        category: e.value.category,
        tier: e.value.tier,
        argKind: e.value.argKind,
        description: e.value.description,
        example: e.value.example,
      ),
  };

  static final Map<String, String> _aliasToCanonical = () {
    final map = <String, String>{};
    for (final e in TestStepRegistry.entries.entries) {
      map[e.key] = e.value.executorCanonical ?? e.key;
    }
    return map;
  }();

  /// Maps YAML step keys (including aliases) to canonical handler names.
  static String resolveStepType(String yamlKey) =>
      _aliasToCanonical[yamlKey] ?? yamlKey;

  static TestStepDefinition? lookup(String yamlKey) {
    final entry = TestStepRegistry.entries[yamlKey];
    if (entry != null) {
      return definitions[yamlKey];
    }
    final canonical = resolveStepType(yamlKey);
    return definitions[canonical];
  }

  static Iterable<TestStepDefinition> byTier(TestStepTier tier) =>
      definitions.values.where((d) => d.tier == tier);

  static Iterable<TestStepDefinition> get coreSteps =>
      byTier(TestStepTier.core);

  /// Every YAML key that may appear as a single-key step map.
  static Iterable<String> get yamlStepKeys => TestStepRegistry.entries.keys;

  /// JSON Schema object for a step's YAML argument map (by YAML key).
  static Map<String, dynamic> argJsonSchemaForYamlKey(String yamlKey) {
    final entry = TestStepRegistry.entries[yamlKey];
    if (entry != null) {
      return entry.argKind.jsonSchema;
    }
    final canonical = resolveStepType(yamlKey);
    return definitions[canonical]?.argKind.jsonSchema ??
        TestStepArgKind.empty.jsonSchema;
  }

  /// JSON Schema for a canonical executor step name.
  static Map<String, dynamic> argJsonSchemaFor(String canonicalStep) =>
      definitions[canonicalStep]?.argKind.jsonSchema ??
      TestStepArgKind.empty.jsonSchema;
}
