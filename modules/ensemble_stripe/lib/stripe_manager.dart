import 'dart:async';
import 'package:ensemble/framework/stub/stripe_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:yaml/yaml.dart';

/// Real implementation of StripeManager for the ensemble_stripe module
class StripeManagerImpl implements StripeManager {
  bool _isInitialized = false;

  /// Auto-initialize Stripe from ensemble configuration
  Future<void> _ensureInitialized() async {
    if (_isInitialized) return;

    try {
      // Get configuration from ensemble
      final config = await _getStripeConfig();
      if (config == null || !config['enabled']) {
        throw Exception('Stripe is not enabled in configuration');
      }

      final publishableKey = config['publishableKey'] as String?;
      if (publishableKey == null || publishableKey.isEmpty) {
        throw Exception('Stripe publishableKey is required in configuration');
      }

      Stripe.publishableKey = publishableKey;

      final stripeAccountId = config['stripeAccountId'] as String?;
      if (stripeAccountId != null && stripeAccountId.isNotEmpty) {
        Stripe.stripeAccountId = stripeAccountId;
      }

      final merchantIdentifier = config['merchantIdentifier'] as String?;
      if (merchantIdentifier != null && merchantIdentifier.isNotEmpty) {
        Stripe.merchantIdentifier = merchantIdentifier;
      }

      _isInitialized = true;
      print(
          'Stripe initialized successfully with key: ${publishableKey.substring(0, 10)}...');
    } catch (e) {
      throw Exception('Failed to initialize Stripe: $e');
    }
  }

  /// Get Stripe configuration from ensemble config
  Future<Map<String, dynamic>?> _getStripeConfig() async {
    try {
      // Load the ensemble configuration file
      final yamlString =
          await rootBundle.loadString('ensemble/ensemble-config.yaml');
      final YamlMap yamlMap = loadYaml(yamlString);

      // Extract Stripe configuration
      final stripeConfig = yamlMap['stripe'] as YamlMap?;
      if (stripeConfig == null) {
        print('Stripe configuration not found in ensemble-config.yaml');
        return null;
      }

      return {
        'enabled': stripeConfig['enabled'] as bool? ?? false,
        'publishableKey': stripeConfig['publishableKey'] as String?,
        'stripeAccountId': stripeConfig['stripeAccountId'] as String?,
        'merchantIdentifier': stripeConfig['merchantIdentifier'] as String?,
      };
    } catch (e) {
      print('Error reading Stripe configuration: $e');
      return null;
    }
  }

  @override
  Future<void> showPaymentSheet({
    required String clientSecret,
    Map<String, dynamic>? configuration,
  }) async {
    // Auto-initialize if not already initialized
    await _ensureInitialized();

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
