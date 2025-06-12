import 'package:ensemble/framework/stub/adobe_manager.dart';
import 'package:flutter/foundation.dart';
import 'core.dart';
import 'edge.dart';
import 'identity.dart';
import 'consent.dart';
import 'user_profile.dart';
import 'assurance.dart';

class AdobeAnalyticsImpl implements AdobeAnalyticsModule {
  static final AdobeAnalyticsImpl _instance = AdobeAnalyticsImpl._internal();
  late final AdobeAnalyticsCore _core;
  late final AdobeAnalyticsEdge _edge;
  late final AdobeAnalyticsAssurance _assurance;
  late final AdobeAnalyticsIdentity _identity;
  late final AdobeAnalyticsConsent _consent;
  late final AdobeAnalyticsUserProfile _userProfile;

  AdobeAnalyticsImpl._internal();

  factory AdobeAnalyticsImpl({required String appId}) {
    if (!AdobeAnalyticsCore.checkInitialization()) {
      try {
        _instance._core = AdobeAnalyticsCore(appId: appId);
        _instance._edge = AdobeAnalyticsEdge();
        _instance._assurance = AdobeAnalyticsAssurance();
        _instance._identity = AdobeAnalyticsIdentity();
        _instance._consent = AdobeAnalyticsConsent();
        _instance._userProfile = AdobeAnalyticsUserProfile();
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
      _assurance = AdobeAnalyticsAssurance();
      _identity = AdobeAnalyticsIdentity();
      _consent = AdobeAnalyticsConsent();
      _userProfile = AdobeAnalyticsUserProfile();
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
    if (!checkInitialization()) {
      throw StateError(
          'Adobe Analytics: Not initialized. Call initialize() first.');
    }
    return _core.trackAction(name, parameters);
  }

  Future<dynamic> trackState(
      String name, Map<String, String>? parameters) async {
    if (!checkInitialization()) {
      throw StateError(
          'Adobe Analytics: Not initialized. Call initialize() first.');
    }
    return _core.trackState(name, parameters);
  }

  // ==========================
  // EDGE
  // ==========================

  Future<dynamic> sendEvent(
      String name, Map<String, dynamic>? parameters) async {
    if (!checkInitialization()) {
      throw StateError(
          'Adobe Analytics: Not initialized. Call initialize() first.');
    }
    return _edge.sendEvent(name, parameters);
  }

  // ==========================
  // ASSURANCE
  // ==========================

  Future<void> setupAssurance(Map<String, dynamic> parameters) async {
    if (!checkInitialization()) {
      throw StateError(
          'Adobe Analytics: Not initialized. Call initialize() first.');
    }
    return await _assurance.setupAssurance(parameters);
  }

  // ==========================
  // IDENTITY
  // ==========================

  Future<dynamic> getExperienceCloudId() async {
    if (!checkInitialization()) {
      throw StateError(
          'Adobe Analytics: Not initialized. Call initialize() first.');
    }
    return await _identity.getExperienceCloudId();
  }

  Future<dynamic> getIdentities() async {
    if (!checkInitialization()) {
      throw StateError(
          'Adobe Analytics: Not initialized. Call initialize() first.');
    }
    return await _identity.getIdentities();
  }

  Future<dynamic> getUrlVariables() async {
    if (!checkInitialization()) {
      throw StateError(
          'Adobe Analytics: Not initialized. Call initialize() first.');
    }
    return _identity.getUrlVariables();
  }

  Future<dynamic> removeIdentity(Map<String, dynamic> parameters) async {
    if (!checkInitialization()) {
      throw StateError(
          'Adobe Analytics: Not initialized. Call initialize() first.');
    }
    return await _identity.removeIdentity(parameters);
  }

  Future<dynamic> resetIdentities() async {
    if (!checkInitialization()) {
      throw StateError(
          'Adobe Analytics: Not initialized. Call initialize() first.');
    }
    return await _identity.resetIdentities();
  }

  Future<dynamic> setAdvertisingIdentifier(String advertisingIdentifier) async {
    if (!checkInitialization()) {
      throw StateError(
          'Adobe Analytics: Not initialized. Call initialize() first.');
    }
    return await _identity.setAdvertisingIdentifier(advertisingIdentifier);
  }

  Future<dynamic> updateIdentities(Map<String, dynamic> parameters) async {
    if (!checkInitialization()) {
      throw StateError(
          'Adobe Analytics: Not initialized. Call initialize() first.');
    }
    return await _identity.updateIdentities(parameters);
  }

  // ==========================
  // CONSENT
  // ==========================

  Future<dynamic> getConsents() async {
    if (!checkInitialization()) {
      throw StateError(
          'Adobe Analytics: Not initialized. Call initialize() first.');
    }
    return await _consent.getConsents();
  }

  Future<void> updateConsent(bool allowed) async {
    if (!checkInitialization()) {
      throw StateError(
          'Adobe Analytics: Not initialized. Call initialize() first.');
    }
    return await _consent.updateConsent(allowed);
  }

  Future<void> setDefaultConsent(bool allowed) async {
    if (!checkInitialization()) {
      throw StateError(
          'Adobe Analytics: Not initialized. Call initialize() first.');
    }
    return await _consent.setDefaultConsent(allowed);
  }

  // ==========================
  // USER PROFILE
  // ==========================

  Future<String> getUserAttributes(Map<String, dynamic> parameters) async {
    if (!checkInitialization()) {
      throw StateError(
          'Adobe Analytics: Not initialized. Call initialize() first.');
    }
    final attributes =
        (parameters['attributes'] as List).map((e) => e.toString()).toList();
    return await _userProfile.getUserAttributes(attributes);
  }

  Future<void> removeUserAttributes(Map<String, dynamic> parameters) async {
    if (!checkInitialization()) {
      throw StateError(
          'Adobe Analytics: Not initialized. Call initialize() first.');
    }
    final attributesList = parameters['attributes'];
    if (attributesList == null) {
      throw ArgumentError('attributes parameter cannot be null');
    }
    final attributes =
        (attributesList as List).map((e) => e.toString()).toList();
    return await _userProfile.removeUserAttributes(attributes);
  }

  Future<void> updateUserAttributes(Map<String, dynamic> parameters) async {
    if (!checkInitialization()) {
      throw StateError(
          'Adobe Analytics: Not initialized. Call initialize() first.');
    }
    final attributeMap =
        Map<String, Object>.from(parameters['attributeMap'] as Map);
    return await _userProfile.updateUserAttributes(attributeMap);
  }
}
