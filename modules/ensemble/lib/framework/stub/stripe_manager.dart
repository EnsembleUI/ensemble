import 'dart:async';
import 'package:flutter/material.dart';

import 'package:ensemble/framework/error_handling.dart';

/// Abstract interface for Stripe operations
abstract class StripeManager {
  /// Show the Stripe payment sheet
  Future<void> showPaymentSheet({
    required String clientSecret,
    Map<String, dynamic>? configuration,
  });
}

/// Stub implementation of StripeManager
class StripeManagerStub implements StripeManager {
  @override
  Future<void> showPaymentSheet({
    required String clientSecret,
    Map<String, dynamic>? configuration,
    BuildContext? context,
  }) async {
    throw ConfigError('Stripe module is not enabled');
  }
}
