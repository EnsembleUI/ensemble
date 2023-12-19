import 'package:ensemble/branch_link_manager.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/cupertino.dart';

class BranchLinkInitAction extends EnsembleAction {
  BranchLinkInitAction({
    super.initiator,
    required this.onSuccess,
    this.onError,
    this.options,
  });

  Map<String, dynamic>? options;
  EnsembleAction? onSuccess;
  EnsembleAction? onError;

  factory BranchLinkInitAction.fromMap({dynamic payload}) {
    if (payload is Map) {
      EnsembleAction? successAction =
          EnsembleAction.fromYaml(payload['onSuccess']);
      if (successAction == null) {
        throw LanguageError(
            "onSuccess() is required for branchLinkInit action");
      }

      return BranchLinkInitAction(
        onSuccess: successAction,
        onError: EnsembleAction.fromYaml(payload['onError']),
        options: Utils.getMap(payload['options']),
      );
    }
    throw LanguageError('Missing inputs for branchLinkInit');
  }

  @override
  Future execute(BuildContext context, ScopeManager scopeManager) async {
    try {
      final useTestKey = Utils.getBool(options?['useTestKey'], fallback: false);
      final enableLog = Utils.getBool(options?['enableLog'], fallback: false);
      final disableTrack =
          Utils.getBool(options?['disableTrack'], fallback: false);

      await BranchLinkManager().init(
          useTestKey: useTestKey,
          enableLog: enableLog,
          disableTrack: disableTrack);
      return ScreenController()
          .executeAction(context, onSuccess!, event: EnsembleEvent(initiator));
    } catch (e) {
      return ScreenController().executeAction(context, onError!,
          event: EnsembleEvent(initiator,
              error: 'Unable to initialize the Branch SDK: $e'));
    }
  }
}

class BranchLinkValidateAction extends EnsembleAction {
  BranchLinkValidateAction({
    super.initiator,
    required this.onSuccess,
    this.onError,
  });

  EnsembleAction? onSuccess;
  EnsembleAction? onError;

  factory BranchLinkValidateAction.fromMap({dynamic payload}) {
    if (payload is Map) {
      EnsembleAction? successAction =
          EnsembleAction.fromYaml(payload['onSuccess']);
      if (successAction == null) {
        throw LanguageError(
            "onSuccess() is required for branchLinkValidate action");
      }

      return BranchLinkValidateAction(
        onSuccess: successAction,
        onError: EnsembleAction.fromYaml(payload['onError']),
      );
    }
    throw LanguageError('Missing inputs for branchLinkValidate');
  }

  @override
  Future execute(BuildContext context, ScopeManager scopeManager) async {
    try {
      BranchLinkManager().validate();
      return ScreenController()
          .executeAction(context, onSuccess!, event: EnsembleEvent(initiator));
    } catch (e) {
      return ScreenController().executeAction(context, onError!,
          event: EnsembleEvent(initiator,
              error: 'Unable to validate the Branch SDK: $e'));
    }
  }
}

class BranchLinkCreateDeeplinkAction extends EnsembleAction {
  BranchLinkCreateDeeplinkAction({
    super.initiator,
    required this.onSuccess,
    this.onError,
  });

  EnsembleAction? onSuccess;
  EnsembleAction? onError;

  factory BranchLinkCreateDeeplinkAction.fromMap({dynamic payload}) {
    if (payload is Map) {
      EnsembleAction? successAction =
          EnsembleAction.fromYaml(payload['onSuccess']);
      if (successAction == null) {
        throw LanguageError(
            'onSuccess() is required for branchLinkCreateDeepLink action');
      }

      return BranchLinkCreateDeeplinkAction(
        onSuccess: successAction,
        onError: EnsembleAction.fromYaml(payload['onError']),
      );
    }
    throw LanguageError('Missing inputs for branchLinkCreateDeepLink');
  }

  @override
  Future execute(BuildContext context, ScopeManager scopeManager) async {
    try {
      BranchLinkManager().validate();
      return ScreenController()
          .executeAction(context, onSuccess!, event: EnsembleEvent(initiator));
    } catch (e) {
      return ScreenController().executeAction(context, onError!,
          event: EnsembleEvent(initiator,
              error: 'Unable to create deeplink using Branch SDK: $e'));
    }
  }
}
