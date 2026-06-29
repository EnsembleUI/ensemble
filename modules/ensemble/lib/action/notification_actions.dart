import 'dart:convert';

import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/notification_manager.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/notification_utils.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';

/**
 * request user authorization to send push notification.
 * This works for both local and server (Firebase) notifications
 */
/// Ensemble action that requests push or local notification permission.
class RequestNotificationAccessAction extends EnsembleAction {
  /// Action executed when notification permission is authorized.
  EnsembleAction? onAuthorized;
  /// Action executed when permission is denied.
  EnsembleAction? onDenied;
  /// Action executed for provisional notification authorization.
  EnsembleAction? onProvisional;
  /// Action executed when notification permission has not been decided.
  EnsembleAction? onNotDetermined;

  /// Whether the permission request targets only local notifications.
  bool? localNotificationOnly;

  /// Action executed when the user accepts a permission prompt.
  EnsembleAction? onAccept;
  /// Action executed when the user rejects a permission prompt.
  EnsembleAction? onReject;

  /// Creates a [RequestNotificationAccessAction] action.
  RequestNotificationAccessAction(
      {super.initiator,
      this.onAuthorized,
      this.onDenied,
      this.onProvisional,
      this.onNotDetermined,
      this.localNotificationOnly,

      // legacy
      this.onAccept,
      this.onReject});

  /// Creates a [RequestNotificationAccessAction] from a YAML or map action payload.
  factory RequestNotificationAccessAction.from(
      {Invokable? initiator, Map? payload}) {
    return RequestNotificationAccessAction(
      onAuthorized: EnsembleAction.from(payload?["onAuthorized"]),
      onDenied: EnsembleAction.from(payload?["onDenied"]),
      localNotificationOnly:
          Utils.optionalBool(payload?["localNotificationOnly"]),
      onAccept: EnsembleAction.from(payload?['onAccept']),
      onReject: EnsembleAction.from(payload?['onReject']),
    );
  }

  /// Runs this action and requests notification permission and dispatches status callbacks.
  @override
  Future execute(BuildContext context, ScopeManager scopeManager) async {
    AuthorizationStatus? status;
    String? deviceToken;

    // local notifications don't need Firebase
    if (localNotificationOnly == true) {
      status = await notificationUtils.initNotifications() == true
          ? AuthorizationStatus.authorized
          : AuthorizationStatus.denied;
    }
    // Server notification (Firebase)
    else {
      status = await NotificationManager().requestAccess();
      if (status == AuthorizationStatus.authorized ||
          status == AuthorizationStatus.provisional) {
        deviceToken = await NotificationManager().getDeviceToken();
      }
    }
    return executeActions(context, status, deviceToken);
  }

  /// Dispatches notification permission callbacks for an authorization status.
  Future executeActions(BuildContext context, AuthorizationStatus? status,
      String? deviceToken) async {
    EnsembleEvent event = EnsembleEvent(initiator,
        data: deviceToken != null ? {"deviceToken": deviceToken} : {});

    if (status == AuthorizationStatus.authorized) {
      if (onAuthorized != null) {
        await ScreenController()
            .executeAction(context, onAuthorized!, event: event);
      }
      // legacy
      if (onAccept != null) {
        await ScreenController()
            .executeAction(context, onAccept!, event: event);
      }
    } else if (status == AuthorizationStatus.denied) {
      if (onDenied != null) {
        await ScreenController()
            .executeAction(context, onDenied!, event: event);
      }
      // legacy
      if (onReject != null) {
        await ScreenController()
            .executeAction(context, onReject!, event: event);
      }
    }

    // other status
    if (status == AuthorizationStatus.provisional && onProvisional != null) {
      await ScreenController()
          .executeAction(context, onProvisional!, event: event);
    }
    if (status == AuthorizationStatus.notDetermined &&
        onNotDetermined != null) {
      await ScreenController()
          .executeAction(context, onNotDetermined!, event: event);
    }
    return;
  }
}

/**
 * Show a notification locally from the device
 */
/// Ensemble action that displays a local notification.
class ShowLocalNotificationAction extends EnsembleAction {
  /// Title text shown in a toast, dialog, or notification.
  String title;
  /// Widget or content body rendered by a toast, dialog, or bottom sheet.
  String? body;
  /// Raw action payload passed to the action implementation.
  Map? payload;

  /// Creates a [ShowLocalNotificationAction] action.
  ShowLocalNotificationAction({required this.title, this.body, this.payload});

  /// Creates a [ShowLocalNotificationAction] from a YAML or map action payload.
  factory ShowLocalNotificationAction.from({Map? payload}) {
    String? title = Utils.optionalString(payload?['title']);
    if (title == null) {
      throw LanguageError("Notification title is required");
    }
    return ShowLocalNotificationAction(
      title: title,
      body: Utils.optionalString(payload?['body']),
      payload: Utils.getMap(payload?['payload']),
    );
  }

  /// Runs this action and shows the configured local notification.
  @override
  Future execute(BuildContext context, ScopeManager scopeManager) async {
    if (await notificationUtils.initNotifications() == true) {
      scopeManager.dataContext.addDataContext(Ensemble.externalDataContext);
      return notificationUtils.showNotification(
        scopeManager.dataContext.eval(title),
        body: scopeManager.dataContext.eval(body),
        payload: jsonEncode(scopeManager.dataContext.eval(payload)),
      );
    }
  }
}

/// Ensemble action that fetches the push notification device token.
class GetDeviceTokenAction extends EnsembleAction {
  /// Creates a [GetDeviceTokenAction] action.
  GetDeviceTokenAction(
      {super.initiator, required this.onSuccess, this.onError});

  /// Action executed when the operation succeeds.
  EnsembleAction? onSuccess;
  /// Action executed when the operation fails.
  EnsembleAction? onError;

  /// Creates a [GetDeviceTokenAction] from a YAML or map action payload.
  factory GetDeviceTokenAction.fromMap({dynamic payload}) {
    if (payload is Map) {
      EnsembleAction? successAction = EnsembleAction.from(payload['onSuccess']);
      if (successAction == null) {
        throw LanguageError("onSuccess() is required for Get Token Action");
      }
      return GetDeviceTokenAction(
          onSuccess: successAction,
          onError: EnsembleAction.from(payload['onError']));
    }
    throw LanguageError("Missing inputs for getDeviceToken.}");
  }

  @override
  Future execute(BuildContext context, ScopeManager scopeManager) async {
    var status = await NotificationManager().requestAccess();
    if (status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional) {
      var deviceToken = await NotificationManager().getDeviceToken();
      if (deviceToken != null) {
        if (onSuccess != null) {
          return ScreenController().executeAction(context, onSuccess!,
              event: EnsembleEvent(initiator, data: {'token': deviceToken}));
        }
        return;
      }
    }

    if (onError != null) {
      return ScreenController().executeAction(context, onError!,
          event: EnsembleEvent(initiator,
              error: 'Unable to get the device token.'));
    }
  }
}
