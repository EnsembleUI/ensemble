import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

/// A web implementation of the HighChart plugin.
///
/// # Not used :-)
///
class HighChartPlatformInterface {
  static void registerWith(Registrar registrar) {
    final MethodChannel channel = MethodChannel(
      'high_chart',
      const StandardMethodCodec(),
      registrar,
    );

    final pluginInstance = HighChartPlatformInterface();
    channel.setMethodCallHandler(pluginInstance.handleMethodCall);
  }

  /// Handles method calls over the MethodChannel of this plugin.
  /// Note: Check the "federated" architecture for a new way of doing this:
  /// https://flutter.dev/go/federated-plugins
  Future<dynamic> handleMethodCall(MethodCall call) async {
    switch (call.method) {
      default:
        throw PlatformException(
          code: 'Unimplemented',
          details: 'high_chart for web doesn\'t implement \'${call.method}\'',
        );
    }
  }
}
