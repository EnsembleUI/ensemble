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
    this.onLinkReceived,
    this.options,
  });

  Map<String, dynamic>? options;
  EnsembleAction? onSuccess;
  EnsembleAction? onError;
  EnsembleAction? onLinkReceived;

  factory BranchLinkInitAction.fromMap({dynamic payload}) {
    if (payload is Map) {
      EnsembleAction? successAction =
          EnsembleAction.fromYaml(payload['onSuccess']);
      if (successAction == null) {
        throw LanguageError(
            'onSuccess() is required for branchLinkInit action');
      }

      return BranchLinkInitAction(
        onSuccess: successAction,
        onError: EnsembleAction.fromYaml(payload['onError']),
        onLinkReceived: EnsembleAction.fromYaml(payload['onLinkReceived']),
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
          disableTrack: disableTrack,
          onLinkReceived: (linkData) {
            return ScreenController().executeAction(context, onLinkReceived!,
                event: EnsembleEvent(initiator, data: {'link': linkData}));
          });
      return ScreenController()
          .executeAction(context, onSuccess!, event: EnsembleEvent(initiator));
    } catch (e) {
      return ScreenController().executeAction(context, onError!,
          event: EnsembleEvent(initiator,
              error: 'Branch SDK: Unable to initialize - Reason: $e'));
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
            'onSuccess() is required for branchLinkValidate action');
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
              error: 'Branch SDK: Unable to validate - Reason: $e'));
    }
  }
}

class BranchLinkCreateDeeplinkAction extends EnsembleAction {
  BranchLinkCreateDeeplinkAction({
    super.initiator,
    required this.onSuccess,
    this.onError,
    this.universalProps,
    this.linkProps,
    this.shareSheet,
  });

  EnsembleAction? onSuccess;
  EnsembleAction? onError;
  Map<String, dynamic>? universalProps;
  Map<String, dynamic>? linkProps;
  Map<String, dynamic>? shareSheet;

  factory BranchLinkCreateDeeplinkAction.fromMap({dynamic payload}) {
    if (payload is Map) {
      EnsembleAction? successAction =
          EnsembleAction.fromYaml(payload['onSuccess']);
      if (successAction == null) {
        throw LanguageError(
            'onSuccess() is required for branchLinkCreateDeepLink action');
      }

      final universalPropsData = Utils.getMap(payload['universalProps']);
      final linkPropsData = Utils.getMap(payload['linkProps']);

      if (universalPropsData == null) {
        throw LanguageError(
            'universalProps is required for branchLinkCreateDeepLink action');
      }

      if (linkPropsData == null) {
        throw LanguageError(
            'linkProps is required for branchLinkCreateDeepLink action');
      }

      return BranchLinkCreateDeeplinkAction(
        onSuccess: successAction,
        onError: EnsembleAction.fromYaml(payload['onError']),
        universalProps: universalPropsData,
        linkProps: linkPropsData,
        shareSheet: Utils.getMap(payload['shareSheet']),
      );
    }
    throw LanguageError('Missing inputs for branchLinkCreateDeepLink');
  }

  @override
  Future execute(BuildContext context, ScopeManager scopeManager) async {
    try {
      dynamic response;
      if (shareSheet != null) {
        response = await BranchLinkManager().createDeeplinkWithShareSheet(
            messageText: Utils.getString(shareSheet?['sharingTitle'],
                fallback: 'messageText'),
            messageTitle:
                Utils.getString(shareSheet?['messageTitle'], fallback: ''),
            sharingTitle:
                Utils.getString(shareSheet?['sharingTitle'], fallback: ''),
            universalProps: universalProps!,
            linkProps: linkProps!);
      } else {
        response = await BranchLinkManager()
            .createDeepLink(universalProps!, linkProps!);
      }
      if (response != null && response.success) {
        return ScreenController().executeAction(context, onSuccess!,
            event: EnsembleEvent(initiator, data: {'result': response.result}));
      } else {
        return ScreenController().executeAction(context, onError!,
            event: EnsembleEvent(initiator,
                error:
                    'Branch SDK: Unable to create deeplink - Reason: ${response?.errorMessage}'));
      }
    } catch (e) {
      return ScreenController().executeAction(context, onError!,
          event: EnsembleEvent(initiator,
              error: 'Branch SDK: Unable to create deeplink - Reason: $e'));
    }
  }
}
