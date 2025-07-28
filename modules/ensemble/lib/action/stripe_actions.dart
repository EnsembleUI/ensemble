import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/stub/stripe_manager.dart';
import 'package:get_it/get_it.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';

/// Show Stripe payment sheet
class ShowPaymentSheetAction extends EnsembleAction {
  ShowPaymentSheetAction({
    super.initiator,
    required this.clientSecret,
    this.configuration,
    this.onComplete,
    this.onError,
  });

  final String clientSecret;
  final Map<String, dynamic>? configuration;
  final EnsembleAction? onComplete;
  final EnsembleAction? onError;

  factory ShowPaymentSheetAction.fromYaml(
      {Invokable? initiator, Map? payload}) {
    if (payload == null || payload['clientSecret'] == null) {
      throw LanguageError(
          "showPaymentSheet requires a 'clientSecret' parameter.");
    }

    return ShowPaymentSheetAction(
      initiator: initiator,
      clientSecret: Utils.getString(payload['clientSecret'], fallback: ''),
      configuration: Utils.getMap(payload['configuration']),
      onComplete: EnsembleAction.from(payload['onComplete']),
      onError: EnsembleAction.from(payload['onError']),
    );
  }

  @override
  Future<void> execute(BuildContext context, ScopeManager scopeManager) async {
    try {
      final stripeManager = GetIt.I<StripeManager>();
      await stripeManager.showPaymentSheet(
        clientSecret: scopeManager.dataContext.eval(clientSecret),
        configuration: scopeManager.dataContext.eval(configuration),
      );

      if (onComplete != null) {
        await ScreenController().executeAction(context, onComplete!);
      }
    } catch (e) {
      if (onError != null) {
        await ScreenController().executeAction(
          context,
          onError!,
          event: EnsembleEvent(initiator, error: e.toString()),
        );
      }
    }
  }
}
