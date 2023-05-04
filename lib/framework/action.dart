import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/widget/view_util.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:source_span/source_span.dart';
import 'package:yaml/yaml.dart';

class InvokeAPIAction extends EnsembleAction {
  InvokeAPIAction(
      {Invokable? initiator,
      required this.apiName,
      this.id,
      Map<String, dynamic>? inputs,
      this.onResponse,
      this.onError})
      : super(initiator: initiator, inputs: inputs);

  String? id;
  final String apiName;
  EnsembleAction? onResponse;
  EnsembleAction? onError;

  factory InvokeAPIAction.fromYaml({Invokable? initiator, YamlMap? payload}) {
    if (payload == null || payload['name'] == null) {
      throw LanguageError(
          "${ActionType.invokeAPI.name} requires the 'name' of the API.");
    }
    return InvokeAPIAction(
        initiator: initiator,
        apiName: payload['name'],
        id: Utils.optionalString(payload['id']),
        inputs: Utils.getMap(payload['inputs']),
        onResponse: EnsembleAction.fromYaml(payload['onResponse'],
            initiator: initiator),
        onError:
            EnsembleAction.fromYaml(payload['onError'], initiator: initiator));
  }
}

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

  factory ShowCameraAction.fromYaml({Invokable? initiator, YamlMap? payload}) {
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

  factory ShowDialogAction.fromYaml({Invokable? initiator, YamlMap? payload}) {
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
      super.transition})
      : super(asModal: false);

  factory NavigateScreenAction.fromYaml(
      {Invokable? initiator, YamlMap? payload}) {
    if (payload == null || payload['name'] == null) {
      throw LanguageError(
          "${ActionType.navigateScreen.name} requires the 'name' of the screen to navigate to.");
    }
    return NavigateScreenAction(
      initiator: initiator,
      screenName: payload['name'].toString(),
      inputs: Utils.getMap(payload['inputs']),
      options: Utils.getMap(payload['options']),
      transition: Utils.getMap(payload['transition']),
    );
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
      {Invokable? initiator, YamlMap? payload}) {
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
      this.options});

  String screenName;
  bool asModal;
  Map<String, dynamic>? transition;
  final Map<String, dynamic>? options;
}

class StartTimerAction extends EnsembleAction {
  StartTimerAction(
      {super.initiator,
      required this.onTimer,
      this.onTimerComplete,
      this.payload});

  final EnsembleAction onTimer;
  final EnsembleAction? onTimerComplete;
  final TimerPayload? payload;

  factory StartTimerAction.fromYaml({Invokable? initiator, YamlMap? payload}) {
    EnsembleAction? onTimer =
        EnsembleAction.fromYaml(payload?['onTimer'], initiator: initiator);
    if (payload == null || onTimer == null) {
      throw LanguageError(
          "${ActionType.startTimer.name} requires a valid 'onTimer' action.");
    }
    EnsembleAction? onTimerComplete = EnsembleAction.fromYaml(
        payload['onTimerComplete'],
        initiator: initiator);
    TimerPayload? timerPayload;
    if (payload['options'] is YamlMap) {
      timerPayload = TimerPayload(
          id: Utils.optionalString(payload['id']),
          startAfter:
              Utils.optionalInt(payload['options']['startAfter'], min: 0),
          repeat: Utils.getBool(payload['options']['repeat'], fallback: false),
          repeatInterval:
              Utils.optionalInt(payload['options']['repeatInterval'], min: 1),
          maxTimes:
              Utils.optionalInt(payload['options']['maxNumberOfTimes'], min: 1),
          isGlobal: Utils.optionalBool(payload['options']['isGlobal']));
    }
    if (timerPayload?.repeat == true && timerPayload?.repeatInterval == null) {
      throw LanguageError(
          "${ActionType.startTimer.name}'s repeatInterval needs a value when repeat is on");
    }
    return StartTimerAction(
        initiator: initiator,
        onTimer: onTimer,
        onTimerComplete: onTimerComplete,
        payload: timerPayload);
  }
}

class StopTimerAction extends EnsembleAction {
  StopTimerAction(this.id);
  String id;

  factory StopTimerAction.fromYaml({YamlMap? payload}) {
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

  factory ExecuteCodeAction.fromYaml({Invokable? initiator, YamlMap? payload}) {
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
        codeBlockSpan: ViewUtil.optDefinition(payload.nodes['body']));
  }
}

class OpenUrlAction extends EnsembleAction {
  OpenUrlAction(this.url, {this.openInExternalApp = false});
  String url;
  bool openInExternalApp;

