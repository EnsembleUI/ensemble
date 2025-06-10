import 'package:flutter/foundation.dart';
import 'package:flutter_aepcore/flutter_aepcore.dart';
import 'package:flutter_aepedgeidentity/flutter_aepedgeidentity.dart';

class AdobeAnalyticsIdentity {
  AdobeAnalyticsIdentity();

  Future<dynamic> getExperienceCloudId() async {
    try {
      return await Identity.experienceCloudId;
    } catch (e) {
      debugPrint('Error getting Adobe Analytics Experience Cloud ID: $e');
      throw StateError('Error getting Adobe Analytics Experience Cloud ID: $e');
    }
  }

  Future<dynamic> getIdentities() async {
    try {
      return await Identity.identities;
    } catch (e) {
      debugPrint('Error getting Adobe Analytics Identities: $e');
      throw StateError('Error getting Adobe Analytics Identities: $e');
    }
  }

  Future<dynamic> getUrlVariables() async {
    try {
      return await Identity.urlVariables;
    } catch (e) {
      debugPrint('Error getting Adobe Analytics URL Variables: $e');
      throw StateError('Error getting Adobe Analytics URL Variables: $e');
    }
  }

  Future<dynamic> removeIdentity(IdentityItem item, String namespace) async {
    try {
      return await Identity.removeIdentity(item, namespace);
    } catch (e) {
      debugPrint('Error removing Adobe Analytics Identity: $e');
      throw StateError('Error removing Adobe Analytics Identity: $e');
    }
  }

  Future<dynamic> resetIdentities() async {
    try {
      return await MobileCore.resetIdentities();
    } catch (e) {
      debugPrint('Error resetting Adobe Analytics Identity: $e');
      throw StateError('Error resetting Adobe Analytics Identity: $e');
    }
  }

  Future<dynamic> setAdvertisingIdentifier(String advertisingIdentifier) async {
    try {
      return await MobileCore.setAdvertisingIdentifier(advertisingIdentifier);
    } catch (e) {
      debugPrint('Error setting Adobe Analytics Advertising Identifier: $e');
      throw StateError(
          'Error setting Adobe Analytics Advertising Identifier: $e');
    }
  }

  Future<dynamic> updateIdentities(IdentityMap identities) async {
    try {
      return await Identity.updateIdentities(identities);
    } catch (e) {
      debugPrint('Error updating Adobe Analytics Identities: $e');
      throw StateError('Error updating Adobe Analytics Identities: $e');
    }
  }
}
