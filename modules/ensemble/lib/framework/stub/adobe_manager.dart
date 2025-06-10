import 'package:ensemble/framework/error_handling.dart';

abstract class AdobeAnalyticsModule {
  Future<void> initialize(String appId);
  Future<void> trackAction(String eventName, Map<String, String> parameters);
  Future<void> trackState(String eventName, Map<String, String> parameters);
  Future<void> sendEvent(String eventName, Map<String, dynamic> parameters);
  Future<void> setupAssurance(String url);
}

class AdobeAnalyticsModuleStub implements AdobeAnalyticsModule {
  final _errorMsg =
      "Adobe Analytics module is not enabled. Please review the Ensemble documentation.";

  @override
  Future<void> initialize(String appId) async {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<void> trackAction(
      String eventName, Map<String, String> parameters) async {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<void> trackState(
      String eventName, Map<String, String> parameters) async {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<void> sendEvent(
      String eventName, Map<String, dynamic> parameters) async {
    throw ConfigError(_errorMsg);
  }

  @override
  Future<void> setupAssurance(String url) async {
    throw ConfigError(_errorMsg);
  }
}
