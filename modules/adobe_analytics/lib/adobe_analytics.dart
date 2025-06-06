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
      debugPrint(
          'Tracking Adobe Analytics action: $name with parameters: $parameters');
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
      debugPrint(
          'Tracking Adobe Analytics state: $name with parameters: $parameters');
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
      debugPrint(
          'Sending Adobe Analytics event: $name with parameters: $parameters');
      if (parameters != null) {
        final xdmDataRaw = parameters['xdmData'];
        final xdmData = (xdmDataRaw is Map)
            ? xdmDataRaw.cast<String, dynamic>()
            : <String, dynamic>{};

        final dataRaw = parameters['data'];
        final data = (dataRaw is Map)
            ? dataRaw.cast<String, dynamic>()
            : <String, dynamic>{};

        final datastreamId = parameters['datastreamId'] as String?;
        final configOverridesRaw = parameters['configOverrides'];
        final configOverrides = (configOverridesRaw is Map)
            ? configOverridesRaw.cast<String, dynamic>()
            : null;

        final experienceEvent = ExperienceEvent.createEventWithOverrides(
          xdmData,
          data,
          datastreamId,
          configOverrides,
        );

        await Edge.sendEvent(experienceEvent);
        debugPrint(
            'Adobe Analytics event sent: $name with xdmData: $xdmData, data: $data, datastreamId: $datastreamId, configOverrides: $configOverrides');
      } else {
        await Edge.sendEvent(
          ExperienceEvent({
            'xdmData': {'eventType': name},
          }),
        );
      }
    } catch (e, stack) {
      debugPrint('Error sending Adobe Analytics event: $e\n$stack');
    }
  }
}
