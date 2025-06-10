import 'package:ensemble/framework/stub/adobe_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_aepassurance/flutter_aepassurance.dart';
import 'package:flutter_aepedgeidentity/flutter_aepedgeidentity.dart';
import 'core.dart';
import 'edge.dart';
import 'identity.dart';

class AdobeAnalyticsImpl implements AdobeAnalyticsModule {
  static final AdobeAnalyticsImpl _instance = AdobeAnalyticsImpl._internal();
  late final AdobeAnalyticsCore _core;
  late final AdobeAnalyticsEdge _edge;
  late final AdobeAnalyticsIdentity _identity;

  AdobeAnalyticsImpl._internal();

  factory AdobeAnalyticsImpl({required String appId}) {
    if (!AdobeAnalyticsCore.checkInitialization()) {
      try {
        _instance._core = AdobeAnalyticsCore(appId: appId);
        _instance._edge = AdobeAnalyticsEdge();
        _instance._identity = AdobeAnalyticsIdentity();
      } catch (e) {
        debugPrint('Error initializing Adobe Analytics: $e');
      }
    }
    return _instance;
  }

  Future<dynamic> initialize(String appId) async {
    try {
      _core = AdobeAnalyticsCore(appId: appId);
      _edge = AdobeAnalyticsEdge();
      _identity = AdobeAnalyticsIdentity();
      return true;
    } catch (e) {
      debugPrint('Error initializing Adobe Analytics: $e');
      throw StateError('Error initializing Adobe Analytics: $e');
    }
  }

  static bool checkInitialization() {
    return AdobeAnalyticsCore.checkInitialization();
  }

  // ==========================
  // CORE
  // ==========================

  Future<dynamic> trackAction(
      String name, Map<String, String>? parameters) async {
    return _core.trackAction(name, parameters);
  }

  Future<dynamic> trackState(
      String name, Map<String, String>? parameters) async {
    return _core.trackState(name, parameters);
  }

  // ==========================
  // EDGE
  // ==========================

  Future<dynamic> sendEvent(
      String name, Map<String, dynamic>? parameters) async {
    return _edge.sendEvent(name, parameters);
  }

  // ==========================
  // ASSURANCE
  // ==========================

  Future<dynamic> setupAssurance(String url) async {
    if (!checkInitialization()) {
      throw StateError(
          'Adobe Analytics: Not initialized. Call initialize() first.');
    }
    try {
      return await Assurance.startSession(url);
    } catch (e) {
      debugPrint('Error setting up Adobe Analytics Assurance: $e');
      throw StateError('Error setting up Adobe Analytics Assurance: $e');
    }
  }

  // ==========================
  // IDENTITY
  // ==========================

  Future<dynamic> getExperienceCloudId() async {
    return _identity.getExperienceCloudId();
  }

  Future<dynamic> getIdentities() async {
    return _identity.getIdentities();
  }

  Future<dynamic> getUrlVariables() async {
    return _identity.getUrlVariables();
  }

  Future<dynamic> removeIdentity(Map<String, dynamic> parameters) async {
    final item = parameters['item'] as IdentityItem;
    final namespace = parameters['namespace'] as String;
    return _identity.removeIdentity(item, namespace);
  }

  Future<dynamic> resetIdentities() async {
    return _identity.resetIdentities();
  }

  Future<dynamic> setAdvertisingIdentifier(String advertisingIdentifier) async {
    return _identity.setAdvertisingIdentifier(advertisingIdentifier);
  }

  Future<dynamic> updateIdentities(Map<String, dynamic> parameters) async {
    final identities = parameters['identities'] as IdentityMap;
    return _identity.updateIdentities(identities);
  }
}