  factory OpenUrlAction.fromYaml({YamlMap? payload}) {
    if (payload == null || payload['url'] == null) {
      throw LanguageError("${ActionType.openUrl.name} requires the 'url'.");
    }
    return OpenUrlAction(payload['url'].toString(),
        openInExternalApp:
            Utils.getBool(payload['openInExternalApp'], fallback: false));
  }
}

class NavigateBack extends EnsembleAction {}

class ShowToastAction extends EnsembleAction {
  ShowToastAction(
      {super.initiator,
      required this.type,
      this.title,
      this.message,
      this.widget,
      this.dismissible,
      this.position,
      this.duration,
      this.styles});

  final ToastType type;

  // either message or widget is needed
  final String? title;
  final String? message;
  final dynamic widget;

  final bool? dismissible;
  final String? position;
  final int? duration; // the during in seconds before toast is dismissed
  final Map<String, dynamic>? styles;

  factory ShowToastAction.fromYaml({YamlMap? payload}) {
    if (payload == null ||
        ((payload['title'] == null && payload['message'] == null) &&
            payload['widget'] == null)) {
      throw LanguageError(
          "${ActionType.showToast.name} requires either a title/message or a widget to render.");
    }
    return ShowToastAction(
        type: ToastType.values.from(payload['options']?['type']) ??
            ToastType.info,
        title: Utils.optionalString(payload['title']),
        message: payload['message']?.toString(),
        widget: payload['widget'],
        dismissible: Utils.optionalBool(payload['options']?['dismissible']),
        position: Utils.optionalString(payload['options']?['position']),
        duration: Utils.optionalInt(payload['options']?['duration'], min: 1),
        styles: Utils.getMap(payload['styles']));
  }
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

class TimerPayload {
  TimerPayload(
      {this.id,
      this.startAfter,
      required this.repeat,
      this.repeatInterval,
      this.maxTimes,
      this.isGlobal});

  final String? id;
  final int? startAfter; // The initial delay in seconds

  final bool repeat;
  final int? repeatInterval; // The repeat interval in seconds
  final int? maxTimes; // how many times to trigger onTimer

  final bool?
      isGlobal; // if global is marked, only 1 instance is available for the entire app
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

  factory FilePickerAction.fromYaml({YamlMap? payload}) {
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
    required this.files,
  }) : super(inputs: inputs);

  String? id;
  EnsembleAction? onComplete;
  EnsembleAction? onError;
  String uploadApi;
  String fieldName;
  int? maxFileSize;
  String? overMaxFileSizeMessage;
  String files;

  factory FileUploadAction.fromYaml({YamlMap? payload}) {
    if (payload == null || payload['uploadApi'] == null) {
      throw LanguageError(
          "${ActionType.uploadFiles.name} requires 'uploadApi'.");
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
      maxFileSize: Utils.optionalInt(payload['maxFileSize']),
      overMaxFileSizeMessage:
          Utils.optionalString(payload['overMaxFileSizeMessage']),
      files: payload['files'],
    );
  }
}

class CopyToClipboardAction extends EnsembleAction {
  CopyToClipboardAction({
    this.value,
    this.onSuccess,
    this.onFailure,
  });
  String? value;
  EnsembleAction? onSuccess;
  EnsembleAction? onFailure;
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

  factory WalletConnectAction.fromYaml({YamlMap? payload}) {
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

enum ActionType {
  invokeAPI,
  navigateScreen,
  navigateModalScreen,
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
}

enum ToastType { success, error, warning, info }

/// payload representing an Action to do (navigateToScreen, InvokeAPI, ..)
abstract class EnsembleAction {
  EnsembleAction({this.initiator, this.inputs});

  // initiator is an Invokable so we can scope to *this* variable
  Invokable? initiator;
  Map<String, dynamic>? inputs;

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
      {Invokable? initiator, YamlMap? payload}) {
    if (actionType == ActionType.navigateScreen) {
      return NavigateScreenAction.fromYaml(
          initiator: initiator, payload: payload);
    } else if (actionType == ActionType.navigateModalScreen) {
      return NavigateModalScreenAction.fromYaml(
          initiator: initiator, payload: payload);
    } else if (actionType == ActionType.navigateBack) {
      return NavigateBack();
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
    } else if (actionType == ActionType.uploadFiles) {
      return FileUploadAction.fromYaml(payload: payload);
    } else if (actionType == ActionType.pickFiles) {
      return FilePickerAction.fromYaml(payload: payload);
    } else if (actionType == ActionType.openUrl) {
      return OpenUrlAction.fromYaml(payload: payload);
    } else if (actionType == ActionType.connectWallet) {
      return WalletConnectAction.fromYaml(payload: payload);
    }
    throw LanguageError("Invalid action.",
        recovery: "Make sure to use one of Ensemble-provided actions.");
  }
}
