// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

import 'package:ensemble/navigation/browser/navigation_browser_history_base.dart';
import 'package:ensemble/navigation/navigation_models.dart';

/// Creates the session-only Flutter Web history adapter.
NavigationBrowserHistory createNavigationBrowserHistory(
        BrowserHistoryRestore onRestore) =>
    _WebNavigationBrowserHistory(onRestore);

class _WebNavigationBrowserHistory implements NavigationBrowserHistory {
  _WebNavigationBrowserHistory(this.onRestore) {
    html.window.onPopState.listen(_handlePopState);
  }

  static const _stateKey = 'ensembleNavigationToken';

  final BrowserHistoryRestore onRestore;

  // Inputs remain only in memory. Browser state receives an opaque token so
  // neither route inputs nor a public URL format are exposed.
  final Map<String, List<EnsembleRouteDescriptor>> _snapshots = {};
  int _sequence = 0;
  bool _publishing = false;
  bool _handlingPopState = false;
  Completer<void>? _pendingMove;

  @override
  bool get isHandlingPopState => _handlingPopState;

  String _store(List<EnsembleRouteDescriptor> snapshot) {
    final token = 'ensemble_history_${_sequence++}';
    _snapshots[token] = List<EnsembleRouteDescriptor>.unmodifiable(snapshot);
    return token;
  }

  Object _state(String token) => <String, dynamic>{_stateKey: token};

  String get _url => html.window.location.href;

  @override
  void replaceInitial(List<EnsembleRouteDescriptor> snapshot) {
    final token = _store(snapshot);
    html.window.history.replaceState(_state(token), '', _url);
  }

  @override
  void recordPush(List<EnsembleRouteDescriptor> snapshot) {
    if (_publishing) return;
    final token = _store(snapshot);
    html.window.history.pushState(_state(token), '', _url);
  }

  @override
  void recordPop() {
    if (!_publishing) html.window.history.back();
  }

  @override
  Future<void> reconcile({
    required int currentDepth,
    required int prefixLength,
    required List<EnsembleRouteDescriptor> finalHistory,
  }) async {
    if (finalHistory.isEmpty) return;
    _publishing = true;
    try {
      if (prefixLength > 0) {
        // Return to the retained prefix before pushing the rewritten suffix;
        // pushState naturally truncates the obsolete forward branch.
        await _moveBack(currentDepth - prefixLength);
        for (var index = prefixLength; index < finalHistory.length; index++) {
          final token = _store(finalHistory.take(index + 1).toList());
          html.window.history.pushState(_state(token), '', _url);
        }
      } else {
        // With no retained root, reuse the earliest reachable browser entry
        // for the new root and append the rest of the requested history.
        await _moveBack(currentDepth > 0 ? currentDepth - 1 : 0);
        final firstToken =
            _store(<EnsembleRouteDescriptor>[finalHistory.first]);
        html.window.history.replaceState(_state(firstToken), '', _url);
        for (var index = 1; index < finalHistory.length; index++) {
          final token = _store(finalHistory.take(index + 1).toList());
          html.window.history.pushState(_state(token), '', _url);
        }
      }
    } finally {
      _publishing = false;
    }
  }

  Future<void> _moveBack(int count) async {
    if (count <= 0) return;
    _pendingMove = Completer<void>();
    html.window.history.go(-count);
    // Some test hosts and embedded webviews may not emit popstate. Do not let
    // one missing platform event permanently block the transaction queue.
    await _pendingMove!.future.timeout(
      const Duration(seconds: 2),
      onTimeout: () {},
    );
    _pendingMove = null;
  }

  void _handlePopState(html.PopStateEvent event) {
    final pendingMove = _pendingMove;
    if (pendingMove != null && !pendingMove.isCompleted) {
      pendingMove.complete();
      return;
    }
    if (_publishing) return;
    final state = event.state;
    if (state is! Map) return;
    final token = state[_stateKey];
    if (token is! String) return;
    final snapshot = _snapshots[token];
    if (snapshot != null) {
      _handlingPopState = true;
      unawaited(onRestore(snapshot).whenComplete(() {
        _handlingPopState = false;
      }));
    }
  }
}
