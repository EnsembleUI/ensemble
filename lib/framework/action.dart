import 'package:app_settings/app_settings.dart';
import 'package:ensemble/action/audio_player.dart';
import 'package:ensemble/action/Log_event_action.dart';
import 'package:ensemble/action/badge_action.dart';
import 'package:ensemble/action/bottom_sheet_actions.dart';
import 'package:ensemble/action/deep_link_action.dart';
import 'package:ensemble/action/call_external_method.dart';
import 'package:ensemble/action/haptic_action.dart';
import 'package:ensemble/action/call_native_method.dart';
import 'package:ensemble/action/invoke_api_action.dart';
import 'package:ensemble/action/biometric_auth_action.dart';
import 'package:ensemble/action/misc_action.dart';
import 'package:ensemble/action/navigation_action.dart';
import 'package:ensemble/action/notification_action.dart';
import 'package:ensemble/action/phone_contact_action.dart';
import 'package:ensemble/action/sign_in_out_action.dart';
import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/keychain_manager.dart';
import 'package:ensemble/framework/permissions_manager.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/view/page_group.dart';
import 'package:ensemble/framework/widget/toast.dart';
import 'package:ensemble/framework/widget/view_util.dart';
import 'package:ensemble/receive_intent_manager.dart';
import 'package:ensemble/screen_controller.dart';
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
    required this.body,
    this.options,
    this.onDialogDismiss,
  });

  final dynamic body;
  final Map<String, dynamic>? options;
  final EnsembleAction? onDialogDismiss;

  factory ShowDialogAction.from({Invokable? initiator, Map? payload}) {
    if (payload == null ||
        (payload['body'] == null && payload['widget'] == null)) {
      throw LanguageError(
          "${ActionType.showDialog.name} requires the 'widget' for the Dialog's content.");
    }
    return ShowDialogAction(
      initiator: initiator,
      body: Utils.maybeYamlMap(payload['body']) ??
          Utils.maybeYamlMap(payload['widget']),
      options: Utils.getMap(payload['options']),
      onDialogDismiss: payload['onDialogDismiss'] == null
          ? null
          : EnsembleAction.fromYaml(
              Utils.maybeYamlMap(payload['onDialogDismiss'])),
    );
  }
}

