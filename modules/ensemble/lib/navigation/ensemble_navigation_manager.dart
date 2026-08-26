import 'dart:async';
import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:ensemble/layout/ensemble_page_route.dart';
import 'package:ensemble/navigation/browser/navigation_browser_history.dart';
import 'package:ensemble/navigation/navigation_models.dart';
import 'package:ensemble/navigation/navigation_reconciler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Constructs either a lazy history route or the animated destination route.
typedef EnsembleRouteCreator = PageRouteBuilder<dynamic> Function(
  EnsembleRouteDescriptor descriptor, {
  required bool animate,
});

/// Owns the canonical Ensemble route history and custom-stack transactions.
class EnsembleNavigationManager {
  EnsembleNavigationManager._();

  /// Shared manager for the canonical Ensemble navigator.
  static final EnsembleNavigationManager instance =
      EnsembleNavigationManager._();

  final List<ManagedEnsembleRoute> _history = [];
  final Expando<EnsembleRouteExitReason> _exitReasons =
      Expando<EnsembleRouteExitReason>('ensembleRouteExitReason');
  final NavigationReconciler _reconciler = const NavigationReconciler();
  final Map<List<Object?>, Future<PageRouteBuilder<dynamic>>>
      _pendingTransactions =
      HashMap<List<Object?>, Future<PageRouteBuilder<dynamic>>>(
    equals: const DeepCollectionEquality().equals,
    hashCode: const DeepCollectionEquality().hash,
  );
  Future<void> _transactionTail = Future<void>.value();
  int _transactionSequence = 0;
  bool _isCommitting = false;
  bool _browserHasInitialEntry = false;
  bool _browserRestoring = false;
  NavigatorState? _lastNavigator;
  EnsembleRouteCreator? _lastRouteCreator;

  NavigationBrowserHistory? _browserHistoryInstance;

  NavigationBrowserHistory get _browserHistory => _browserHistoryInstance ??=
      createNavigationBrowserHistory(_restoreFromBrowser);

  /// Observer that keeps [_history] synchronized with Navigator 1.0 events.
  late final NavigatorObserver observer = _EnsembleNavigationObserver(this);

  /// Snapshot of the currently managed Ensemble routes, from root to top.
  List<ManagedEnsembleRoute> get history => List.unmodifiable(_history);

  /// Returns the semantic exit reason used by `onNavigateBack` filtering.
  EnsembleRouteExitReason exitReasonFor(Route<dynamic> route) =>
      _exitReasons[route] ?? EnsembleRouteExitReason.back;

  /// Queues a declarative history rewrite and returns its destination route.
  ///
  /// The returned future completes once the destination has been accepted by
  /// Navigator. Internal cleanup remains serialized so rapid
  /// requests cannot observe or modify a partially reconciled stack.
  Future<PageRouteBuilder<dynamic>> navigateWithHistory({
    required NavigatorState navigator,
    required List<EnsembleRouteDescriptor> history,
    required EnsembleRouteDescriptor destination,
    required EnsembleRouteCreator createRoute,
  }) {
    _lastNavigator = navigator;
    _lastRouteCreator = createRoute;
    final key = _transactionKey(history, destination);
    final pending = _pendingTransactions[key];
    // Coalesce rapid identical taps while their transaction is still queued or
    // completing its visual cleanup.
    if (pending != null) return pending;

    final completer = Completer<PageRouteBuilder<dynamic>>();
    final transaction = completer.future;
    _pendingTransactions[key] = transaction;
    _transactionTail =
        _transactionTail.catchError((Object _) {}).then((_) async {
      try {
        final commit = _startCommit(
          navigator: navigator,
          desiredHistory: history,
          destination: destination,
          createRoute: createRoute,
        );
        completer.complete(commit.destinationRoute);
        await commit.completion;
      } catch (error, stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      } finally {
        _pendingTransactions.remove(key);
      }
    });
    return transaction;
  }

