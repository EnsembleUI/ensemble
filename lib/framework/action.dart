import 'package:app_settings/app_settings.dart';
import 'package:ensemble/action/badge_action.dart';
import 'package:ensemble/action/bottom_modal_action.dart';
import 'package:ensemble/action/call_external_method.dart';
import 'package:ensemble/action/invoke_api_action.dart';
import 'package:ensemble/action/misc_action.dart';
import 'package:ensemble/action/navigation_action.dart';
import 'package:ensemble/action/notification_action.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/permissions_manager.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/widget/view_util.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'package:source_span/source_span.dart';
import 'package:yaml/yaml.dart';

class ShowCameraAction extends EnsembleAction {
  ShowCameraAction({
    Invokable? initiator,
    this.options,
    this.id,
    this.onComplete,
    this.onClose,
    this.onCapture,
  }) : super(initiator: initiator);
  final Map<String, dynamic>? options;
  String? id;
  EnsembleAction? onComplete;
  EnsembleAction? onClose;
  EnsembleAction? onCapture;

  factory ShowCameraAction.fromYaml({Invokable? initiator, Map? payload}) {
    return ShowCameraAction(
      initiator: initiator,
      options: Utils.getMap(payload?['options']),
      id: Utils.optionalString(payload?['id']),
      onComplete: EnsembleAction.fromYaml(payload?['onComplete']),
      onClose: EnsembleAction.fromYaml(payload?['onClose']),
      onCapture: EnsembleAction.fromYaml(payload?['onCapture']),
    );
  }
}

/// TODO: support inputs for Dialog
class ShowDialogAction extends EnsembleAction {
  ShowDialogAction({
    super.initiator,
    required this.widget,
    //super.inputs,
    this.options,
    this.onDialogDismiss,
  });

  final dynamic widget;
  final Map<String, dynamic>? options;
  final EnsembleAction? onDialogDismiss;

  factory ShowDialogAction.fromYaml({Invokable? initiator, Map? payload}) {
    if (payload == null || payload['widget'] == null) {
      throw LanguageError(
          "${ActionType.showDialog.name} requires the 'widget' for the Dialog's content.");
    }
    return ShowDialogAction(
        initiator: initiator,
        widget: payload['widget'],
        //inputs: Utils.getMap(payload["inputs"]),
        options: Utils.getMap(payload['options']),
        onDialogDismiss: EnsembleAction.fromYaml(payload['onDialogDismiss']));
  }
}

class NavigateScreenAction extends BaseNavigateScreenAction {
  NavigateScreenAction(
      {super.initiator,
      required super.screenName,
      super.inputs,
      super.options,
      this.onNavigateBack,
      super.transition,
      super.isExternal})
      : super(asModal: false);
  EnsembleAction? onNavigateBack;

  factory NavigateScreenAction.fromYaml({Invokable? initiator, Map? payload}) {
    if (payload == null || payload['name'] == null) {
      throw LanguageError(
          "${ActionType.navigateScreen.name} requires the 'name' of the screen to navigate to.");
    }
    return NavigateScreenAction(
      initiator: initiator,
      screenName: payload['name'].toString(),
      inputs: Utils.getMap(payload['inputs']),
      options: Utils.getMap(payload['options']),
      onNavigateBack: EnsembleAction.fromYaml(payload['onNavigateBack']),
      transition: Utils.getMap(payload['transition']),
      isExternal: Utils.getBool(payload['external'], fallback: false),
    );
  }

  factory NavigateScreenAction.fromMap(dynamic inputs) {
    // just have the screen name only
    if (inputs is String) {
      return NavigateScreenAction(screenName: inputs);
    }
    return NavigateScreenAction.fromYaml(payload: Utils.getYamlMap(inputs));
  }
}

class NavigateModalScreenAction extends BaseNavigateScreenAction {
  NavigateModalScreenAction({
    super.initiator,
    required super.screenName,
    super.inputs,
    this.onModalDismiss,
  }) : super(asModal: true);
  EnsembleAction? onModalDismiss;

  factory NavigateModalScreenAction.fromYaml(
      {Invokable? initiator, Map? payload}) {
    if (payload == null || payload['name'] == null) {
      throw LanguageError(
          "${ActionType.navigateModalScreen.name} requires the 'name' of the screen to navigate to.");
    }
    return NavigateModalScreenAction(
        initiator: initiator,
        screenName: payload['name'].toString(),
        inputs: Utils.getMap(payload['inputs']),
        onModalDismiss: EnsembleAction.fromYaml(payload['onModalDismiss']));
  }
}

