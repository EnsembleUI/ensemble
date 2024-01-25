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

class ProcessNotificationAction extends EnsembleAction {
  ProcessNotificationAction(
      {super.initiator, required this.onNotification, this.onNoNotification});

  EnsembleAction? onNotification;
  EnsembleAction? onNoNotification;

  factory ProcessNotificationAction.fromMap({dynamic payload}) {
    if (payload is Map) {
      EnsembleAction? onNotification =
          EnsembleAction.fromYaml(payload['onNotification']);
      if (onNotification == null) {
        throw LanguageError(
            "onNotification() is required for Process Notification Action");
      }
      return ProcessNotificationAction(
          onNotification: onNotification,
          onNoNotification: EnsembleAction.fromYaml(payload['onError']));
    }
    throw LanguageError("Missing inputs for getDeviceToken.}");
  }

  @override
  Future execute(BuildContext context, ScopeManager scopeManager) async {
    final remoteNotification = await NotificationManager().getInitialMessage();
    final data = {
      'notification': {
        'title': remoteNotification?.notification?.title,
        'body': remoteNotification?.notification?.body,
      },
      'data': remoteNotification?.data,
    };
    if (remoteNotification != null && onNotification != null) {
      return ScreenController().executeAction(context, onNotification!,
          event: EnsembleEvent(initiator, data: data));
    }
    if (remoteNotification == null && onNoNotification != null) {
      return ScreenController().executeAction(context, onNoNotification!,
          event: EnsembleEvent(initiator,
              error: 'Unable to get the remote notification message.'));
    }
  }
}