  _StartedNavigationCommit _startCommit({
    required NavigatorState navigator,
    required List<EnsembleRouteDescriptor> desiredHistory,
    required EnsembleRouteDescriptor destination,
    required EnsembleRouteCreator createRoute,
  }) {
    final transactionId = 'nav_${_transactionSequence++}';
    final current = List<ManagedEnsembleRoute>.of(_history);
    final reconciliation = _reconciler.reconcile(current, desiredHistory);
    // A wildcard-retained route keeps its actual inputs. Browser snapshots must
    // therefore use retained descriptors rather than the input-less request.
    final resolvedHistory = <EnsembleRouteDescriptor>[
      ...reconciliation.retained.map((route) => route.descriptor),
      ...reconciliation.missing,
    ];
    final newHistoricalRoutes = reconciliation.missing
        .map((descriptor) => createRoute(descriptor, animate: false))
        .toList(growable: false);
    final destinationRoute = createRoute(destination, animate: true);
    final pushed = <Route<dynamic>>[];

    _debugTransaction(
      transactionId,
      current,
      desiredHistory,
      destination,
      reconciliation,
    );

    _isCommitting = true;
    try {
      // All pushes occur in one synchronous block before obsolete routes are
      // touched, allowing a synchronous failure to roll back safely.
      for (final route in newHistoricalRoutes) {
        navigator.push(route);
        pushed.add(route);
      }
      navigator.push(destinationRoute);
      pushed.add(destinationRoute);
    } catch (_) {
      for (final route in pushed.reversed) {
        _exitReasons[route] = EnsembleRouteExitReason.historyReconciled;
        if (route.isActive) navigator.removeRoute(route);
      }
      rethrow;
    } finally {
      _isCommitting = false;
    }

    final browserUpdate = _browserRestoring
        ? Future<void>.value()
        : _browserHistory.reconcile(
            currentDepth: current.length,
            prefixLength: reconciliation.prefixLength,
            finalHistory: <EnsembleRouteDescriptor>[
              ...resolvedHistory,
              destination,
            ],
          );

    final completion = () async {
      // Keep the old visible route alive under the destination transition.
      // Removing it immediately would expose a dormant transparent history
      // entry and briefly show the Navigator background.
      await _waitForForwardTransition(destinationRoute);
      for (final managed in reconciliation.obsolete.reversed) {
        if (!managed.route.isActive) continue;
        _exitReasons[managed.route] = EnsembleRouteExitReason.historyReconciled;
        navigator.removeRoute(managed.route);
      }
      await browserUpdate;
    }();

    return _StartedNavigationCommit(destinationRoute, completion);
  }

  Future<void> _waitForForwardTransition(
      PageRouteBuilder<dynamic> route) async {
    if (route.transitionDuration == Duration.zero) return;

    // Navigator.push can briefly expose the controller's pre-animation status
    // before the first frame. Keep the outgoing route through that frame so a
    // dormant historical route can never become the transition background.
    await SchedulerBinding.instance.endOfFrame;

    final animation = route.animation;
    if (animation == null || animation.status == AnimationStatus.completed) {
      return;
    }

    final transitionCompleted = Completer<void>();
    var transitionStarted = animation.status != AnimationStatus.dismissed;
    void listener(AnimationStatus status) {
      if (status == AnimationStatus.forward ||
          status == AnimationStatus.reverse) {
        transitionStarted = true;
        return;
      }
      if (status != AnimationStatus.completed &&
          !(status == AnimationStatus.dismissed && transitionStarted)) {
        return;
      }
      animation.removeStatusListener(listener);
      if (!transitionCompleted.isCompleted) transitionCompleted.complete();
    }

    animation.addStatusListener(listener);
    try {
      // A legacy navigation can remove this route while it is animating. In
      // that case Flutter disposes the animation and clears its listeners, but
      // still completes Route.popped. Racing both lifecycle signals prevents
      // a removed destination from permanently blocking the FIFO queue.
      await Future.any<void>(<Future<void>>[
        transitionCompleted.future,
        route.popped.then<void>((_) {}),
      ]);
    } finally {
      animation.removeStatusListener(listener);
    }
  }

