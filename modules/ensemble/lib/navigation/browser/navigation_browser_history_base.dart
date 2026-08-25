import 'package:ensemble/navigation/navigation_models.dart';

/// Restores a descriptor snapshot selected by browser Back or Forward.
typedef BrowserHistoryRestore = Future<void> Function(
    List<EnsembleRouteDescriptor> snapshot);

/// Platform abstraction for session-only browser navigation history.
abstract class NavigationBrowserHistory {
  /// Whether a browser popstate callback is currently restoring Navigator.
  bool get isHandlingPopState;

  /// Associates the current browser entry with the initial route snapshot.
  void replaceInitial(List<EnsembleRouteDescriptor> snapshot);

  /// Adds one browser entry for a normal Ensemble route push.
  void recordPush(List<EnsembleRouteDescriptor> snapshot);

  /// Mirrors a normal Ensemble route pop in browser history.
  void recordPop();

  /// Rewrites browser entries to match one committed declarative transaction.
  Future<void> reconcile({
    required int currentDepth,
    required int prefixLength,
    required List<EnsembleRouteDescriptor> finalHistory,
  });
}
