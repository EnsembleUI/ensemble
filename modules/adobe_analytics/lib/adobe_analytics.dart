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
      // Initialize the AEP Core SDK
      await MobileCore.setLogLevel(LogLevel.trace);
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
      debugPrint(
          'Tracking Adobe Analytics action: $name with parameters: $parameters');
      await MobileCore.trackAction(name, data: parameters).timeout(
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

  Future<void> trackState(String name, Map<String, String>? parameters) async {
    if (!checkInitialization()) {
      throw StateError(
          'Adobe Analytics: Not initialized. Call initialize() first.');
    }
    try {
      debugPrint(
          'Tracking Adobe Analytics state: $name with parameters: $parameters');
      await MobileCore.trackState(name, data: parameters).timeout(
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

  Future<void> sendEvent(String name, Map<String, dynamic>? parameters) async {
    if (!checkInitialization()) {
      throw StateError(
          'Adobe Analytics: Not initialized. Call initialize() first.');
    }
    try {
      debugPrint(
          'Sending Adobe Analytics event: $name with parameters: $parameters');
      if (parameters != null) {
        final xdmData = parameters['xdmData'] is Map
            ? parameters['xdmData'] as Map<String, dynamic>
            : <String, dynamic>{};
        final data = parameters['data'] is Map
            ? parameters['data'] as Map<String, dynamic>
            : <String, dynamic>{};
        final datastreamId = parameters['datastreamId'] as String? ?? '';
        final configOverrides = parameters['configOverrides'] is Map
            ? parameters['configOverrides'] as Map<String, dynamic>
            : <String, dynamic>{};

        final experienceEvent = ExperienceEvent.createEventWithOverrides(
          xdmData,
          data,
          datastreamId,
          configOverrides,
        );
        await Edge.sendEvent(experienceEvent).timeout(
          Duration(seconds: 10),
          onTimeout: () {
            debugPrint('Edge.sendEvent timed out!');
            throw StateError('Edge.sendEvent timed out!');
          },
        );
        debugPrint(
            'Adobe Analytics event sent successfully: $name with xdmData: $xdmData');
      } else {
        await Edge.sendEvent(
          ExperienceEvent({
            'xdmData': {'eventType': name},
          }),
        );
        debugPrint('Adobe Analytics event sent successfully: $name');
      }
    } catch (e, stack) {
      debugPrint('Error sending Adobe Analytics event: $e\n$stack');
      throw StateError('Error sending Adobe Analytics event: $e');
    }
  }
}