  Future<void> _restoreFromBrowser(
      List<EnsembleRouteDescriptor> snapshot) async {
    // Defer out of the browser event callback before mutating Navigator.
    await Future<void>.delayed(Duration.zero);
    if (snapshot.isEmpty || _historyMatches(snapshot)) return;
    final navigator = _lastNavigator;
    final createRoute = _lastRouteCreator;
    if (navigator == null || createRoute == null || !navigator.mounted) return;

    _browserRestoring = true;
    try {
      if (_isHistoryPrefix(snapshot)) {
        // Browser Back to a strict prefix maps directly to normal route pops.
        while (_history.length > snapshot.length && navigator.canPop()) {
          navigator.pop();
        }
        return;
      }
      await navigateWithHistory(
        // Browser Forward or a changed branch uses the same reconciler as an
        // application-triggered navigation, without publishing new entries.
        navigator: navigator,
        history: snapshot.sublist(0, snapshot.length - 1),
        destination: snapshot.last,
        createRoute: createRoute,
      );
    } finally {
      _browserRestoring = false;
    }
  }

  bool _isHistoryPrefix(List<EnsembleRouteDescriptor> snapshot) {
    if (snapshot.length >= _history.length) return false;
    for (var index = 0; index < snapshot.length; index++) {
      if (!_history[index].descriptor.isEquivalentTo(snapshot[index])) {
        return false;
      }
    }
    return true;
  }

  bool _historyMatches(List<EnsembleRouteDescriptor> snapshot) {
    if (_history.length != snapshot.length) return false;
    for (var index = 0; index < snapshot.length; index++) {
      if (!_history[index].descriptor.isEquivalentTo(snapshot[index])) {
        return false;
      }
    }
    return true;
  }

  List<Object?> _transactionKey(
    List<EnsembleRouteDescriptor> history,
    EnsembleRouteDescriptor destination,
  ) {
    List<Object?> descriptorKey(EnsembleRouteDescriptor descriptor) =>
        <Object?>[
          descriptor.screenId,
          descriptor.screenName,
          descriptor.isExternal,
          descriptor.pageType,
          descriptor.inputs,
        ];
    return <Object?>[
      for (final descriptor in <EnsembleRouteDescriptor>[
        ...history,
        destination,
      ])
        descriptorKey(descriptor),
    ];
  }

  void _didPush(Route<dynamic> route) {
    final settings = route.settings;
    if (settings is! EnsembleRouteSettings) return;
    _history.add(
      ManagedEnsembleRoute(route: route, descriptor: settings.descriptor),
    );
    if (!_isCommitting && !_browserRestoring) {
      // A declarative transaction publishes one final snapshot itself; only
      // standalone Navigator pushes are mirrored here.
      final snapshot = _history.map((entry) => entry.descriptor).toList();
      if (_browserHasInitialEntry) {
        _browserHistory.recordPush(snapshot);
      } else {
        _browserHistory.replaceInitial(snapshot);
        _browserHasInitialEntry = true;
      }
    }
  }

  void _didPop(Route<dynamic> route) {
    _exitReasons[route] ??= EnsembleRouteExitReason.back;
    _history.removeWhere((managed) => identical(managed.route, route));
    if (!_isCommitting &&
        !_browserRestoring &&
        !_browserHistory.isHandlingPopState) {
      _browserHistory.recordPop();
    }
  }

  void _didRemove(Route<dynamic> route) {
    _history.removeWhere((managed) => identical(managed.route, route));
  }

