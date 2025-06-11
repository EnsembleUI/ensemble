import 'package:ensemble/framework/error_handling.dart';

abstract class AdobeAnalyticsModule {
  // CORE
  Future<dynamic> initialize(String appId);
  Future<dynamic> trackAction(String eventName, Map<String, String> parameters);
  Future<dynamic> trackState(String eventName, Map<String, String> parameters);

  // EDGE
  Future<dynamic> sendEvent(String eventName, Map<String, dynamic> parameters);

  // ASSURANCE
  Future<dynamic> setupAssurance(String url);

  // IDENTITY
  Future<dynamic> getExperienceCloudId();
  Future<dynamic> getIdentities();
  Future<dynamic> getUrlVariables();
  Future<dynamic> removeIdentity(Map<String, dynamic> parameters);
  Future<dynamic> resetIdentities();
  Future<dynamic> setAdvertisingIdentifier(String advertisingIdentifier);
  Future<dynamic> updateIdentities(Map<String, dynamic> parameters);

  // CONSENT
  Future<dynamic> getConsents();
  Future<void> updateConsent(bool allowed);
  Future<void> setDefaultConsent(bool allowed);

  // USER PROFILE
  Future<String> getUserAttributes(Map<String, dynamic> parameters);
  Future<void> removeUserAttributes(Map<String, dynamic> parameters);
  Future<void> updateUserAttributes(Map<String, dynamic> parameters);
}

class AdobeAnalyticsModuleStub implements AdobeAnalyticsModule {
  final _errorMsg =
      "Adobe Analytics module is not enabled. Please review the Ensemble documentation.";

  @override
  Future<dynamic> initialize(String appId) async {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<dynamic> trackAction(
      String eventName, Map<String, String> parameters) async {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<dynamic> trackState(
      String eventName, Map<String, String> parameters) async {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<dynamic> sendEvent(
      String eventName, Map<String, dynamic> parameters) async {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<dynamic> setupAssurance(String url) async {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<dynamic> getExperienceCloudId() async {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<dynamic> getIdentities() async {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<dynamic> getUrlVariables() async {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<dynamic> removeIdentity(Map<String, dynamic> parameters) async {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<dynamic> resetIdentities() async {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<dynamic> setAdvertisingIdentifier(String advertisingIdentifier) async {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<dynamic> updateIdentities(Map<String, dynamic> parameters) async {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<dynamic> getConsents() async {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<void> updateConsent(bool allowed) async {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<void> setDefaultConsent(bool allowed) async {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<String> getUserAttributes(Map<String, dynamic> parameters) async {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<void> removeUserAttributes(Map<String, dynamic> parameters) async {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<void> updateUserAttributes(Map<String, dynamic> parameters) async {
    throw ConfigError(_errorMsg);
  }
}
