import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ControlBackNavigation extends EnsembleAction {
  ControlBackNavigation({
    super.initiator,
    this.disable = false,
    this.onComplete,
    this.onFailure,
  });

  static WillPopCallback? _disableCallback; // Store the callback instance
  final bool disable;
  final EnsembleAction? onComplete;
  final EnsembleAction? onFailure;

  factory ControlBackNavigation.from({Map? payload}) {
    return ControlBackNavigation(
      disable: payload?['disable'] ?? true,
      onComplete: payload?['onComplete'] != null
          ? EnsembleAction.from(payload!['onComplete'])
          : null,
      onFailure: payload?['onFailure'] != null
          ? EnsembleAction.from(payload?['onFailure'])
          : null,
    );
  }

  factory ControlBackNavigation.fromMap(dynamic inputs) =>
      ControlBackNavigation.from(payload: Utils.getYamlMap(inputs));

  @override
  Future<void> execute(BuildContext context, ScopeManager scopeManager) async {
    try {
      // Attach the back button override
      _disableBackButton(context);

      if (onComplete != null) {
        await ScreenController().executeAction(
          context,
          onComplete!,
          event: EnsembleEvent(initiator, data: {
            'message': disable ? 'Back button disabled' : 'Back button enabled'
          }),
        );
      }
    } catch (e) {
      if (onFailure != null) {
        await ScreenController().executeAction(
          context,
          onFailure!,
          event: EnsembleEvent(initiator, data: {'error': e.toString()}),
        );
      }
      rethrow;
    }
  }

  void _disableBackButton(BuildContext context) {
    ModalRoute? currentRoute = ModalRoute.of(context);
    if (currentRoute != null) {
      if (disable) {
        // Check if the callback is already added
        if (_disableCallback == null) {
          // Create and store the callback
          _disableCallback = () async => false;
          currentRoute.addScopedWillPopCallback(_disableCallback!);
        }
      } else {
        // Remove the previously added callback
        if (_disableCallback != null) {
          currentRoute.removeScopedWillPopCallback(_disableCallback!);
          _disableCallback = null; // Clear the stored callback
        }
      }
    } else {
      throw LanguageError(
          "Unable to find the current route to modify back navigation.");
    }
  }
}
