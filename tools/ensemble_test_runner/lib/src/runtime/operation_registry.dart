import 'package:ensemble_test_runner/src/core/operation.dart';
import 'package:ensemble_test_runner/src/core/operation_registry.dart';
import 'package:ensemble_test_runner/vocabulary/test_step_vocabulary.dart';

/// Builds the core registry from generated step metadata.
/// Execution adapters consume the handler keys from this registry directly.
final OperationRegistry operationRegistry = _buildRegistry();

OperationRegistry _buildRegistry() {
  final aliases = <String, List<String>>{};
  final waitKinds = <String, Set<String>>{};
  final orderedEvidenceNames = <String>{};
  for (final entry in TestStepRegistry.entries.entries) {
    if (entry.value.category == TestStepCategory.control) continue;
    final canonical = TestStepVocabulary.resolveStepType(entry.key);
    final waitKind = entry.value.waitKind;
    if (entry.value.orderedEvidence) {
      orderedEvidenceNames.add(entry.key);
    }
    if (waitKind != null) {
      waitKinds.putIfAbsent(canonical, () => <String>{}).add(waitKind);
    }
    if (canonical != entry.key) {
      aliases.putIfAbsent(canonical, () => []).add(entry.key);
    }
  }

  return OperationRegistry([
    for (final entry in TestStepRegistry.entries.entries)
      if (entry.value.category != TestStepCategory.control &&
          TestStepVocabulary.resolveStepType(entry.key) == entry.key)
        OperationDescriptor(
          name: entry.key,
          kind: _kindFor(entry.value.executionKind),
          handlerKey: entry.value.handlerKey,
          argumentSchema: entry.value.argumentSchema,
          restrictedUiAllowed: entry.value.restrictedUiAllowed,
          userAction: entry.value.userAction,
          orderedEvidence: orderedEvidenceNames.contains(entry.key),
          orderedEvidenceAliases: aliases[entry.key]?.where(
                (alias) => orderedEvidenceNames.contains(alias),
              ) ??
              const [],
          acceptsTimeout: entry.value.acceptsTimeout,
          notifiesConditionMatched: entry.value.notifiesConditionMatched,
          requiredCapabilities: entry.value.requiredCapabilities,
          waitKind: entry.value.waitKind,
          waitTargetState: entry.value.waitTargetState,
          supportedWaitKinds: waitKinds[entry.key],
          aliases: aliases[entry.key] ?? const [],
        ),
  ], controls: [
    for (final entry in TestStepRegistry.entries.entries)
      if (entry.value.controlKind case final kind?)
        ControlDescriptor(name: entry.key, kind: _controlKind(kind)),
  ]);
}

ControlKind _controlKind(TestStepControlKind kind) => switch (kind) {
      TestStepControlKind.group => ControlKind.group,
      TestStepControlKind.repeat => ControlKind.repeat,
      TestStepControlKind.optional => ControlKind.optional,
      TestStepControlKind.ifVisible => ControlKind.ifVisible,
    };

OperationKind _kindFor(TestStepExecutionKind kind) {
  if (kind == TestStepExecutionKind.control) {
    throw StateError('Control descriptors are not operations.');
  }
  // The generated execution metadata intentionally mirrors the core operation
  // kinds. This keeps the registry as the only route classification source.
  try {
    return OperationKind.values.byName(kind.name);
  } on ArgumentError {
    throw StateError('Unknown execution kind "${kind.name}".');
  }
}
