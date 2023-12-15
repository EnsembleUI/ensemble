import 'dart:developer';

import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/notification_manager.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';

class GetDeviceTokenAction extends EnsembleAction {
  GetDeviceTokenAction(
      {super.initiator, required this.onSuccess, this.onError});

  EnsembleAction? onSuccess;
  EnsembleAction? onError;

  factory GetDeviceTokenAction.fromMap({dynamic payload}) {
    if (payload is Map) {
      EnsembleAction? successAction =
          EnsembleAction.fromYaml(payload['onSuccess']);
      if (successAction == null) {
        throw LanguageError("onSuccess() is required for Get Token Action");
      }
      return GetDeviceTokenAction(
          onSuccess: successAction,
          onError: EnsembleAction.fromYaml(payload['onError']));
    }
    throw LanguageError("Missing inputs for getDeviceToken.}");
  }

  @override
  Future execute(BuildContext context, ScopeManager scopeManager) async {
    String? deviceToken = await NotificationManager().getDeviceToken();
    if (deviceToken != null && onSuccess != null) {
      return ScreenController().executeAction(context, onSuccess!,
          event: EnsembleEvent(initiator, data: {'token': deviceToken}));
    }
    if (deviceToken == null && onError != null) {
      return ScreenController().executeAction(context, onError!,
          event: EnsembleEvent(initiator,
              error: 'Unable to get the device token.'));
    }
  }
}
