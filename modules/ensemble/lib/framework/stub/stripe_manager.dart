import 'package:ensemble/framework/error_handling.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

abstract class StripeManager {
  Future<void> stripeInit({
    required String publishableKey,
  });

  Future<void> createPaymentIntent({
    required int amount,
    required String currency,
    required String url,
  });

  Future<void> showPaymentSheet({
    required String clientSecret,
    required String merchantDisplayName,
    required String merchantCountryCode,
    bool applePay = false,
    bool googlePay = false,
    bool testEnv = false,
    ThemeMode style = ThemeMode.system,
    PaymentSheetAppearance appearance = const PaymentSheetAppearance(),
    BillingDetails? billingDetails,
    bool? customFlow,
    bool allowsDelayedPaymentMethods = false,
  });
}

class StripeManagerStub extends StripeManager {
  @override
  Future<void> stripeInit({
    required String publishableKey,
  }) {
    throw ConfigError(
        "Stripe Manager is not enabled. Please review the Ensemble documentation.");
  }

  @override
  Future<void> createPaymentIntent({
    required int amount,
    required String currency,
    required String url,
  }) {
    throw ConfigError(
        "Stripe Manager is not enabled. Please review the Ensemble documentation.");
  }

  @override
  Future<void> showPaymentSheet({
    required String clientSecret,
    required String merchantDisplayName,
    required String merchantCountryCode,
    bool applePay = false,
    bool googlePay = false,
    bool testEnv = false,
    ThemeMode style = ThemeMode.system,
    PaymentSheetAppearance appearance = const PaymentSheetAppearance(),
    BillingDetails? billingDetails,
    bool? customFlow,
    bool allowsDelayedPaymentMethods = false,
  }) {
    throw ConfigError(
        "Stripe Manager is not enabled. Please review the Ensemble documentation.");
  }
}