class NavigateScreenAction extends BaseNavigateScreenAction {
  NavigateScreenAction(
      {super.initiator,
      required super.screenName,
      super.payload,
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
      payload:
          Utils.getMap(payload['payload']) ?? Utils.getMap(payload['inputs']),
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

class NavigateViewGroupAction extends EnsembleAction {
  NavigateViewGroupAction(this.data);

  final Map? data;

  @override
  Future execute(BuildContext context, ScopeManager scopeManager,
      {DataContext? dataContext}) {
    String? screenName =
        Utils.optionalString(eval(data?["name"], scopeManager));
    int? viewIndex = Utils.optionalInt(eval(data?["viewIndex"], scopeManager));
    if (screenName == null && viewIndex == null) {
      throw LanguageError(
          "${ActionType.navigateViewGroup} requires either 'name' or 'viewIndex'.");
    }

    Map<String, dynamic>? payload = Utils.getMap(data?["payload"]);

    if (screenName != null) {
      if (viewIndex != null) {
        (payload ??= {})["viewIndex"] = viewIndex;
      }
      ScreenController()
          .navigateToScreen(context, screenName: screenName, pageArgs: payload);
    } else if (viewIndex != null) {
      if (payload != null) {
        // TODO: this is wrong. Can't mutate the scope like this
        scopeManager.dataContext.addDataContext(payload);
      }
      // TODO: refactor the below. Both are needed when reloadView=false, but only
      //  viewGroupNotifier is needed without. Doesn't make any sense
      PageGroupWidget.getPageController(context)?.jumpToPage(viewIndex);
      viewGroupNotifier.updatePage(viewIndex, payload: payload);
    }
    return Future.value(null);
  }
}

class NavigateModalScreenAction extends BaseNavigateScreenAction {
  NavigateModalScreenAction({
    super.initiator,
    required super.screenName,
    super.payload,
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
        payload:
            Utils.getMap(payload['payload']) ?? Utils.getMap(payload['inputs']),
        onModalDismiss: EnsembleAction.fromYaml(payload['onModalDismiss']));
  }
}

abstract class BaseNavigateScreenAction extends EnsembleAction {
  BaseNavigateScreenAction(
      {super.initiator,
      required this.screenName,
      required this.asModal,
      this.transition,
      this.payload,
      this.options,
      this.isExternal = false});

  String screenName;
  bool asModal;
  Map<String, dynamic>? transition;
  final Map<String, dynamic>? options;
  final bool isExternal;
  Map<String, dynamic>? payload;
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

class ReceiveIntentAction extends EnsembleAction {
  ReceiveIntentAction({
    Invokable? initiator,
    this.options,
    this.id,
    this.onReceive,
    this.onError,
  }) : super(initiator: initiator);
  final Map<String, dynamic>? options;
  String? id;
  EnsembleAction? onReceive;
  EnsembleAction? onError;

  EnsembleAction? getOnReceive(DataContext dataContext) =>
      dataContext.eval(onReceive);

  EnsembleAction? getOnError(DataContext dataContext) =>
      dataContext.eval(onError);

  factory ReceiveIntentAction.fromYaml({Invokable? initiator, Map? payload}) {
    return ReceiveIntentAction(
      initiator: initiator,
      options: Utils.getMap(payload?['options']),
      id: Utils.optionalString(payload?['id']),
      onReceive: EnsembleAction.fromYaml(payload?['onReceive']),
      onError: EnsembleAction.fromYaml(payload?['onError']),
    );
  }

  @override
  Future execute(BuildContext context, ScopeManager scopeManager) {
    ReceiveIntentManager().init(
        context,
        initiator,
        getOnReceive(scopeManager.dataContext),
        getOnError(scopeManager.dataContext));
    return Future.value(null);
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

class ExecuteActionGroupAction extends EnsembleAction {
  ExecuteActionGroupAction({super.initiator, required this.actions});

  List<EnsembleAction> actions;

  factory ExecuteActionGroupAction.fromYaml(
      {Invokable? initiator, Map? payload}) {
    if (payload == null || payload['actions'] == null) {
      throw LanguageError(
          "${ActionType.executeActionGroup.name} requires a 'actions' list.");
    }

    if (payload['actions'] is! List<dynamic>) {
      throw LanguageError(
          "${ActionType.executeActionGroup.name} requires a 'actions' list.");
    }
    List<dynamic> actions = payload['actions'] as List<dynamic>;
    if (actions == null || actions.isEmpty) {
      throw LanguageError(
          "${ActionType.executeActionGroup.name} requires a 'actions' list.");
    }
    List<EnsembleAction> ensembleActions = [];
    for (var action in actions) {
      EnsembleAction? ensembleAction =
          EnsembleAction.fromYaml(action, initiator: initiator);
      if (ensembleAction == null) {
        throw LanguageError(
            "$action under ${ActionType.executeActionGroup.name} is not a valid action");
      }
      if (ensembleAction != null) {
        ensembleActions.add(ensembleAction);
      }
    }
    return ExecuteActionGroupAction(
        initiator: initiator, actions: ensembleActions);
  }

  factory ExecuteActionGroupAction.from(dynamic payload) =>
      ExecuteActionGroupAction.fromYaml(payload: Utils.getYamlMap(payload));

  @override
  Future<void> execute(BuildContext context, ScopeManager scopeManager) {
    // Map each action into a Future by calling execute on it, starting all actions in parallel
    var actionFutures = actions.map((action) {
      return ScreenController()
          .executeActionWithScope(context, scopeManager, action);
    });

    // Wait for all action Futures to complete and return the resulting Future
    return Future.wait(actionFutures);
  }
}

class ExecuteConditionalActionAction extends EnsembleAction {
  List<dynamic> conditions;

  ExecuteConditionalActionAction({super.initiator, required this.conditions});

  factory ExecuteConditionalActionAction.fromYaml(
      {Invokable? initiator, Map? payload}) {
    if (payload == null || payload['conditions'] == null) {
      throw LanguageError(
          "${ActionType.executeConditionalAction.name} requires a 'conditions' list.");
    }
    if (payload['conditions'] is! List<dynamic>) {
      throw LanguageError(
          "${ActionType.executeConditionalAction.name} requires a 'conditions' list.");
    }
    List<dynamic> conditions = payload['conditions'] as List<dynamic>;
    if (conditions == null || conditions.isEmpty) {
      throw LanguageError(
          "${ActionType.executeConditionalAction.name} requires a 'conditions' list.");
    }
    if (conditions.first.containsKey('if') == false) {
      throw LanguageError(
          "${ActionType.executeConditionalAction.name} requires a 'conditions' list with the first condition being an 'if' condition.");
    }
    // Iterate over the conditions list starting from the second element
    for (int i = 1; i < conditions.length; i++) {
      if (conditions[i] is Map && conditions[i].containsKey('if')) {
        throw LanguageError(
            "${ActionType.executeConditionalAction.name} requires that only the first condition contains an 'if' key. Found another 'if' at position $i.");
      }
    }
    return ExecuteConditionalActionAction(
        initiator: initiator, conditions: conditions);
  }

  factory ExecuteConditionalActionAction.from(dynamic payload) =>
      ExecuteConditionalActionAction.fromYaml(
          payload: Utils.getYamlMap(payload));

  Future<dynamic> _execute(
      Map actionMap, BuildContext context, ScopeManager scopeManager) async {
    EnsembleAction? action = EnsembleAction.fromYaml(YamlMap.wrap(actionMap));
    if (action == null) {
      throw LanguageError(
          "${ActionType.executeConditionalAction.name} requires a valid action.");
    }
    return ScreenController()
        .executeActionWithScope(context, scopeManager, action);
  }

  @override
  Future<dynamic> execute(
      BuildContext context, ScopeManager scopeManager) async {
    for (var condition in conditions) {
      String? conditionType;
      var result = true; // Default to true for 'else'

      if (condition.containsKey('if')) {
        conditionType = 'if';
        result = scopeManager.dataContext.eval(condition['if']);
      } else if (condition.containsKey('elseif')) {
        conditionType = 'elseif';
        result = scopeManager.dataContext.eval(condition['elseif']);
      } else if (condition.containsKey('else')) {
        conditionType = 'else';
      } else {
        throw LanguageError(
            "${ActionType.executeConditionalAction.name} requires a valid condition.");
      }

      if (result) {
        Map? actionMap = condition['action'];
        if (actionMap == null) {
          throw LanguageError(
              "${ActionType.executeConditionalAction.name} $conditionType condition requires a valid action.");
        }
        return _execute(actionMap, context, scopeManager);
      }
    }
    return Future.value(
        null); // No conditions met or all conditions evaluated to false.
  }
}

//used to dispatch events. Used within custom widgets as custom widgets expose events to the callers
class DispatchEventAction extends EnsembleAction {
  DispatchEventAction({super.initiator, required this.event, this.onComplete});

  EnsembleEvent event;
  EnsembleAction? onComplete;

  factory DispatchEventAction.fromYaml({Invokable? initiator, Map? payload}) {
    if (payload == null || payload.keys.length != 1) {
      throw LanguageError(
          "${ActionType.dispatchEvent.name} requires one and only one 'event' to dispatch.");
    }
    YamlMap? data;
    if (payload.values.first != null) {
      data = payload.values.first as YamlMap;
    }
    return DispatchEventAction(
        initiator: initiator,
        event: EnsembleEvent.fromYaml(payload.keys.first, data),
        onComplete: EnsembleAction.fromYaml(payload['onComplete']));
  }

  factory DispatchEventAction.from(dynamic payLoad) {
    return DispatchEventAction.fromYaml(payload: Utils.getYamlMap(payLoad));
  }

  @override
  Future<dynamic> execute(BuildContext context, ScopeManager scopeManager) {
    //we can safely do event.name! as we are always settings it
    //we are not going to check if the returned type is a handler or not as that should have been done before
    EnsembleEventHandler? handler =
        scopeManager.dataContext.getContextById(event.name!);
    if (handler != null) {
      Map? evaluatedData = event.data?.map(
          (key, value) => MapEntry(key, scopeManager.dataContext.eval(value)));

      return handler.handleEvent(
          EnsembleEvent(event.source,
              data: evaluatedData, error: event.error, name: event.name),
          context);
    }
    return Future.value(null);
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
        openInExternalApp: Utils.optionalBool(payload['external']) ??
            Utils.optionalBool(payload['openInExternalApp']) ??
            false);
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
        message: payload['message']?.toString(),
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

enum FileSource { gallery, files }

class FilePickerAction extends EnsembleAction {
  FilePickerAction({
    required this.id,
    this.allowedExtensions,
    this.allowMultiple,
    this.allowCompression,
    this.onComplete,
    this.onError,
    this.source,
  });

  String id;
  List<String>? allowedExtensions;
  bool? allowMultiple;
  bool? allowCompression;
  EnsembleAction? onComplete;
  EnsembleAction? onError;
  FileSource? source;

  factory FilePickerAction.fromYaml({Map? payload}) {
    if (payload == null || payload['id'] == null) {
      throw LanguageError("${ActionType.pickFiles.name} requires 'id'.");
    }

    FileSource? getSource(String? source) {
      if (source == 'gallery') {
        return FileSource.gallery;
      }
      if (source == 'files') {
        return FileSource.files;
      }
      return null;
    }

    return FilePickerAction(
      id: Utils.getString(payload['id'], fallback: ''),
      allowedExtensions:
          (payload['allowedExtensions'] as YamlList?)?.cast<String>().toList(),
      allowMultiple: Utils.optionalBool(payload['allowMultiple']),
      allowCompression: Utils.optionalBool(payload['allowCompression']),
      onComplete: EnsembleAction.fromYaml(payload['onComplete']),
      onError: EnsembleAction.fromYaml(payload['onError']),
      source: getSource(payload['source']),
    );
  }
}

class FileUploadAction extends EnsembleAction {
  FileUploadAction({
    super.inputs,
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
    this.batchSize,
  });

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
  int? batchSize;

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
      batchSize: Utils.optionalInt(payload['options']?['batchSize']),
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
  Map? payload;

  ShowNotificationAction({this.title = '', this.body = '', this.payload});

  factory ShowNotificationAction.fromYaml({Map? payload}) {
    return ShowNotificationAction(
      title: Utils.getString(payload?['title'], fallback: ''),
      body: Utils.getString(payload?['body'], fallback: ''),
      payload: Utils.getMap(payload?['payload']),
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
    super.inputs,
  });

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

class SaveKeychain extends EnsembleAction {
  SaveKeychain({
    required this.key,
    this.value,
    this.onComplete,
    this.onError,
  });

  final String key;
  final dynamic value;
  final EnsembleAction? onComplete;
  final EnsembleAction? onError;

  factory SaveKeychain.fromYaml({Map? payload}) {
    if (payload == null || payload['key'] == null) {
      throw ConfigError('${ActionType.saveKeychain} requires a key.');
    }
    return SaveKeychain(
      key: payload['key'],
      value: payload['value'],
      onComplete: EnsembleAction.fromYaml(payload['onComplete']),
      onError: EnsembleAction.fromYaml(payload['onError']),
    );
  }

  @override
  Future execute(BuildContext context, ScopeManager scopeManager,
      {DataContext? dataContext}) async {
    String? storageKey =
        Utils.optionalString(scopeManager.dataContext.eval(key));
    String? errorReason;

    if (storageKey != null) {
      try {
        final datas = {'key': key, 'value': value};
        await KeychainManager().saveToKeychain(datas);
        // dispatch onComplete
        if (onComplete != null) {
          ScreenController().executeAction(context, onComplete!);
        }
      } catch (e) {
        errorReason = e.toString();
      }
    } else {
      errorReason = '${ActionType.saveKeychain} requires a key.';
    }

    if (onError != null && errorReason != null) {
      ScreenController().executeAction(context, onError!,
          event: EnsembleEvent(null, error: errorReason));
    }
    return Future.value(null);
  }
}

class ClearKeychain extends EnsembleAction {
  ClearKeychain({
    required this.key,
    this.onComplete,
    this.onError,
  });

  final String key;
  final EnsembleAction? onComplete;
  final EnsembleAction? onError;

  factory ClearKeychain.fromYaml({Map? payload}) {
    if (payload == null || payload['key'] == null) {
      throw ConfigError('${ActionType.clearKeychain} requires a key.');
    }
    return ClearKeychain(
      key: payload['key'],
      onComplete: EnsembleAction.fromYaml(payload['onComplete']),
      onError: EnsembleAction.fromYaml(payload['onError']),
    );
  }

  @override
  Future execute(BuildContext context, ScopeManager scopeManager,
      {DataContext? dataContext}) async {
    String? storageKey =
        Utils.optionalString(scopeManager.dataContext.eval(key));
    String? errorReason;

    if (storageKey != null) {
      try {
        final datas = {'key': key};
        await KeychainManager().clearKeychain(datas);
        // dispatch onComplete
        if (onComplete != null) {
          ScreenController().executeAction(context, onComplete!);
        }
      } catch (e) {
        errorReason = e.toString();
      }
    } else {
      errorReason = '${ActionType.clearKeychain} requires a key.';
    }

    if (onError != null && errorReason != null) {
      ScreenController().executeAction(context, onError!,
          event: EnsembleEvent(null, error: errorReason));
    }
    return Future.value(null);
  }
}

enum ActionType {
  invokeAPI,
  navigateScreen,
  navigateViewGroup,
  navigateExternalScreen,
  navigateModalScreen,
  showBottomSheet,
  dismissBottomSheet,
  @Deprecated("use showBottomSheet")
  showBottomModal,
  @Deprecated("use dismissBottomSheet")
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
  getPhoneContactPhoto,
  checkPermission,
  saveKeychain,
  clearKeychain,
  getDeviceToken,
  receiveIntent,
  connectSocket,
  disconnectSocket,
  messageSocket,
  updateBadgeCount,
  clearBadgeCount,
  callExternalMethod,
  invokeHaptic,
  callNativeMethod,
  deeplinkInit,
  authenticateByBiometric,
  handleDeeplink,
  createDeeplink,
  verifySignIn,
  signOut,
  dispatchEvent,
  executeConditionalAction,
  executeActionGroup,
  playAudio,
  stopAudio,
  pauseAudio,
  resumeAudio,
  seekAudio,
  logEvent
}

enum ToastType { success, error, warning, info }

/// payload representing an Action to do (navigateToScreen, InvokeAPI, ..)
abstract class EnsembleAction {
  EnsembleAction({this.initiator, this.inputs});

  // initiator is an Invokable so we can scope to *this* variable
  Invokable? initiator;
  Map? inputs;

  // evaluate the data based on the given scope
  dynamic eval(dynamic data, ScopeManager scopeManager) =>
      scopeManager.dataContext.eval(data);

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
    } else if (actionType == ActionType.navigateViewGroup) {
      return NavigateViewGroupAction(payload);
    } else if (actionType == ActionType.navigateModalScreen) {
      return NavigateModalScreenAction.fromYaml(
          initiator: initiator, payload: payload);
    } else if (actionType == ActionType.navigateBack) {
      return NavigateBackAction.from(payload: payload);
    } else if (actionType == ActionType.showBottomSheet ||
        actionType == ActionType.showBottomModal) {
      return ShowBottomSheetAction.from(payload: payload);
    } else if (actionType == ActionType.dismissBottomSheet ||
        actionType == ActionType.dismissBottomModal) {
      return DismissBottomSheetAction.from(payload: payload);
    } else if (actionType == ActionType.invokeAPI) {
      return InvokeAPIAction.fromYaml(initiator: initiator, payload: payload);
    } else if (actionType == ActionType.openCamera) {
      return ShowCameraAction.fromYaml(initiator: initiator, payload: payload);
    } else if (actionType == ActionType.showDialog) {
      return ShowDialogAction.from(initiator: initiator, payload: payload);
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
      return GetPhoneContactAction.fromMap(
          initiator: initiator, payload: payload);
    } else if (actionType == ActionType.getPhoneContactPhoto) {
      return GetPhoneContactPhotoAction.fromMap(
          initiator: initiator, payload: payload);
    } else if (actionType == ActionType.checkPermission) {
      return CheckPermission.fromYaml(payload: payload);
    } else if (actionType == ActionType.receiveIntent) {
      return ReceiveIntentAction.fromYaml(
          initiator: initiator, payload: payload);
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
    } else if (actionType == ActionType.callNativeMethod) {
      return CallNativeMethod.from(payload: payload);
    } else if (actionType == ActionType.saveKeychain) {
      return SaveKeychain.fromYaml(payload: payload);
    } else if (actionType == ActionType.clearKeychain) {
      return ClearKeychain.fromYaml(payload: payload);
    } else if (actionType == ActionType.invokeHaptic) {
      return HapticAction.from(payload);
    } else if (actionType == ActionType.playAudio) {
      return PlayAudio.from(payload);
    } else if (actionType == ActionType.pauseAudio) {
      return PauseAudio.from(payload);
    } else if (actionType == ActionType.stopAudio) {
      return PauseAudio.from(payload);
    } else if (actionType == ActionType.resumeAudio) {
      return ResumeAudio.from(payload);
    } else if (actionType == ActionType.seekAudio) {
      return SeekAudio.from(payload);
    } else if (actionType == ActionType.deeplinkInit) {
      return DeepLinkInitAction.fromMap(payload: payload);
    } else if (actionType == ActionType.authenticateByBiometric) {
      return AuthenticateByBiometric.fromMap(payload: payload);
    } else if (actionType == ActionType.handleDeeplink) {
      return DeepLinkHandleAction.fromMap(payload: payload);
    } else if (actionType == ActionType.createDeeplink) {
      return CreateDeeplinkAction.fromMap(payload: payload);
    } else if (actionType == ActionType.verifySignIn) {
      return VerifySignInAction(
          initiator: initiator,
          onSignedIn: EnsembleAction.fromYaml(payload?['onSignedIn']),
          onNotSignedIn: EnsembleAction.fromYaml(payload?['onNotSignedIn']));
    } else if (actionType == ActionType.signOut) {
      return SignOutAction(
          initiator: initiator,
          onComplete: EnsembleAction.fromYaml(payload?['onComplete']));
    } else if (actionType == ActionType.dispatchEvent) {
      return DispatchEventAction.fromYaml(
          initiator: initiator, payload: payload);
    } else if (actionType == ActionType.executeConditionalAction) {
      return ExecuteConditionalActionAction.fromYaml(
          initiator: initiator, payload: payload);
    } else if (actionType == ActionType.executeActionGroup) {
      return ExecuteActionGroupAction.fromYaml(
          initiator: initiator, payload: payload);
    } else if (actionType == ActionType.logEvent) {
      return LogEvent.from(initiator: initiator, payload: payload);
    }

    throw LanguageError("Invalid action.",
        recovery: "Make sure to use one of Ensemble-provided actions.");
  }
}