abstract class BaseNavigateScreenAction extends EnsembleAction {
  BaseNavigateScreenAction(
      {super.initiator,
      required this.screenName,
      required this.asModal,
      this.transition,
      super.inputs,
      this.options,
      this.isExternal = false});

  String screenName;
  bool asModal;
  Map<String, dynamic>? transition;
  final Map<String, dynamic>? options;
  final bool isExternal;
}

class PlaidLinkAction extends EnsembleAction {
  PlaidLinkAction({
    super.initiator,
    required this.linkToken,
    this.onSuccess,
    this.onEvent,
    this.onExit,
  });

  final String linkToken;
  final EnsembleAction? onSuccess;
  final EnsembleAction? onEvent;
  final EnsembleAction? onExit;

  String getLinkToken(dataContext) =>
      Utils.getString(dataContext.eval(linkToken), fallback: '');

  factory PlaidLinkAction.fromYaml({Invokable? initiator, Map? payload}) {
    if (payload == null || payload['linkToken'] == null) {
      throw LanguageError(
          "${ActionType.openPlaidLink.name} action requires the plaid's link_token");
    }

    return PlaidLinkAction(
      initiator: initiator,
      linkToken: payload['linkToken'],
      onSuccess: EnsembleAction.fromYaml(payload['onSuccess']),
      onEvent: EnsembleAction.fromYaml(payload['onEvent']),
      onExit: EnsembleAction.fromYaml(payload['onExit']),
    );
  }
}

class AppSettingAction extends EnsembleAction {
  AppSettingAction({
    super.initiator,
    required this.target,
  });

  final String target;

  AppSettingsType getTarget(dataContext) =>
      AppSettingsType.values.from(dataContext.eval(target)) ??
      AppSettingsType.settings;

  factory AppSettingAction.fromYaml({Invokable? initiator, Map? payload}) {
    return AppSettingAction(
      initiator: initiator,
      target: Utils.getString(payload?['target'], fallback: 'settings'),
    );
  }
}

class PhoneContactAction extends EnsembleAction {
  PhoneContactAction({
    super.initiator,
    this.id,
    this.onSuccess,
    this.onError,
  });

  final String? id;
  final EnsembleAction? onSuccess;
  final EnsembleAction? onError;

  EnsembleAction? getOnSuccess(DataContext dataContext) =>
      dataContext.eval(onSuccess);

  EnsembleAction? getOnError(DataContext dataContext) =>
      dataContext.eval(onError);

  factory PhoneContactAction.fromYaml({Invokable? initiator, Map? payload}) {
    if (payload == null) {
      throw LanguageError(
          "${ActionType.getPhoneContacts.name} action requires payload");
    }

    return PhoneContactAction(
      initiator: initiator,
      id: Utils.optionalString(payload['id']),
      onSuccess: EnsembleAction.fromYaml(payload['onSuccess']),
      onError: EnsembleAction.fromYaml(payload['onError']),
    );
  }
}

class StartTimerAction extends EnsembleAction {
  StartTimerAction(
      {super.initiator,
      required this.onTimer,
      this.onTimerComplete,
      this.id,
      options})
      : _options = options;

  final String? id;
  final EnsembleAction onTimer;
  final EnsembleAction? onTimerComplete;
  final Map<String, dynamic>? _options;

  // The initial delay in seconds
  int? getStartAfter(DataContext dataContext) =>
      Utils.optionalInt(dataContext.eval(_options?['startAfter']), min: 0);

  bool isRepeat(dataContext) =>
      Utils.getBool(dataContext.eval(_options?['repeat']), fallback: false);

  // The repeat interval in seconds
  int? getRepeatInterval(dataContext) =>
      Utils.optionalInt(dataContext.eval(_options?['repeatInterval']), min: 1);

  // how many times to trigger onTimer
  int? getMaxTimes(dataContext) =>
      Utils.optionalInt(dataContext.eval(_options?['maxNumberOfTimes']),
          min: 1);

  // if global is marked, only 1 instance is available for the entire app
  bool? isGlobal(dataContext) =>
      Utils.optionalBool(dataContext.eval(_options?['isGlobal']));

