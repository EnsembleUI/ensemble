import 'package:ensemble/framework/error_handling.dart';

abstract class AdobeAnalyticsModule {
  Future<dynamic> initialize(String appId);
  Future<dynamic> trackAction(String eventName, Map<String, String> parameters);
  Future<dynamic> trackState(String eventName, Map<String, String> parameters);
  Future<dynamic> sendEvent(String eventName, Map<String, dynamic> parameters);
  Future<dynamic> setupAssurance(String url);
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
}
