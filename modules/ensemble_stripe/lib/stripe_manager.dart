import 'dart:async';
import 'package:ensemble/framework/stub/stripe_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

/// Real implementation of StripeManager for the ensemble_stripe module
class StripeManagerImpl implements StripeManager {
  bool _isInitialized = false;

  @override
  Future<void> initializeStripe({
    String? publishableKey,
    String? stripeAccountId,
    String? merchantIdentifier,
  }) async {
    if (_isInitialized) {
      print('Stripe is already initialized');
      return;
    }

    try {
      if (publishableKey == null || publishableKey.isEmpty) {
        throw Exception('Stripe publishableKey is required');
      }

      // Initialize Stripe
      Stripe.publishableKey = publishableKey;

      if (stripeAccountId != null && stripeAccountId.isNotEmpty) {
        Stripe.stripeAccountId = stripeAccountId;
      }

      if (merchantIdentifier != null && merchantIdentifier.isNotEmpty) {
        Stripe.merchantIdentifier = merchantIdentifier;
      }

      _isInitialized = true;
      print('Stripe initialized successfully');
    } catch (e) {
      throw Exception('Failed to initialize Stripe: $e');
    }
  }

  @override
  Future<void> showPaymentSheet({
    required String clientSecret,
    Map<String, dynamic>? configuration,
  }) async {
    try {
      // Parse theme mode from configuration
      ThemeMode themeMode = ThemeMode.system;
      if (configuration?['style'] != null) {
        final style = configuration!['style'].toString().toLowerCase();
        switch (style) {
          case 'light':
            themeMode = ThemeMode.light;
            break;
          case 'dark':
            themeMode = ThemeMode.dark;
            break;
          default:
            themeMode = ThemeMode.system;
        }
      }

      // Parse billing details safely
      BillingDetails? billingDetails;
      if (configuration?['billingDetails'] != null) {
        try {
          billingDetails = BillingDetails.fromJson(
            Map<String, dynamic>.from(configuration!['billingDetails']),
          );
        } catch (e) {
          print('Stripe: Failed to parse billing details: $e');
          // Continue without billing details
        }
      }

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          // Main params
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: configuration?['merchantDisplayName'],
          preferredNetworks: configuration?['preferredNetworks'] != null
              ? (configuration?['preferredNetworks'] as List<dynamic>)
                  .map((network) =>
                      CardBrand.values.firstWhere((e) => e.name == network))
                  .toList()
              : null,
          // Customer params
          customerId: configuration?['customerId'],
          customerEphemeralKeySecret:
              configuration?['customerEphemeralKeySecret'],
          returnURL: configuration?['returnURL'],
          // Extra params
          primaryButtonLabel: configuration?['primaryButtonLabel'],
          applePay: configuration?['applePay'] != null
              ? PaymentSheetApplePay(
                  merchantCountryCode: configuration?['applePay']
                      ['merchantCountryCode'] as String,
                )
              : null,
          googlePay: configuration?['googlePay'] != null
              ? PaymentSheetGooglePay(
                  merchantCountryCode: configuration?['googlePay']
                      ['merchantCountryCode'] as String,
                  testEnv: configuration?['googlePay']?['testEnv'] ?? false,
                )
              : null,
          style: themeMode,
          billingDetails: billingDetails,
        ),
      );
      await Stripe.instance.presentPaymentSheet();
    } catch (e) {
      print('Stripe: Error showing payment sheet: $e');
      throw Exception('Failed to show payment sheet: $e');
    }
  }
}