  factory StartTimerAction.fromYaml({Invokable? initiator, Map? payload}) {
    EnsembleAction? onTimer =
        EnsembleAction.fromYaml(payload?['onTimer'], initiator: initiator);
    if (payload == null || onTimer == null) {
      throw LanguageError(
          "${ActionType.startTimer.name} requires a valid 'onTimer' action.");
    }
    EnsembleAction? onTimerComplete = EnsembleAction.fromYaml(
        payload['onTimerComplete'],
        initiator: initiator);

    return StartTimerAction(
        initiator: initiator,
        onTimer: onTimer,
        onTimerComplete: onTimerComplete,
        id: Utils.optionalString(payload['id']),
        options: Utils.getMap(payload['options']));
  }

  factory StartTimerAction.fromMap(dynamic inputs) =>
      StartTimerAction.fromYaml(payload: Utils.getYamlMap(inputs));
}

class StopTimerAction extends EnsembleAction {
  StopTimerAction(this.id);

  String id;

  factory StopTimerAction.fromYaml({Map? payload}) {
    if (payload?['id'] == null) {
      throw LanguageError(
          "${ActionType.stopTimer.name} requires a timer Id to stop.");
    }
    return StopTimerAction(payload!['id'].toString());
  }
}

class CloseAllDialogsAction extends EnsembleAction {}

/// TODO: confirm codeBlockSpan
class ExecuteCodeAction extends EnsembleAction {
  ExecuteCodeAction(
      {super.initiator,
      super.inputs,
      required this.codeBlock,
      this.onComplete,
      required this.codeBlockSpan});

  String codeBlock;
  EnsembleAction? onComplete;
  SourceSpan codeBlockSpan;

  factory ExecuteCodeAction.fromYaml({Invokable? initiator, Map? payload}) {
    if (payload == null || payload['body'] == null) {
      throw LanguageError(
          "${ActionType.executeCode.name} requires a 'body' code block.");
    }
    return ExecuteCodeAction(
        initiator: initiator,
        inputs: Utils.getMap(payload['inputs']),
        codeBlock: payload['body'].toString(),
        onComplete: EnsembleAction.fromYaml(payload['onComplete'],
            initiator: initiator),
        codeBlockSpan:
            ViewUtil.optDefinition((payload as YamlMap).nodes['body']));
  }
}

class OpenUrlAction extends EnsembleAction {
  OpenUrlAction(this.url, {this.openInExternalApp = false});

  String url;
  bool openInExternalApp;

  factory OpenUrlAction.fromYaml({Map? payload}) {
    if (payload == null || payload['url'] == null) {
      throw LanguageError("${ActionType.openUrl.name} requires the 'url'.");
    }
    return OpenUrlAction(payload['url'].toString(),
        openInExternalApp:
            Utils.getBool(payload['openInExternalApp'], fallback: false));
  }

  factory OpenUrlAction.fromMap(dynamic inputs) =>
      OpenUrlAction.fromYaml(payload: Utils.getYamlMap(inputs));
}

class ShowToastAction extends EnsembleAction {
  ShowToastAction(
      {super.initiator,
      this.type,
      this.title,
      this.message,
      this.widget,
      this.dismissible,
      this.alignment,
      this.duration,
      this.styles});

  ToastType? type;
  final String? title;

  // either message or widget is needed
  final String? message;
  final dynamic widget;

  final bool? dismissible;

  final Alignment? alignment;
  final int? duration; // the during in seconds before toast is dismissed
  final Map<String, dynamic>? styles;

  factory ShowToastAction.fromYaml({Map? payload}) {
    if (payload == null ||
        (payload['message'] == null && payload['widget'] == null)) {
      throw LanguageError(
          "${ActionType.showToast.name} requires either a message or a widget to render.");
    }
    return ShowToastAction(
        type: ToastType.values.from(payload['options']?['type']),
        title: Utils.optionalString(payload['title']),
        message: payload['message']?.toString(),
        widget: payload['widget'],
        dismissible: Utils.optionalBool(payload['options']?['dismissible']),
        alignment: Utils.getAlignment(payload['options']?['alignment']),
        duration: Utils.optionalInt(payload['options']?['duration'], min: 1),
        styles: Utils.getMap(payload['styles']));
  }

  factory ShowToastAction.fromMap(dynamic inputs) =>
      ShowToastAction.fromYaml(payload: Utils.getYamlMap(inputs));
}

