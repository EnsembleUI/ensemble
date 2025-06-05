import 'package:ensemble/framework/stub/adobe_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_aepcore/flutter_aepcore.dart';
import 'package:flutter_aepedge/flutter_aepedge.dart';

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

  Future<void> initialize(String appId) async {
    try {
      debugPrint('Initializing Adobe Analytics with appId: $appId');
      await MobileCore.setLogLevel(LogLevel.debug);
      await MobileCore.initializeWithAppId(appId: appId);
      _isAdobeAnalyticsInitialized = true;
      print('Adobe Analytics initialized');
    } catch (e) {
      debugPrint('Error initializing Adobe Analytics: $e');
      throw StateError('Error initializing Adobe Analytics: $e');
    }
  }

  static bool checkInitialization() {
    return _isAdobeAnalyticsInitialized;
  }

  Future<void> trackAction(String name, Map<String, String>? parameters) async {
    if (!checkInitialization()) {
      throw StateError(
          'Adobe Analytics: Not initialized. Call initialize() first.');
    }
    try {
      if (parameters != null) {
        await MobileCore.trackAction(name, data: parameters);
      } else {
        await MobileCore.trackAction(name, data: {});
      }
    } catch (e) {
      debugPrint('Error tracking Adobe Analytics action: $e');
    }
  }

  Future<void> trackState(String name, Map<String, String>? parameters) async {
    if (!checkInitialization()) {
      throw StateError(
          'Adobe Analytics: Not initialized. Call initialize() first.');
    }
    try {
      if (parameters != null) {
        await MobileCore.trackState(name, data: parameters);
      } else {
        await MobileCore.trackState(name, data: {});
      }
    } catch (e) {
      debugPrint('Error tracking Adobe Analytics state: $e');
    }
  }

  Future<void> sendEvent(String name, Map<String, dynamic>? parameters) async {
    if (!checkInitialization()) {
      throw StateError(
          'Adobe Analytics: Not initialized. Call initialize() first.');
    }
    try {
      if (parameters != null) {
        final xdmData = parameters['xdmData'] as Map<String, dynamic>?;
        final data = parameters['data'] as Map<String, dynamic>?;
        final datastreamId = parameters['datastreamId'] as String?;
        final configOverrides =
            parameters['configOverrides'] as Map<String, dynamic>?;

        final ExperienceEvent experienceEvent = ExperienceEvent({
          'xdmData': xdmData ?? {'eventType': name},
          'data': data,
          if (datastreamId != null) 'datastreamIdOverride': datastreamId,
          if (configOverrides != null)
            'datastreamConfigOverride': configOverrides,
        });

        await Edge.sendEvent(experienceEvent);
      } else {
        await Edge.sendEvent(
          ExperienceEvent({
            'xdmData': {'eventType': name},
          }),
        );
      }
    } catch (e) {
      debugPrint('Error sending Adobe Analytics event: $e');
    }
  }

  Future<void> trackPurchase(
    String name,
    Map<String, String> parameters,
  ) async {
    if (!checkInitialization()) {
      throw StateError(
          'Adobe Analytics: Not initialized. Call initialize() first.');
    }
    try {
      final products = parameters['products']?.toString() ?? '';
      final events = parameters['events']?.toString() ?? '';
      final additionalData =
          parameters['additionalData'] as Map<String, String>?;
      final data = {
        '&&products': products,
        '&&events': events,
        ...?additionalData,
      };
      await MobileCore.trackAction(name, data: data);
    } catch (e) {
      debugPrint('Error tracking purchase: $e');
    }
  }

  Future<void> trackProductView(
    String name,
    Map<String, String> parameters,
  ) async {
    if (!checkInitialization()) {
      throw StateError(
          'Adobe Analytics: Not initialized. Call initialize() first.');
    }
    try {
      final products = parameters['products']?.toString() ?? '';
      final additionalData =
          parameters['additionalData'] as Map<String, String>?;
      final data = {
        '&&products': products,
        ...?additionalData,
      };
      await MobileCore.trackState(name, data: data);
    } catch (e) {
      debugPrint('Error tracking product view: $e');
    }
  }
}
