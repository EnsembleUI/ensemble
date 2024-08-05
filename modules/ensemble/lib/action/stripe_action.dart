import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/stub/deferred_link_manager.dart';
import 'package:ensemble/framework/stub/stripe_manager.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:get_it/get_it.dart';

class StripeInitAction extends EnsembleAction {
  StripeInitAction({
    super.initiator,
    required this.publishableKey,
    this.onSuccess,
    this.onError,
  });

  String publishableKey;
  EnsembleAction? onSuccess;
  EnsembleAction? onError;

  factory StripeInitAction.fromMap({dynamic payload}) {
    if (payload is Map) {
      String? publishableKey = Utils.optionalString(payload['publishableKey']);
      if (publishableKey == null) {
        throw LanguageError('publishableKey is required for StripeInit action');
      }

      EnsembleAction? successAction = EnsembleAction.from(payload['onSuccess']);

      return StripeInitAction(
        publishableKey: publishableKey,
        onSuccess: successAction,
        onError: EnsembleAction.from(payload['onError']),
      );
    }
    throw LanguageError('StripeInit: Missing inputs for init action');
  }

  @override
  Future execute(BuildContext context, ScopeManager scopeManager) async {
    try {
      await GetIt.I<StripeManager>().stripeInit(
        publishableKey: publishableKey,
      );

      if (onSuccess != null) {
        return ScreenController().executeAction(
          context,
          onSuccess!,
          event: EnsembleEvent(initiator),
        );
      }
    } catch (e) {
      return ScreenController().executeAction(
        context,
        onError!,
        event: EnsembleEvent(
          initiator,
          error: 'StripeInit: Unable to initialize - Reason: $e',
        ),
      );
    }
  }
}

class StripeCreatePaymentIntentAction extends EnsembleAction {
  StripeCreatePaymentIntentAction({
    super.initiator,
    required this.amount,
    required this.currency,
    required this.url,
    required this.onSuccess,
    this.onError,
  });

  int amount;
  String currency;
  String url;
  EnsembleAction? onSuccess;
  EnsembleAction? onError;

  factory StripeCreatePaymentIntentAction.fromMap({dynamic payload}) {
    if (payload is Map) {
      int? amount = Utils.optionalInt(payload['amount']);
      if (amount == null) {
        throw LanguageError(
            'amount is required for createPaymentIntent action');
      }

      String? currency = Utils.optionalString(payload['currency']);
      if (currency == null) {
        throw LanguageError(
            'currency is required for createPaymentIntent action');
      }

      String? url = Utils.optionalString(payload['url']);
      if (url == null) {
        throw LanguageError('url is required for createPaymentIntent action');
      }

      EnsembleAction? successAction = EnsembleAction.from(payload['onSuccess']);
      if (successAction == null) {
        throw LanguageError(
            'onSuccess() is required for createPaymentIntent action');
      }

      return StripeCreatePaymentIntentAction(
        amount: amount,
        currency: currency,
        url: url,
        onSuccess: successAction,
        onError: EnsembleAction.from(payload['onError']),
      );
    }
    throw LanguageError('StripeCreatePaymentIntent: Missing inputs for action');
  }

  @override
  Future execute(BuildContext context, ScopeManager scopeManager) async {
    try {
      await GetIt.I<StripeManager>().createPaymentIntent(
        amount: amount,
        currency: currency,
        url: url,
      );

      if (onSuccess != null) {
        return ScreenController().executeAction(
          context,
          onSuccess!,
          event: EnsembleEvent(initiator),
        );
      }
    } catch (e) {
      if (onError != null) {
        return ScreenController().executeAction(
          context,
          onError!,
          event: EnsembleEvent(
            initiator,
            error:
                'StripeCreatePaymentIntent: Unable to create payment intent - Reason: $e',
          ),
        );
      }
    }
  }
}