class GetLocationAction extends EnsembleAction {
  GetLocationAction(
      {this.onLocationReceived,
      this.onError,
      this.recurring,
      this.recurringDistanceFilter});

  EnsembleAction? onLocationReceived;
  EnsembleAction? onError;

  bool? recurring;
  int? recurringDistanceFilter;
}

class FilePickerAction extends EnsembleAction {
  FilePickerAction({
    required this.id,
    this.allowedExtensions,
    this.allowMultiple,
    this.allowCompression,
    this.onComplete,
    this.onError,
  });

  String id;
  List<String>? allowedExtensions;
  bool? allowMultiple;
  bool? allowCompression;
  EnsembleAction? onComplete;
  EnsembleAction? onError;

  factory FilePickerAction.fromYaml({Map? payload}) {
    if (payload == null || payload['id'] == null) {
      throw LanguageError("${ActionType.pickFiles.name} requires 'id'.");
    }

    return FilePickerAction(
      id: Utils.getString(payload['id'], fallback: ''),
      allowedExtensions:
          (payload['allowedExtensions'] as YamlList?)?.cast<String>().toList(),
      allowMultiple: Utils.optionalBool(payload['allowMultiple']),
      allowCompression: Utils.optionalBool(payload['allowCompression']),
      onComplete: EnsembleAction.fromYaml(payload['onComplete']),
      onError: EnsembleAction.fromYaml(payload['onError']),
    );
  }
}

class FileUploadAction extends EnsembleAction {
  FileUploadAction({
    Map<String, dynamic>? inputs,
    this.id,
    this.onComplete,
    this.onError,
    required this.uploadApi,
    required this.fieldName,
    this.maxFileSize,
    this.overMaxFileSizeMessage,
    required this.isBackgroundTask,
    required this.files,
    this.networkType,
    this.requiresBatteryNotLow,
    required this.showNotification,
  }) : super(inputs: inputs);

  String? id;
  EnsembleAction? onComplete;
  EnsembleAction? onError;
  String uploadApi;
  String fieldName;
  int? maxFileSize;
  String? overMaxFileSizeMessage;
  dynamic files;
  bool isBackgroundTask;
  String? networkType;
  bool? requiresBatteryNotLow;
  bool showNotification;

  factory FileUploadAction.fromYaml({Map? payload}) {
    if (payload == null || payload['uploadApi'] == null) {
      throw LanguageError("${ActionType.uploadFiles.name} requires '  '.");
    }
    if (payload['files'] == null) {
      throw LanguageError("${ActionType.uploadFiles.name} requires 'files'.");
    }
    return FileUploadAction(
      id: Utils.optionalString(payload['id']),
      onComplete: EnsembleAction.fromYaml(payload['onComplete']),
      onError: EnsembleAction.fromYaml(payload['onError']),
      uploadApi: payload['uploadApi'],
      inputs: Utils.getMap(payload['inputs']),
      fieldName: Utils.getString(payload['fieldName'], fallback: 'files'),
      maxFileSize: Utils.optionalInt(payload['options']?['maxFileSize']),
      overMaxFileSizeMessage:
          Utils.optionalString(payload['options']?['overMaxFileSizeMessage']),
      files: payload['files'],
      isBackgroundTask:
          Utils.getBool(payload['options']?['backgroundTask'], fallback: false),
      networkType: Utils.optionalString(payload['options']?['networkType']),
      requiresBatteryNotLow:
          Utils.optionalBool(payload['options']?['requiresBatteryNotLow']),
      showNotification: Utils.getBool(payload['options']?['showNotification'],
          fallback: false),
    );
  }
}

class WalletConnectAction extends EnsembleAction {
  WalletConnectAction({
    this.id,
    required this.wcProjectId,
    required this.appName,
    this.appDescription,
    this.appUrl,
    this.appIconUrl,
    this.onComplete,
    this.onError,
  });

  String? id;
  String wcProjectId;
  String appName;
  String? appDescription;
  String? appUrl;
  String? appIconUrl;
  EnsembleAction? onComplete;
  EnsembleAction? onError;

