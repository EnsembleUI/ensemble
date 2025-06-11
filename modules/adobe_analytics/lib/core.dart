import 'package:flutter/foundation.dart';
import 'package:flutter_aepcore/flutter_aepcore.dart';

class AdobeAnalyticsCore {
  static final AdobeAnalyticsCore _instance = AdobeAnalyticsCore._internal();
  AdobeAnalyticsCore._internal();

  static bool _isAdobeAnalyticsInitialized = false;

  factory AdobeAnalyticsCore({required String appId}) {
    if (!AdobeAnalyticsCore._isAdobeAnalyticsInitialized) {
      try {
        _instance.initialize(appId);
      } catch (e) {
        debugPrint('Error initializing Adobe Analytics: $e');
      }
    }
    return _instance;
  }

  // Initialize the AEP SDK by automatically registering all extensions bundled with the application and enabling automatic lifecycle tracking.
  // appId: Configures the SDK with the provided mobile property environment ID configured from the Data Collection UI.
  Future<dynamic> initialize(String appId) async {
    try {
      // Initialize the AEP Core SDK
      await MobileCore.setLogLevel(LogLevel.trace);
      await MobileCore.initializeWithAppId(appId: appId);
      _isAdobeAnalyticsInitialized = true;
      return true;
    } catch (e) {
      debugPrint('Error initializing Adobe Analytics: $e');
      throw StateError('Error initializing Adobe Analytics: $e');
    }
  }

  static bool checkInitialization() {
    return _isAdobeAnalyticsInitialized;
  }

  // Track event actions that occur in your application.
  Future<dynamic> trackAction(
      String name, Map<String, String>? parameters) async {
    try {
      return await MobileCore.trackAction(name, data: parameters).timeout(
        Duration(seconds: 10),
        onTimeout: () {
          throw StateError('MobileCore.trackAction timed out!');
        },
      );
    } catch (e) {
      debugPrint('Error tracking Adobe Analytics action: $e');
    }
  }

  // Track states that represent screens or views in your application.
  Future<dynamic> trackState(
      String name, Map<String, String>? parameters) async {
    try {
      return await MobileCore.trackState(name, data: parameters).timeout(
        Duration(seconds: 10),
        onTimeout: () {
          throw StateError('MobileCore.trackState timed out!');
        },
      );
    } catch (e) {
      debugPrint('Error tracking Adobe Analytics state: $e');
    }
  }
}
