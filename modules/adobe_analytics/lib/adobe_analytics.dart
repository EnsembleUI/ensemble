/// Adobe Analytics implementation for Ensemble apps.
library adobe_analytics;

import 'package:ensemble/framework/stub/adobe_manager.dart';
import 'package:flutter/foundation.dart';
import 'core.dart';
import 'edge.dart';
import 'identity.dart';
import 'consent.dart';
import 'user_profile.dart';
import 'assurance.dart';

/// Coordinates Adobe Experience Platform analytics APIs for Ensemble.
class AdobeAnalyticsImpl implements AdobeAnalyticsModule {
  static final AdobeAnalyticsImpl _instance = AdobeAnalyticsImpl._internal();
  late final AdobeAnalyticsCore _core;
  late final AdobeAnalyticsEdge _edge;
  late final AdobeAnalyticsAssurance _assurance;
  late final AdobeAnalyticsIdentity _identity;
  late final AdobeAnalyticsConsent _consent;
  late final AdobeAnalyticsUserProfile _userProfile;

  AdobeAnalyticsImpl._internal();

  /// Creates the shared Adobe Analytics module instance for [appId].
  factory AdobeAnalyticsImpl({required String appId}) {
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
    return _instance;
  }

  /// Initializes Adobe Analytics with the supplied mobile property [appId].
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

  // ==========================
  // CORE
  // ==========================

  /// Tracks a user action with optional string [parameters].
  Future<dynamic> trackAction(
      String name, Map<String, String>? parameters) async {
    return _core.trackAction(name, parameters);
  }

  /// Tracks an app state or screen with optional string [parameters].
  Future<dynamic> trackState(
      String name, Map<String, String>? parameters) async {
    return _core.trackState(name, parameters);
  }

  // ==========================
  // EDGE
  // ==========================

  /// Sends an Experience Edge event with optional XDM and data [parameters].
  Future<dynamic> sendEvent(
      String name, Map<String, dynamic>? parameters) async {
    return _edge.sendEvent(name, parameters);
  }

  // ==========================
  // ASSURANCE
  // ==========================

  /// Starts Adobe Assurance using the provided connection [parameters].
  Future<void> setupAssurance(Map<String, dynamic> parameters) async {
    return await _assurance.setupAssurance(parameters);
  }

  // ==========================
  // IDENTITY
  // ==========================

  /// Returns the current Experience Cloud ID.
  Future<dynamic> getExperienceCloudId() async {
    return await _identity.getExperienceCloudId();
  }

  /// Returns the identities currently known to the Adobe SDK.
  Future<dynamic> getIdentities() async {
    return await _identity.getIdentities();
  }

  /// Returns Adobe identity URL variables for hybrid web views.
  Future<dynamic> getUrlVariables() async {
    return _identity.getUrlVariables();
  }

  /// Removes one identity described by [parameters].
  Future<dynamic> removeIdentity(Map<String, dynamic> parameters) async {
    return await _identity.removeIdentity(parameters);
  }

  /// Clears SDK identities and returns the refreshed identity state.
  Future<dynamic> resetIdentities() async {
    return await _identity.resetIdentities();
  }

  /// Sets or clears the advertising identifier used by the SDK.
  Future<dynamic> setAdvertisingIdentifier(String advertisingIdentifier) async {
    return await _identity.setAdvertisingIdentifier(advertisingIdentifier);
  }

  /// Merges the supplied identity [parameters] into the SDK identity map.
  Future<dynamic> updateIdentities(Map<String, dynamic> parameters) async {
    return await _identity.updateIdentities(parameters);
  }

  // ==========================
  // CONSENT
  // ==========================

  /// Returns the current Adobe consent preferences.
  Future<dynamic> getConsents() async {
    return await _consent.getConsents();
  }

  /// Updates the collect consent preference.
  Future<void> updateConsent(bool allowed) async {
    return await _consent.updateConsent(allowed);
  }

  /// Sets the default collect consent preference.
  Future<void> setDefaultConsent(bool allowed) async {
    return await _consent.setDefaultConsent(allowed);
  }

  // ==========================
  // USER PROFILE
  // ==========================

  /// Reads user profile attributes named in [parameters].
  Future<String> getUserAttributes(Map<String, dynamic> parameters) async {
    final attributes =
        (parameters['attributes'] as List).map((e) => e.toString()).toList();
    return await _userProfile.getUserAttributes(attributes);
  }

  /// Removes user profile attributes named in [parameters].
  Future<void> removeUserAttributes(Map<String, dynamic> parameters) async {
    final attributesList = parameters['attributes'];
    if (attributesList == null) {
      throw ArgumentError('attributes parameter cannot be null');
    }
    final attributes =
        (attributesList as List).map((e) => e.toString()).toList();
    return await _userProfile.removeUserAttributes(attributes);
  }

  /// Updates user profile attributes from [parameters].
  Future<void> updateUserAttributes(Map<String, dynamic> parameters) async {
    final attributeMap =
        Map<String, Object>.from(parameters['attributeMap'] as Map);
    return await _userProfile.updateUserAttributes(attributeMap);
  }
}