  factory WalletConnectAction.fromYaml({Map? payload}) {
    if (payload == null ||
        (payload['wcProjectId'] == null ||
            payload['appMetaData']?['name'] == null)) {
      throw LanguageError(
          "${ActionType.connectWallet.name} requires wcProjectId, appMetaData. Check if any is missing");
    }
    return WalletConnectAction(
      id: Utils.optionalString(payload['id']),
      wcProjectId: Utils.getString(payload['wcProjectId'], fallback: ''),
      appName: Utils.getString(payload['appMetaData']?['name'], fallback: ''),
      appDescription:
          Utils.optionalString(payload['appMetaData']?['description']),
      appUrl: Utils.optionalString(payload['appMetaData']?['url']),
      appIconUrl: Utils.optionalString(payload['appMetaData']?['iconUrl']),
      onComplete: EnsembleAction.fromYaml(payload['onComplete']),
      onError: EnsembleAction.fromYaml(payload['onError']),
    );
  }
}

/// not in use yet
class AuthorizeOAuthAction extends EnsembleAction {
  AuthorizeOAuthAction(this.id, {this.onResponse, this.onError});

  final String id;
  EnsembleAction? onResponse;
  EnsembleAction? onError;

  factory AuthorizeOAuthAction.fromYaml({Map? payload}) {
    if (payload == null || payload['id'] == null) {
      throw LanguageError(
          '${ActionType.authorizeOAuthService.name} requires the service ID.');
    }
    return AuthorizeOAuthAction(
      payload['id'],
      onResponse: EnsembleAction.fromYaml(payload['onResponse']),
      onError: EnsembleAction.fromYaml(payload['onError']),
    );
  }
}

class NotificationAction extends EnsembleAction {
  NotificationAction({this.onTap, this.onReceive});

  EnsembleAction? onTap;
  EnsembleAction? onReceive;

  factory NotificationAction.fromYaml({Invokable? initiator, Map? payload}) {
    return NotificationAction(
      onTap: EnsembleAction.fromYaml(payload?['onTap']),
      onReceive: EnsembleAction.fromYaml(payload?['onReceive']),
    );
  }
}

class RequestNotificationAction extends EnsembleAction {
  EnsembleAction? onAccept;
  EnsembleAction? onReject;

  RequestNotificationAction({this.onAccept, this.onReject});

  factory RequestNotificationAction.fromYaml(
      {Invokable? initiator, Map? payload}) {
    return RequestNotificationAction(
      onAccept: EnsembleAction.fromYaml(payload?['onAccept']),
      onReject: EnsembleAction.fromYaml(payload?['onReject']),
    );
  }
}

class ShowNotificationAction extends EnsembleAction {
  late String title;
  late String body;

  ShowNotificationAction({this.title = '', this.body = ''});

  factory ShowNotificationAction.fromYaml({Map? payload}) {
    return ShowNotificationAction(
      title: Utils.getString(payload?['title'], fallback: ''),
      body: Utils.getString(payload?['body'], fallback: ''),
    );
  }
}

class ConnectSocketAction extends EnsembleAction {
  final String name;
  final EnsembleAction? onSuccess;
  final EnsembleAction? onError;

  ConnectSocketAction({
    required this.name,
    this.onSuccess,
    this.onError,
    Map<String, dynamic>? inputs,
  }) : super(inputs: inputs);

  factory ConnectSocketAction.fromYaml({Map? payload}) {
    if (payload == null || payload['name'] == null) {
      throw ConfigError('connectSocket requires a name');
    }
    return ConnectSocketAction(
      inputs: Utils.getMap(payload['inputs']),
      name: Utils.getString(payload['name'], fallback: ''),
      onSuccess: EnsembleAction.fromYaml(payload['onSuccess']),
      onError: EnsembleAction.fromYaml(payload['onError']),
    );
  }
}

class DisconnectSocketAction extends EnsembleAction {
  final String name;

  DisconnectSocketAction({required this.name});

  factory DisconnectSocketAction.fromYaml({Map? payload}) {
    if (payload == null || payload['name'] == null) {
      throw ConfigError('disconnectSocket requires a name');
    }

    return DisconnectSocketAction(
        name: Utils.getString(payload['name'], fallback: ''));
  }
}

class MessageSocketAction extends EnsembleAction {
  final String name;
  final dynamic message;

  MessageSocketAction({required this.name, required this.message});

  factory MessageSocketAction.fromYaml({Map? payload}) {
    if (payload == null || payload['name'] == null) {
      throw ConfigError('messageSocket requires a name');
    }

    return MessageSocketAction(
      name: Utils.getString(payload['name'], fallback: ''),
      message: payload['message'],
    );
  }
}

