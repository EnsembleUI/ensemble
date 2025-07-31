import 'dart:async';
import 'package:flutter/material.dart';

import 'package:ensemble/framework/error_handling.dart';

/// Abstract interface for Stripe operations
abstract class StripeManager {
  /// Initialize Stripe with the given configuration
  Future<void> initializeStripe({
    String? publishableKey,
    String? stripeAccountId,
    String? merchantIdentifier,
  });

  /// Show the Stripe payment sheet
  Future<void> showPaymentSheet({
    required String clientSecret,
    Map<String, dynamic>? configuration,
  });
}

/// Stub implementation of StripeManager
class StripeManagerStub implements StripeManager {
  @override
  Future<void> initializeStripe({
    String? publishableKey,
    String? stripeAccountId,
    String? merchantIdentifier,
  }) async {
    throw ConfigError('Stripe module is not enabled');
  }

  @override
  Future<void> showPaymentSheet({
    required String clientSecret,
    Map<String, dynamic>? configuration,
    BuildContext? context,
  }) async {
    throw ConfigError('Stripe module is not enabled');
  }
}