class StripeShowPaymentSheetAction extends EnsembleAction {
  StripeShowPaymentSheetAction({
    super.initiator,
    required this.clientSecret,
    required this.merchantDisplayName,
    required this.merchantCountryCode,
    required this.onSuccess,
    this.onError,
    this.applePay = false,
    this.googlePay = false,
    this.testEnv = false,
    this.style = ThemeMode.system,
    this.appearance = const PaymentSheetAppearance(),
    this.billingDetails,
    this.customFlow,
    this.allowsDelayedPaymentMethods = false,
  });

  String clientSecret;
  String merchantDisplayName;
  String merchantCountryCode;
  bool applePay;
  bool googlePay;
  bool testEnv;
  ThemeMode style;
  PaymentSheetAppearance appearance;
  BillingDetails? billingDetails;
  bool? customFlow;
  bool allowsDelayedPaymentMethods;
  EnsembleAction? onSuccess;
  EnsembleAction? onError;

  factory StripeShowPaymentSheetAction.fromMap({dynamic payload}) {
    if (payload is Map) {
      String? clientSecret = Utils.optionalString(payload['clientSecret']);
      if (clientSecret == null) {
        throw LanguageError(
            'clientSecret is required for showPaymentSheet action');
      }

      String? merchantDisplayName =
          Utils.optionalString(payload['merchantDisplayName']);
      if (merchantDisplayName == null) {
        throw LanguageError(
            'merchantDisplayName is required for showPaymentSheet action');
      }

      String? merchantCountryCode =
          Utils.optionalString(payload['merchantCountryCode']);
      if (merchantCountryCode == null) {
        throw LanguageError(
            'merchantCountryCode is required for showPaymentSheet action');
      }

      EnsembleAction? successAction = EnsembleAction.from(payload['onSuccess']);
      if (successAction == null) {
        throw LanguageError(
            'onSuccess() is required for showPaymentSheet action');
      }

      return StripeShowPaymentSheetAction(
        clientSecret: clientSecret,
        merchantDisplayName: merchantDisplayName,
        merchantCountryCode: merchantCountryCode,
        onSuccess: successAction,
        onError: EnsembleAction.from(payload['onError']),
        applePay: payload['applePay'] ?? false,
        googlePay: payload['googlePay'] ?? false,
        testEnv: payload['testEnv'] ?? false,
        style: payload['style'] ?? ThemeMode.system,
        appearance: payload['appearance'] ?? const PaymentSheetAppearance(),
        billingDetails: BillingDetails(
          email: payload['email'],
          name: payload['name'],
          phone: payload['phone'],
          address: Address(
            city: payload['city'],
            country: payload['country'],
            line1: payload['line1'],
            line2: payload['line2'],
            postalCode: payload['postalCode'],
            state: payload['state'],
          ),
        ),
        customFlow: payload['customFlow'],
        allowsDelayedPaymentMethods:
            payload['allowsDelayedPaymentMethods'] ?? false,
      );
    }
    throw LanguageError('StripeShowPaymentSheet: Missing inputs for action');
  }

  @override
  Future execute(BuildContext context, ScopeManager scopeManager) async {
    try {
      await GetIt.I<StripeManager>().showPaymentSheet(
        clientSecret: clientSecret,
        merchantCountryCode: merchantCountryCode,
        merchantDisplayName: merchantDisplayName,
        allowsDelayedPaymentMethods: allowsDelayedPaymentMethods,
        appearance: appearance,
        applePay: applePay,
        billingDetails: billingDetails,
        customFlow: customFlow,
        googlePay: googlePay,
        style: style,
        testEnv: testEnv,
      );

      if (onSuccess != null) {
        return ScreenController().executeAction(
          context,
          onSuccess!,
          event: EnsembleEvent(initiator),
        );
      }
    } catch (e) {
      if (onError != null) {
        return ScreenController().executeAction(
          context,
          onError!,
          event: EnsembleEvent(
            initiator,
            error:
                'StripeShowPaymentSheet: Unable to show payment sheet - Reason: $e',
          ),
        );
      }
    }
  }
}
