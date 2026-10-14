import 'operation_registry.dart';

enum StepEvidenceBoundary {
  none,
  orderedOperation,
  condition,
  textMatch,
  navigation,
}

/// Classification policy for ordered step evidence events.
///
/// This is deliberately independent from event delivery and capture sinks. It
/// lets standalone and hosted callback binders share one vocabulary without
/// coupling their evidence timing to the subscriber implementation.
final class StepEvidencePolicy {
  const StepEvidencePolicy._();

  static final Set<String> orderedSteps = Set.unmodifiable({
    for (final descriptor in operationRegistry.descriptors)
      if (descriptor.orderedEvidence) descriptor.name,
    for (final descriptor in operationRegistry.descriptors)
      ...descriptor.orderedEvidenceAliases,
  });

  static const conditionBoundaryPrefix = 'condition:';

  /// Classifies a kernel boundary once so adapters share the same evidence
  /// semantics while retaining their distinct frame-capture timing.
  static StepEvidenceBoundary classify(String? detail) {
    if (detail == null) return StepEvidenceBoundary.none;
    if (detail == 'waitForNavigation') return StepEvidenceBoundary.navigation;
    if (detail == 'waitForText') return StepEvidenceBoundary.textMatch;
    if (detail.startsWith(conditionBoundaryPrefix)) {
      final stepType = detail.substring(conditionBoundaryPrefix.length);
      return isConditionStep(stepType)
          ? StepEvidenceBoundary.condition
          : StepEvidenceBoundary.none;
    }
    return orderedSteps.contains(detail)
        ? StepEvidenceBoundary.orderedOperation
        : StepEvidenceBoundary.none;
  }

  static bool acceptsBoundary(String detail) =>
      classify(detail) != StepEvidenceBoundary.none;

  static bool ownsOrderedCapture(String stepType) =>
      orderedSteps.contains(stepType) || isConditionStep(stepType);

  static bool isConditionStep(String stepType) {
    if (stepType == 'waitForText' || stepType == 'waitForNavigation') {
      return false;
    }
    if (const {'wait', 'pump', 'settle', 'scrollUntilVisible'}
        .contains(stepType)) {
      return true;
    }
    return stepType.startsWith('expect') ||
        (stepType.startsWith('waitFor') &&
            operationRegistry.lookup(stepType) != null);
  }
}
