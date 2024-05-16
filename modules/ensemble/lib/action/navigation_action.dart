import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/host_platform_manager.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';

/// Navigate to a screen outside of Ensemble (i.e. Flutter, iOS or Android screen)
class NavigateExternalScreen extends BaseNavigateScreenAction {
  NavigateExternalScreen(
      {super.initiator,
      required super.screenName,
      super.payload,
      super.options})
      : super(asModal: false, isExternal: false);

  factory NavigateExternalScreen.from({Invokable? initiator, Map? payload}) {
    if (payload?['name'] == null) {
      throw LanguageError(
          "${ActionType.navigateExternalScreen.name} requires a 'name' of the screen");
    }
    return NavigateExternalScreen(
        initiator: initiator,
        screenName: payload!['name'].toString(),
        payload:
            Utils.getMap(payload['payload']) ?? Utils.getMap(payload['inputs']),
        options: Utils.getMap(payload['options']));
  }

  @override
  Future<dynamic> execute(BuildContext context, ScopeManager scopeManager) {
    Map? evaluatedPayload = payload?.map(
        (key, value) => MapEntry(key, scopeManager.dataContext.eval(value)));

    Map? evaluatedOptions = options?.map(
        (key, value) => MapEntry(key, scopeManager.dataContext.eval(value)));

    return HostPlatformManager().navigateExternalScreen({
      'name': scopeManager.dataContext.eval(screenName),
      'inputs': evaluatedPayload,
      'options': evaluatedOptions
    });
  }
}

/// pop the current screen, but we abstract it as a navigate back
class NavigateBackAction extends EnsembleAction {
  NavigateBackAction({this.payload});

  Map? payload;

  factory NavigateBackAction.from({Map? payload}) =>
      NavigateBackAction(payload: payload?['payload'] ?? payload?['data']);

  @override
  Future<dynamic> execute(BuildContext context, ScopeManager scopeManager) {
    return Navigator.of(context)
        .maybePop(scopeManager.dataContext.eval(payload));
  }
}