  void _didReplace(Route<dynamic>? newRoute, Route<dynamic>? oldRoute) {
    final index = oldRoute == null
        ? -1
        : _history.indexWhere((entry) => identical(entry.route, oldRoute));
    if (oldRoute != null) {
      _exitReasons[oldRoute] = EnsembleRouteExitReason.replaced;
    }
    if (index < 0) {
      if (newRoute != null) _didPush(newRoute);
      return;
    }
    if (newRoute?.settings is EnsembleRouteSettings) {
      final settings = newRoute!.settings as EnsembleRouteSettings;
      _history[index] = ManagedEnsembleRoute(
        route: newRoute,
        descriptor: settings.descriptor,
      );
    } else {
      _history.removeAt(index);
    }
  }

  void markExitReason(
      Route<dynamic> route, EnsembleRouteExitReason exitReason) {
    _exitReasons[route] = exitReason;
  }

  void markCurrentRoute(EnsembleRouteExitReason exitReason) {
    if (_history.isEmpty) return;
    markExitReason(_history.last.route, exitReason);
  }

  void markAllRoutes(EnsembleRouteExitReason exitReason) {
    for (final managed in List<ManagedEnsembleRoute>.of(_history)) {
      markExitReason(managed.route, exitReason);
    }
  }

  void _debugTransaction(
    String id,
    List<ManagedEnsembleRoute> current,
    List<EnsembleRouteDescriptor> desired,
    EnsembleRouteDescriptor destination,
    NavigationReconciliation reconciliation,
  ) {
    if (!kDebugMode) return;
    debugPrint('[Navigation] Transaction: $id');
    debugPrint(
        'Current: ${current.map((r) => r.descriptor.identifier).join(' -> ')}');
    debugPrint('Requested: ${[
      ...desired,
      destination
    ].map((r) => r.identifier).join(' -> ')}');
    debugPrint(
        'KEEP: ${reconciliation.retained.map((r) => r.descriptor.identifier).join(', ')}');
    debugPrint(
        'DROP: ${reconciliation.obsolete.map((r) => r.descriptor.identifier).join(', ')}');
    debugPrint(
        'INSERT: ${reconciliation.missing.map((r) => r.identifier).join(', ')}');
    debugPrint('PUSH: ${destination.identifier}');
  }

  /// Clears singleton state between widget tests.
  @visibleForTesting
  void reset() {
    _history.clear();
    _pendingTransactions.clear();
    _transactionTail = Future<void>.value();
    _isCommitting = false;
    _browserHasInitialEntry = false;
    _browserRestoring = false;
    _lastNavigator = null;
    _lastRouteCreator = null;
  }

  /// Replaces the platform adapter with a deterministic test implementation.
  @visibleForTesting
  void setBrowserHistoryForTesting(NavigationBrowserHistory browserHistory) {
    _browserHistoryInstance = browserHistory;
    _browserHasInitialEntry = false;
  }
}

class _EnsembleNavigationObserver extends NavigatorObserver {
  _EnsembleNavigationObserver(this.manager);

  final EnsembleNavigationManager manager;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    manager._didPush(route);
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    manager._didPop(route);
    super.didPop(route, previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    manager._didRemove(route);
    super.didRemove(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    manager._didReplace(newRoute, oldRoute);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didStartUserGesture(
      Route<dynamic> route, Route<dynamic>? previousRoute) {
    // Interactive iOS back gestures expose the previous route before didPopNext
    // is delivered. Materialize it under the still-visible current route.
    if (previousRoute is LazyEnsemblePageRouteBuilder<dynamic>) {
      previousRoute.materialize();
    }
    super.didStartUserGesture(route, previousRoute);
  }
}

class _StartedNavigationCommit {
  const _StartedNavigationCommit(this.destinationRoute, this.completion);

  /// Route returned to the action as soon as Navigator accepts the push.
  final PageRouteBuilder<dynamic> destinationRoute;

  /// Deferred transition cleanup that keeps subsequent transactions FIFO.
  final Future<void> completion;
}
