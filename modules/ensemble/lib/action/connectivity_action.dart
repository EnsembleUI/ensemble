import 'dart:async';

import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/bindings.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';

/// Global listener for internet connectivity changes.
///
/// Usage in YAML:
/// connectivityListener:
///   onOnline: ...
///   onOffline: ...
///   onChange: ...
class ConnectivityListenerAction extends EnsembleAction {
  ConnectivityListenerAction({
    super.initiator,
    this.onOnline,
    this.onOffline,
    this.onChange,
  });

  final EnsembleAction? onOnline;
  final EnsembleAction? onOffline;
  final EnsembleAction? onChange;

  // Single global subscription for the whole app.
  static StreamSubscription<ConnectivityChangeEvent>? _subscription;

  factory ConnectivityListenerAction.fromYaml(
      {Invokable? initiator, Map? payload}) {
    return ConnectivityListenerAction(
      initiator: initiator,
      onOnline: EnsembleAction.from(payload?['onOnline'], initiator: initiator),
      onOffline:
          EnsembleAction.from(payload?['onOffline'], initiator: initiator),
      onChange: EnsembleAction.from(payload?['onChange'], initiator: initiator),
    );
  }

  @override
  Future execute(BuildContext context, ScopeManager scopeManager) async {
    // Cancel any existing listener so we don't leak or duplicate callbacks.
    await _subscription?.cancel();

    _subscription =
        AppEventBus().eventBus.on<ConnectivityChangeEvent>().listen((event) {
      final bool isOnline = event.isOnline;
      final data = {'isOnline': isOnline};

      // Prefer the global app context, fall back to the last known page
      // context, and finally to the context where the listener was created.
      final BuildContext? activeContext =
          ScreenController().currentScreenContext ??
              Utils.globalAppKey.currentContext ??
              context;

      if (activeContext == null) {
        return;
      }

      // Resolve a fresh ScopeManager for the active context so we don't rely
      // on stale scopes from an old screen. It's fine if this is null; we'll
      // still handle simple navigation-only cases below.
      final ScopeManager? activeScopeManager =
          ScreenController().getScopeManager(activeContext) ?? scopeManager;

      if (onChange != null && activeScopeManager != null) {
        ScreenController().executeActionWithScope(
          activeContext,
          activeScopeManager,
          onChange!,
          event: EnsembleEvent(initiator, data: data),
        );
      }

      // Fire specific events for transitions.
      if (isOnline && onOnline != null && activeScopeManager != null) {
        ScreenController().executeActionWithScope(
          activeContext,
          activeScopeManager,
          onOnline!,
          event: EnsembleEvent(initiator, data: data),
        );
      } else if (!isOnline && onOffline != null && activeScopeManager != null) {
        ScreenController().executeActionWithScope(
          activeContext,
          activeScopeManager,
          onOffline!,
          event: EnsembleEvent(initiator, data: data),
        );
      }
    });

    // Initial check so we handle "app starts while already offline".
    // We don't call into connectivity_plus here; instead we read the last
    // known status maintained by EnsembleApp via ConnectivityState.
    final bool? lastKnownOnline = ConnectivityState().isOnline;
    if (lastKnownOnline == false && onOffline != null) {
      final BuildContext? activeContext =
          ScreenController().currentScreenContext ??
              Utils.globalAppKey.currentContext ??
              context;

      if (activeContext != null) {
        final ScopeManager? activeScopeManager =
            ScreenController().getScopeManager(activeContext) ?? scopeManager;

        if (activeScopeManager != null) {
          final data = {'isOnline': lastKnownOnline};
          if (onChange != null) {
            await ScreenController().executeActionWithScope(
              activeContext,
              activeScopeManager,
              onChange!,
              event: EnsembleEvent(initiator, data: data),
            );
          }
          await ScreenController().executeActionWithScope(
            activeContext,
            activeScopeManager,
            onOffline!,
            event: EnsembleEvent(initiator, data: data),
          );
        }
      }
    }
    // Nothing to return; this action just sets up the listener.
    return Future.value(null);
  }
}
