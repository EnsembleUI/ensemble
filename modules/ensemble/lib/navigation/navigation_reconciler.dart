import 'package:ensemble/navigation/navigation_models.dart';

/// Immutable result of comparing live and requested histories.
class NavigationReconciliation {
  const NavigationReconciliation({
    required this.prefixLength,
    required this.retained,
    required this.obsolete,
    required this.missing,
  });

  /// Number of compatible routes at the start of both histories.
  final int prefixLength;

  /// Existing routes whose widgets and state can be preserved.
  final List<ManagedEnsembleRoute> retained;

  /// Existing suffix that must be removed after destination navigation.
  final List<ManagedEnsembleRoute> obsolete;

  /// Requested suffix inserted as lazy historical routes.
  final List<EnsembleRouteDescriptor> missing;
}

/// Calculates the longest reusable prefix without mutating Navigator state.
class NavigationReconciler {
  const NavigationReconciler();

  /// Reconciles in order and never reuses a matching route after a mismatch.
  NavigationReconciliation reconcile(
    List<ManagedEnsembleRoute> current,
    List<EnsembleRouteDescriptor> desired,
  ) {
    var prefixLength = 0;
    final limit =
        current.length < desired.length ? current.length : desired.length;
    while (prefixLength < limit &&
        current[prefixLength]
            .descriptor
            .satisfiesHistoryRequest(desired[prefixLength])) {
      prefixLength++;
    }
    return NavigationReconciliation(
      prefixLength: prefixLength,
      retained: List.unmodifiable(current.take(prefixLength)),
      obsolete: List.unmodifiable(current.skip(prefixLength)),
      missing: List.unmodifiable(desired.skip(prefixLength)),
    );
  }
}
