import 'package:ensemble/framework/stub/adobe_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_aepcore/flutter_aepcore.dart';
import 'package:flutter_aepedge/flutter_aepedge.dart';
import 'package:flutter_aepassurance/flutter_aepassurance.dart';

class AdobeAnalyticsImpl implements AdobeAnalyticsModule {
  static final AdobeAnalyticsImpl _instance = AdobeAnalyticsImpl._internal();
  AdobeAnalyticsImpl._internal();

  static bool _isAdobeAnalyticsInitialized = false;

  factory AdobeAnalyticsImpl({required String appId}) {
    if (!AdobeAnalyticsImpl._isAdobeAnalyticsInitialized) {
      try {
        _instance.initialize(appId);
      } catch (e) {
        debugPrint('Error initializing Adobe Analytics: $e');
      }
    }
    return _instance;
  }

  Future<dynamic> initialize(String appId) async {
    try {
      debugPrint('Initializing Adobe Analytics with appId: $appId');
      // Initialize the AEP Core SDK
      await MobileCore.setLogLevel(LogLevel.trace);
      await MobileCore.initializeWithAppId(appId: appId);
      _isAdobeAnalyticsInitialized = true;
      print('Adobe Analytics initialized');
      return true;
    } catch (e) {
      debugPrint('Error initializing Adobe Analytics: $e');
      throw StateError('Error initializing Adobe Analytics: $e');
    }
  }

  static bool checkInitialization() {
    return _isAdobeAnalyticsInitialized;
  }

  Future<dynamic> trackAction(
      String name, Map<String, String>? parameters) async {
    if (!checkInitialization()) {
      throw StateError(
          'Adobe Analytics: Not initialized. Call initialize() first.');
    }
    try {
      debugPrint(
          'Tracking Adobe Analytics action: $name with parameters: $parameters');
      return await MobileCore.trackAction(name, data: parameters).timeout(
        Duration(seconds: 10),
        onTimeout: () {
          debugPrint('MobileCore.trackAction timed out!');
          throw StateError('MobileCore.trackAction timed out!');
        },
      );
    } catch (e) {
      debugPrint('Error tracking Adobe Analytics action: $e');
    }
  }

  Future<dynamic> trackState(
      String name, Map<String, String>? parameters) async {
    if (!checkInitialization()) {
      throw StateError(
          'Adobe Analytics: Not initialized. Call initialize() first.');
    }
    try {
      debugPrint(
          'Tracking Adobe Analytics state: $name with parameters: $parameters');
      return await MobileCore.trackState(name, data: parameters).timeout(
        Duration(seconds: 10),
        onTimeout: () {
          debugPrint('MobileCore.trackState timed out!');
          throw StateError('MobileCore.trackState timed out!');
        },
      );
    } catch (e) {
      debugPrint('Error tracking Adobe Analytics state: $e');
    }
  }

  Future<dynamic> sendEvent(
      String name, Map<String, dynamic>? parameters) async {
    if (!checkInitialization()) {
      throw StateError(
          'Adobe Analytics: Not initialized. Call initialize() first.');
    }
    try {
      debugPrint(
          'Sending Adobe Analytics event: $name with parameters: $parameters');
      late List<EventHandle> result;
      if (parameters == null) {
        throw StateError('Parameters are required for sendEvent');
      }
      final xdmData = parameters['xdmData'] is Map
          ? parameters['xdmData'] as Map<String, dynamic>
          : null;
      final data = parameters['data'] is Map
          ? parameters['data'] as Map<String, dynamic>
          : null;
      final datasetIdentifier =
          parameters['datasetIdentifier'] as String? ?? null;
      final configOverrides = parameters['configOverrides'] is Map
          ? parameters['configOverrides'] as Map<String, dynamic>
          : null;
      final datastreamIdOverride =
          parameters['datastreamIdOverride'] as String? ?? null;

      var event = <String, dynamic>{};
      if (xdmData != null) {
        event['xdmData'] = xdmData;
      }
      if (data != null) {
        event['data'] = data;
      }
      if (datasetIdentifier != null) {
        event['datasetIdentifier'] = datasetIdentifier;
      }
      if (datastreamIdOverride != null) {
        event['datastreamIdOverride'] = datastreamIdOverride;
      }
      if (configOverrides != null) {
        event['datastreamConfigOverride'] = configOverrides;
      }
      final experienceEvent = ExperienceEvent(event);

      result = await Edge.sendEvent(experienceEvent).timeout(
        Duration(seconds: 10),
        onTimeout: () {
          debugPrint('Edge.sendEvent timed out!');
          throw StateError('Edge.sendEvent timed out!');
        },
      );
      return result;
    } catch (e, stack) {
      debugPrint('Error sending Adobe Analytics event: $e\n$stack');
      throw StateError('Error sending Adobe Analytics event: $e');
    }
  }

  Future<dynamic> setupAssurance(String url) async {
    if (!checkInitialization()) {
      throw StateError(
          'Adobe Analytics: Not initialized. Call initialize() first.');
    }
    try {
      return await Assurance.startSession(url);
    } catch (e) {
      debugPrint('Error setting up Adobe Analytics Assurance: $e');
    }
  }
}
