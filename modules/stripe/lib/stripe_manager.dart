import 'package:ensemble/framework/stub/stripe_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class StripeManagerImpl extends StripeManager {
  static final StripeManagerImpl _instance = StripeManagerImpl._internal();

  StripeManagerImpl._internal();

  factory StripeManagerImpl() {
    return _instance;
  }

  @override
  Future<void> stripeInit({
    required String publishableKey,
  }) async {
    try {
      print('Hello');
      Stripe.publishableKey = publishableKey;
    } catch (e) {
      print(e);
    }
  }

  @override
  Future<void> createPaymentIntent({
    required int amount,
    required String currency,
    required String url,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'amount': amount,
          'currency': currency,
        }),
      );

      if (response.statusCode == 200) {
        final res = jsonDecode(response.body)['client_secret'];
        print(res);
      } else {}
    } catch (e) {
      print(e);
    }
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
  }) async {
    try {
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: merchantDisplayName,
          style: style,
          appearance: appearance,
          billingDetails: billingDetails,
          allowsDelayedPaymentMethods: allowsDelayedPaymentMethods,
          customFlow: customFlow ?? false,
          applePay: applePay
              ? PaymentSheetApplePay(merchantCountryCode: merchantCountryCode)
              : null,
          googlePay: googlePay
              ? PaymentSheetGooglePay(
                  merchantCountryCode: merchantCountryCode, testEnv: testEnv)
              : null,
        ),
      );

      await Stripe.instance.presentPaymentSheet();
    } catch (e) {
      print(e);
    }
  }
}
