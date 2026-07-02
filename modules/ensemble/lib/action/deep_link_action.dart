import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/stub/deferred_link_manager.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:get_it/get_it.dart';

/// Ensemble action that initializes a deep-link provider and listeners.
class DeepLinkInitAction extends EnsembleAction {
  /// Creates a [DeepLinkInitAction] action.
  DeepLinkInitAction({
    super.initiator,
    required this.provider,
    required this.onSuccess,
    this.onError,
    this.onLinkReceived,
    this.options,
  });

  /// Provider selected by the YAML payload.
  DeepLinkProvider provider;
  /// Provider-specific options passed through from the action payload.
  Map<String, dynamic>? options;
  /// Action executed when the operation succeeds.
  EnsembleAction? onSuccess;
  /// Action executed when the operation fails.
  EnsembleAction? onError;
  /// Action executed when a deep link is received.
  EnsembleAction? onLinkReceived;

  /// Creates a [DeepLinkInitAction] from a YAML or map action payload.
  factory DeepLinkInitAction.fromMap({dynamic payload}) {
    if (payload is Map) {
      DeepLinkProvider? provider = DeepLinkProvider.values
          .from(Utils.optionalString(payload['provider']));
      if (provider == null) {
        throw LanguageError('provider is required for initDeepLink action');
      }

      EnsembleAction? successAction = EnsembleAction.from(payload['onSuccess']);
      if (successAction == null) {
        throw LanguageError('onSuccess() is required for initDeepLink action');
      }

      return DeepLinkInitAction(
        provider: provider,
        onSuccess: successAction,
        onError: EnsembleAction.from(payload['onError']),
        onLinkReceived: EnsembleAction.from(payload['onLinkReceived']),
        options: Utils.getMap(payload['options']),
      );
    }
    throw LanguageError('DeferredDeepLink: Missing inputs for initDeepLink');
  }

  /// Runs this action and performs the deep link init operation.
  @override
  Future execute(BuildContext context, ScopeManager scopeManager) async {
    try {
      await GetIt.I<DeferredLinkManager>().init(
          provider: provider,
          options: options,
          onLinkReceived: (linkData) {
            return ScreenController().executeAction(context, onLinkReceived!,
                event: EnsembleEvent(initiator, data: {'link': linkData}));
          });
      return ScreenController()
          .executeAction(context, onSuccess!, event: EnsembleEvent(initiator));
    } catch (e) {
      return ScreenController().executeAction(context, onError!,
          event: EnsembleEvent(initiator,
              error: 'DeferredDeepLink: Unable to initialize - Reason: $e'));
    }
  }
}

/// Ensemble action that handles an incoming deep-link URL.
class DeepLinkHandleAction extends EnsembleAction {
  /// Creates a [DeepLinkHandleAction] action.
  DeepLinkHandleAction({
    super.initiator,
    required this.url,
    required this.onLinkReceived,
    this.onError,
  });

  /// URL handled, opened, or converted into a deep link.
  String? url;
  /// Action executed when the operation succeeds.
  EnsembleAction? onSuccess;
  /// Action executed when a deep link is received.
  EnsembleAction? onLinkReceived;
  /// Action executed when the operation fails.
  EnsembleAction? onError;

  /// Creates a [DeepLinkHandleAction] from a YAML or map action payload.
  factory DeepLinkHandleAction.fromMap({dynamic payload}) {
    if (payload is Map) {
      String? url = Utils.optionalString(payload['url']);
      if (url == null) {
        throw LanguageError('url is required for handleDeepLink action');
      }

      EnsembleAction? onLinkReceivedAction =
          EnsembleAction.from(payload['onLinkReceived']);
      if (onLinkReceivedAction == null) {
        throw LanguageError(
            'onLinkReceived() is required for handleDeepLink action');
      }

      return DeepLinkHandleAction(
        url: url,
        onLinkReceived: onLinkReceivedAction,
        onError: EnsembleAction.from(payload['onError']),
      );
    }
    throw LanguageError('DeferredDeepLink: Missing inputs for handleDeepLink');
  }

  /// Runs this action and performs the deep link handle operation.
  @override
  Future execute(BuildContext context, ScopeManager scopeManager) async {
    try {
      if (url != null && onLinkReceived != null) {
        GetIt.I<DeferredLinkManager>().handleDeferredLink(url!, (linkData) {
          return ScreenController().executeAction(context, onLinkReceived!,
              event: EnsembleEvent(initiator, data: {'link': linkData}));
        });
      }
    } catch (e) {
      if (onError != null) {
        return ScreenController().executeAction(context, onError!,
            event: EnsembleEvent(initiator,
                error:
                    'DeferredDeepLink: Unable to handle deeplink - Reason: $e'));
      }
    }
  }
}

/// Ensemble action that creates a deep link with provider-specific properties.
class CreateDeeplinkAction extends EnsembleAction {
  /// Creates a [CreateDeeplinkAction] action.
  CreateDeeplinkAction({
    super.initiator,
    required this.provider,
    required this.onSuccess,
    this.onError,
    this.universalProps,
    this.linkProps,
  });

  /// Provider selected by the YAML payload.
  DeepLinkProvider provider;
  /// Action executed when the operation succeeds.
  EnsembleAction? onSuccess;
  /// Action executed when the operation fails.
  EnsembleAction? onError;
  /// Provider-agnostic deep-link properties.
  Map<String, dynamic>? universalProps;
  /// Provider-specific deep-link properties.
  Map<String, dynamic>? linkProps;

  /// Creates a [CreateDeeplinkAction] from a YAML or map action payload.
  factory CreateDeeplinkAction.fromMap({dynamic payload}) {
    if (payload is Map) {
      DeepLinkProvider? provider = DeepLinkProvider.values
          .from(Utils.optionalString(payload['provider']));
      if (provider == null) {
        throw LanguageError('provider is required for createDeepLink action');
      }

      EnsembleAction? successAction = EnsembleAction.from(payload['onSuccess']);
      if (successAction == null) {
        throw LanguageError(
            'onSuccess() is required for createDeepLink action');
      }

      return CreateDeeplinkAction(
        provider: provider,
        onSuccess: successAction,
        onError: EnsembleAction.from(payload['onError']),
        universalProps: Utils.getMap(payload['universalProps']),
        linkProps: Utils.getMap(payload['linkProps']),
      );
    }
    throw LanguageError('DeferredDeepLink: Missing inputs for createDeepLink');
  }

  /// Runs this action and performs the create deeplink operation.
  @override
  Future execute(BuildContext context, ScopeManager scopeManager) async {
    try {
      final response = await GetIt.I<DeferredLinkManager>().createDeepLink(
          provider: provider,
          universalProps: universalProps,
          linkProps: linkProps);
      if (response != null && response.success) {
        return ScreenController().executeAction(context, onSuccess!,
            event: EnsembleEvent(initiator, data: {'result': response.result}));
      } else {
        return ScreenController().executeAction(context, onError!,
            event: EnsembleEvent(initiator,
                error:
                    'DeferredDeepLink: Unable to create deeplink - Reason: ${response?.errorMessage}'));
      }
    } catch (e) {
      return ScreenController().executeAction(context, onError!,
          event: EnsembleEvent(initiator,
              error:
                  'DeferredDeepLink: Unable to create deeplink - Reason: $e'));
    }
  }
}