class CheckPermission extends EnsembleAction {
  CheckPermission(
      {required dynamic type,
      this.onAuthorized,
      this.onDenied,
      this.onNotDetermined})
      : _type = type;
  final dynamic _type;
  final EnsembleAction? onAuthorized;
  final EnsembleAction? onDenied;
  final EnsembleAction? onNotDetermined;

  Permission? getType(DataContext dataContext) =>
      Permission.values.from(dataContext.eval(_type));

  factory CheckPermission.fromYaml({Map? payload}) {
    if (payload == null || payload['type'] == null) {
      throw ConfigError('checkPermission requires a type.');
    }
    return CheckPermission(
      type: payload['type'],
      onAuthorized: EnsembleAction.fromYaml(payload['onAuthorized']),
      onDenied: EnsembleAction.fromYaml(payload['onDenied']),
      onNotDetermined: EnsembleAction.fromYaml(payload['onNotDetermined']),
    );
  }
}

enum ActionType {
  invokeAPI,
  navigateScreen,
  navigateExternalScreen,
  navigateModalScreen,
  showBottomModal,
  dismissBottomModal,
  showDialog,
  startTimer,
  stopTimer,
  closeAllDialogs,
  executeCode,
  showToast,
  getLocation,
  openUrl,
  openCamera,
  uploadFiles,
  navigateBack,
  pickFiles,
  connectWallet,
  authorizeOAuthService,
  notification,
  requestNotificationAccess,
  showNotification,
  copyToClipboard,
  share,
  rateApp,
  openPlaidLink,
  openAppSettings,
  getPhoneContacts,
  checkPermission,
  saveToKeychain,
  clearKeychain,
  getDeviceToken,
  connectSocket,
  disconnectSocket,
  messageSocket,
  updateBadgeCount,
  clearBadgeCount,
  callExternalMethod,
}

enum ToastType { success, error, warning, info }

/// payload representing an Action to do (navigateToScreen, InvokeAPI, ..)
abstract class EnsembleAction {
  EnsembleAction({this.initiator, this.inputs});

  // initiator is an Invokable so we can scope to *this* variable
  Invokable? initiator;
  Map<String, dynamic>? inputs;

  /// TODO: each Action does all the execution in here
  /// use DataContext to eval properties. ScopeManager should be refactored
  /// so it contains the update data context (its DataContext might not have
  /// the latest data)
  Future<dynamic> execute(BuildContext context, ScopeManager scopeManager) {
    // placeholder until all Actions are implemented
    return Future.value(null);
  }

  static EnsembleAction? fromYaml(dynamic action, {Invokable? initiator}) {
    if (action is YamlMap) {
      ActionType? actionType = ActionType.values.from(action.keys.first);
      dynamic payload = action[action.keys.first];
      if (actionType != null && payload is YamlMap?) {
        return fromActionType(actionType,
            initiator: initiator, payload: payload);
      }
    } else if (action is String) {
      /// some actions can be shorthanded by their key, e.g. navigateBack, closeAllDialogs
      ActionType? actionType = ActionType.values.from(action);
      if (actionType != null) {
        return fromActionType(actionType, initiator: initiator);
      } else {
        /// short-hand //@code string is same as ExecuteCodeAction
        return ExecuteCodeAction(
            initiator: initiator,
            codeBlock: action,
            codeBlockSpan: ViewUtil.optDefinition(null));
      }
    }
    return null;
  }

