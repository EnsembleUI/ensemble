


import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:source_span/source_span.dart';
import 'package:yaml/yaml.dart';

/// payload representing an Action to do (navigateToScreen, InvokeAPI, ..)
abstract class EnsembleAction {
  EnsembleAction({this.initiator,this.inputs});
  Map<String, dynamic>? inputs;
  // initiator is an Invokable so we can scope to *this* variable
  Invokable? initiator;
}

class InvokeAPIAction extends EnsembleAction {
  InvokeAPIAction({
    Invokable? initiator,
    Map<String, dynamic>? inputs,
    required this.apiName,
    this.id,
    this.onResponse,
    this.onError
  }) : super(initiator: initiator, inputs: inputs);

  String? id;
  final String apiName;
  EnsembleAction? onResponse;
  EnsembleAction? onError;
}

class ShowCameraAction extends EnsembleAction{
  ShowCameraAction({
    Invokable? initiator,
    this.options,
    this.id,
    this.onComplete,
  }) : super(initiator: initiator);
  final Map<String , dynamic>? options;
  String? id;
  EnsembleAction? onComplete;
}

class ShowDialogAction extends EnsembleAction {
  ShowDialogAction({
    Invokable? initiator,
    required this.content,
    this.options,
    this.onDialogDismiss,
    Map<String, dynamic>? inputs
  }) : super(initiator: initiator, inputs: inputs);

  final dynamic content;
  final Map<String, dynamic>? options;
  final EnsembleAction? onDialogDismiss;
}

class NavigateScreenAction extends BaseNavigateScreenAction {
  NavigateScreenAction({
    Invokable? initiator,
    required String screenName,
    Map<String, dynamic>? inputs
  }) : super(initiator: initiator, screenName: screenName, asModal: false, inputs: inputs);
}

class NavigateModalScreenAction extends BaseNavigateScreenAction {
  NavigateModalScreenAction({
    Invokable? initiator,
    required String screenName,
    Map<String, dynamic>? inputs,
    this.onModalDismiss,
  }) : super(initiator: initiator, screenName: screenName, asModal: true, inputs: inputs);

  EnsembleAction? onModalDismiss;

}

abstract class BaseNavigateScreenAction extends EnsembleAction {
  BaseNavigateScreenAction({
    Invokable? initiator,
    required this.screenName,
    required this.asModal,
    Map<String, dynamic>? inputs
  }) : super(initiator: initiator,inputs: inputs);

  String screenName;
  bool asModal;
}

class StartTimerAction extends EnsembleAction {
  StartTimerAction({
    Invokable? initiator,
    required this.onTimer,
    this.onTimerComplete,
    this.payload
  }) : super(initiator: initiator);

  final EnsembleAction onTimer;
  final EnsembleAction? onTimerComplete;
  final TimerPayload? payload;
}

class StopTimerAction extends EnsembleAction {
  StopTimerAction(this.id);
  String id;
}

class CloseAllDialogsAction extends EnsembleAction {

}

class ExecuteCodeAction extends EnsembleAction {
  ExecuteCodeAction({
    Invokable? initiator,
    Map<String, dynamic>? inputs,
    required this.codeBlock,
    this.onComplete,
    required this.codeBlockSpan
  }) : super(initiator: initiator,inputs: inputs);

  String codeBlock;
  EnsembleAction? onComplete;
  SourceSpan codeBlockSpan;
}
class OpenUrlAction extends EnsembleAction {
  String url;
  bool openInExternalApp;
  OpenUrlAction(this.url, {this.openInExternalApp=false});
}
class NavigateBack extends EnsembleAction {
}
class ShowToastAction extends EnsembleAction {
  ShowToastAction({
    Invokable? initiator,
    required this.type,
    this.message,
    this.body,
    this.dismissible,
    this.position,
    this.duration,
    this.styles
  }) : super(initiator: initiator);

  final ToastType type;

  // either message or body is needed
  final String? message;
  final dynamic body;

  final bool? dismissible;
  final String? position;
  final int? duration;    // the during in seconds before toast is dismissed
  final Map<String, dynamic>? styles;
}

class GetLocationAction extends EnsembleAction {
  GetLocationAction({
    this.onLocationReceived,
    this.onError,
    this.recurring,
    this.recurringDistanceFilter
  });
  EnsembleAction? onLocationReceived;
  EnsembleAction? onError;

  bool? recurring;
  int? recurringDistanceFilter;
}

class TimerPayload {
  TimerPayload({
    this.id,
    this.startAfter,
    required this.repeat,
    this.repeatInterval,
    this.maxTimes,
    this.isGlobal
  });

  final String? id;
  final int? startAfter;  // The initial delay in seconds

  final bool repeat;
  final int? repeatInterval;  // The repeat interval in seconds
  final int? maxTimes;         // how many times to trigger onTimer

  final bool? isGlobal;        // if global is marked, only 1 instance is available for the entire app
}

class FileUploadAction extends EnsembleAction {
  FileUploadAction({
    this.allowedExtensions, 
    this.allowMultiple, 
    this.allowCompression,
    this.id,
    this.onComplete,
    this.onError,
    this.uploadUrl,
  });

  List<String>? allowedExtensions;
  bool? allowMultiple;
  bool? allowCompression;
  String? id;
  EnsembleAction? onComplete;
  EnsembleAction? onError;
  String? uploadUrl;
}


enum ActionType { invokeAPI, navigateScreen, navigateModalScreen, showDialog, startTimer, stopTimer, closeAllDialogs, executeCode, showToast, getLocation, openUrl, openCamera, uploadFiles, navigateBack }

enum ToastType { success, error, warning, info, custom }
