import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/widget/toast.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';

/// Visual styles supported by the show-toast action.
enum ToastType {
  /// Styles a toast as a successful outcome.
  success,
  /// Styles a toast as an error outcome.
  error,
  /// Styles a toast as a warning message.
  warning,
  /// Styles a toast as informational feedback.
  info
}

/// Ensemble action that displays a transient toast message.
class ShowToastAction extends EnsembleAction with HasStyles, Invokable {
  /// Creates a [ShowToastAction] action.
  ShowToastAction(
      {super.initiator,
      this.type,
      this.title,
      this.message,
      this.body,
      this.dismissible,
      this.alignment,
      this.duration,
      this.payload,
      this.styles});

  /// Action-specific type such as toast style, haptic type, or file type.
  ToastType? type;
  /// Title text shown in a toast, dialog, or notification.
  final String? title;

  /// Message text shown to the user.
  final String? message;
  /// Widget or content body rendered by a toast, dialog, or bottom sheet.
  final dynamic body;

  /// Whether the user can dismiss the UI without completing the flow.
  final bool? dismissible;

  /// Screen alignment used to position the visual element.
  final Alignment? alignment;
  /// Duration in seconds or milliseconds for a timed visual or media operation.
  final int? duration; // the during in seconds before toast is dismissed
  /// Resolved style overrides applied to the generated widget.
  Map<String, dynamic>? styles;

  /// Raw action payload passed to the action implementation.
  final Map? payload;

  @override
  Map<String, Function> getters() {
    return {};
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {};
  }

  /// Creates a [ShowToastAction] from a YAML or map action payload.
  factory ShowToastAction.fromYaml({Map? payload}) {
    if (payload == null ||
        (payload['message'] == null &&
            payload['body'] == null &&
            payload['widget'] == null)) {
      throw LanguageError(
          "${ActionType.showToast.name} requires either a message or a body widget.");
    }
    // Create a mutable copy of payload so we can update styles after resolution
    final mutablePayload = Map<String, dynamic>.from(payload);
    return ShowToastAction(
        type: ToastType.values.from(payload['options']?['type']),
        title: Utils.optionalString(payload['title']),
        message: Utils.optionalString(payload['message']),
        body: payload['body'] ?? payload['widget'],
        dismissible: Utils.optionalBool(payload['options']?['dismissible']),
        alignment: Utils.getAlignment(payload['options']?['alignment']),
        duration: Utils.optionalInt(payload['options']?['duration'], min: 1),
        styles: Utils.getMap(payload['styles']),
        payload: mutablePayload);
  }

  /// Creates a [ShowToastAction] from a YAML or map action payload.
  factory ShowToastAction.fromMap(dynamic inputs) =>
      ShowToastAction.fromYaml(payload: Utils.getYamlMap(inputs));

  /// Runs this action and renders the toast and applies its configured style.
  @override
  Future execute(BuildContext context, ScopeManager scopeManager) {
    Widget? customToastBody;
    if (body != null) {
      customToastBody = scopeManager.buildWidgetFromDefinition(body);
    }
    ToastController().showToast(context, this, customToastBody,
        dataContext: scopeManager.dataContext);
    return Future.value(null);
  }
}