  static EnsembleAction? fromActionType(ActionType actionType,
      {Invokable? initiator, Map? payload}) {
    if (actionType == ActionType.navigateScreen) {
      return NavigateScreenAction.fromYaml(
          initiator: initiator, payload: payload);
    } else if (actionType == ActionType.navigateExternalScreen) {
      return NavigateExternalScreen.from(
          initiator: initiator, payload: payload);
    } else if (actionType == ActionType.navigateModalScreen) {
      return NavigateModalScreenAction.fromYaml(
          initiator: initiator, payload: payload);
    } else if (actionType == ActionType.navigateBack) {
      return NavigateBackAction.from(payload: payload);
    } else if (actionType == ActionType.showBottomModal) {
      return ShowBottomModalAction.from(payload: payload);
    } else if (actionType == ActionType.dismissBottomModal) {
      return DismissBottomModalAction.from(payload: payload);
    } else if (actionType == ActionType.invokeAPI) {
      return InvokeAPIAction.fromYaml(initiator: initiator, payload: payload);
    } else if (actionType == ActionType.openCamera) {
      return ShowCameraAction.fromYaml(initiator: initiator, payload: payload);
    } else if (actionType == ActionType.showDialog) {
      return ShowDialogAction.fromYaml(initiator: initiator, payload: payload);
    } else if (actionType == ActionType.closeAllDialogs) {
      return CloseAllDialogsAction();
    } else if (actionType == ActionType.startTimer) {
      return StartTimerAction.fromYaml(initiator: initiator, payload: payload);
    } else if (actionType == ActionType.stopTimer) {
      return StopTimerAction.fromYaml(payload: payload);
    } else if (actionType == ActionType.showToast) {
      return ShowToastAction.fromYaml(payload: payload);
    } else if (actionType == ActionType.executeCode) {
      return ExecuteCodeAction.fromYaml(initiator: initiator, payload: payload);
    } else if (actionType == ActionType.getLocation) {
      return GetLocationAction(
          onLocationReceived:
              EnsembleAction.fromYaml(payload?['onLocationReceived']),
          onError: EnsembleAction.fromYaml(payload?['onError']),
          recurring: Utils.optionalBool(payload?['options']?['recurring']),
          recurringDistanceFilter: Utils.optionalInt(
              payload?['options']?['recurringDistanceFilter'],
              min: 50));
    } else if (actionType == ActionType.pickFiles) {
      return FilePickerAction.fromYaml(payload: payload);
    } else if (actionType == ActionType.uploadFiles) {
      return FileUploadAction.fromYaml(payload: payload);
    } else if (actionType == ActionType.pickFiles) {
      return FilePickerAction.fromYaml(payload: payload);
    } else if (actionType == ActionType.openUrl) {
      return OpenUrlAction.fromYaml(payload: payload);
    } else if (actionType == ActionType.connectWallet) {
      return WalletConnectAction.fromYaml(payload: payload);
    } else if (actionType == ActionType.authorizeOAuthService) {
      return AuthorizeOAuthAction.fromYaml(payload: payload);
    } else if (actionType == ActionType.notification) {
      return NotificationAction.fromYaml(payload: payload);
    } else if (actionType == ActionType.showNotification) {
      return ShowNotificationAction.fromYaml(payload: payload);
    } else if (actionType == ActionType.requestNotificationAccess) {
      return RequestNotificationAction.fromYaml(payload: payload);
    } else if (actionType == ActionType.copyToClipboard) {
      return CopyToClipboardAction.from(payload: payload);
    } else if (actionType == ActionType.share) {
      return ShareAction.from(payload: payload);
    } else if (actionType == ActionType.rateApp) {
      return RateAppAction.from(payload: payload);
    } else if (actionType == ActionType.getDeviceToken) {
      return GetDeviceTokenAction.fromMap(payload: payload);
    } else if (actionType == ActionType.openPlaidLink) {
      return PlaidLinkAction.fromYaml(initiator: initiator, payload: payload);
    } else if (actionType == ActionType.openAppSettings) {
      return AppSettingAction.fromYaml(initiator: initiator, payload: payload);
    } else if (actionType == ActionType.getPhoneContacts) {
      return PhoneContactAction.fromYaml(
          initiator: initiator, payload: payload);
    } else if (actionType == ActionType.checkPermission) {
      return CheckPermission.fromYaml(payload: payload);
    } else if (actionType == ActionType.connectSocket) {
      return ConnectSocketAction.fromYaml(payload: payload);
    } else if (actionType == ActionType.disconnectSocket) {
      return DisconnectSocketAction.fromYaml(payload: payload);
    } else if (actionType == ActionType.messageSocket) {
      return MessageSocketAction.fromYaml(payload: payload);
    } else if (actionType == ActionType.updateBadgeCount) {
      return UpdateBadgeCount.from(payload: payload);
    } else if (actionType == ActionType.clearBadgeCount) {
      return ClearBadgeCount();
    } else if (actionType == ActionType.callExternalMethod) {
      return CallExternalMethod.from(payload: payload);
    }
    throw LanguageError("Invalid action.",
        recovery: "Make sure to use one of Ensemble-provided actions.");
  }
}
