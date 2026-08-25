import 'package:ensemble/navigation/browser/navigation_browser_history_base.dart';
import 'package:ensemble/navigation/navigation_models.dart';

/// Creates the native no-op implementation; Navigator owns native Back state.
NavigationBrowserHistory createNavigationBrowserHistory(
        BrowserHistoryRestore onRestore) =>
    _NoopNavigationBrowserHistory();

class _NoopNavigationBrowserHistory implements NavigationBrowserHistory {
  @override
  bool get isHandlingPopState => false;

  @override
  void recordPop() {}

  @override
  void recordPush(List<EnsembleRouteDescriptor> snapshot) {}

  @override
  Future<void> reconcile({
    required int currentDepth,
    required int prefixLength,
    required List<EnsembleRouteDescriptor> finalHistory,
  }) async {}

  @override
  void replaceInitial(List<EnsembleRouteDescriptor> snapshot) {}
}
