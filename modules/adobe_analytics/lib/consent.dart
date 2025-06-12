import 'package:flutter_aepcore/flutter_aepcore.dart';
import 'package:flutter_aepedgeconsent/flutter_aepedgeconsent.dart';

class AdobeAnalyticsConsent {
  AdobeAnalyticsConsent();

  // Retrieves the current consent preferences stored in the Consent extension.
  Future<dynamic> getConsents() async {
    Map<String, dynamic> result = {};
    try {
      result = await Consent.consents;
      return result;
    } catch (e) {
      throw StateError('Error getting Adobe Analytics Consents: $e');
    }
  }

  Future<void> setDefaultConsent(bool allowed) async {
    Map<String, Object> collectConsents = allowed
        ? {
            "collect": {"val": "y"}
          }
        : {
            "collect": {"val": "n"}
          };
    Map<String, Object> currentConsents = {"consents": collectConsents};
    Map<String, Object> defaultConsents = {"consents.default": currentConsents};

    MobileCore.updateConfiguration(defaultConsents);
  }

  // Merges the existing consents with the given consents. Duplicate keys will take the value of those passed in the API.
  Future<void> updateConsent(bool allowed) async {
    Map<String, dynamic> collectConsents = allowed
        ? {
            "collect": {"val": "y"}
          }
        : {
            "collect": {"val": "n"}
          };
    Map<String, dynamic> currentConsents = {"consents": collectConsents};

    Consent.update(currentConsents);
  }
}
