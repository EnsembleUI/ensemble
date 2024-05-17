import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/widget/toast.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/cupertino.dart';

enum ToastType { success, error, warning, info }

class ShowToastAction extends EnsembleAction {
  ShowToastAction(
      {super.initiator,
      this.type,
      this.title,
      this.message,
      this.body,
      this.dismissible,
      this.alignment,
      this.duration,
      this.styles});

  ToastType? type;
  final String? title;

  // either message or widget is needed
  final String? message;
  final dynamic body;

  final bool? dismissible;

  final Alignment? alignment;
  final int? duration; // the during in seconds before toast is dismissed
  final Map<String, dynamic>? styles;

  factory ShowToastAction.fromYaml({Map? payload}) {
    if (payload == null ||
        (payload['message'] == null &&
            payload['body'] == null &&
            payload['widget'] == null)) {
      throw LanguageError(
          "${ActionType.showToast.name} requires either a message or a body widget.");
    }
    return ShowToastAction(
        type: ToastType.values.from(payload['options']?['type']),
        title: Utils.optionalString(payload['title']),
        message: Utils.optionalString(payload['message']),
        body: payload['body'] ?? payload['widget'],
        dismissible: Utils.optionalBool(payload['options']?['dismissible']),
        alignment: Utils.getAlignment(payload['options']?['alignment']),
        duration: Utils.optionalInt(payload['options']?['duration'], min: 1),
        styles: Utils.getMap(payload['styles']));
  }

  factory ShowToastAction.fromMap(dynamic inputs) =>
      ShowToastAction.fromYaml(payload: Utils.getYamlMap(inputs));

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
