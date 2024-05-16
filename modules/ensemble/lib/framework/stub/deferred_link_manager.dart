import 'package:ensemble/framework/error_handling.dart';

typedef DeferredDeepLink = Function(Map<dynamic, dynamic>);

enum DeepLinkProvider { branch, appsflyer, adjust }

class DeferredLinkResponse {
  bool success = true;
  dynamic result;
  String errorCode = '';
  String errorMessage = '';

  DeferredLinkResponse.success({required this.result}) {
    success = true;
  }
  DeferredLinkResponse.error(
      {required this.errorCode, required this.errorMessage}) {
    success = false;
  }

  @override
  String toString() {
    return ('success: $success, errorCode: $errorCode, errorMessage: $errorMessage}');
  }
}

abstract class DeferredLinkManager {
  Future<void> init({
    required DeepLinkProvider provider,
    Map<String, dynamic>? options,
    DeferredDeepLink? onLinkReceived,
  });

  void handleDeferredLink(String url, DeferredDeepLink onLinkReceived);

  Future<DeferredLinkResponse?> createDeepLink(
      {required DeepLinkProvider provider,
      Map<String, dynamic>? universalProps,
      Map<String, dynamic>? linkProps});
}

class DeferredLinkManagerStub extends DeferredLinkManager {
  @override
  Future<void> init(
      {required DeepLinkProvider provider,
      Map<String, dynamic>? options,
      DeferredDeepLink? onLinkReceived}) {
    throw ConfigError(
        "Deferred Link Service is not enabled. Please review the Ensemble documentation.");
  }

  @override
  void handleDeferredLink(String url, DeferredDeepLink onLinkReceived) {
    throw ConfigError(
        "Deferred Link Service is not enabled. Please review the Ensemble documentation.");
  }

  @override
  Future<DeferredLinkResponse?> createDeepLink(
      {required DeepLinkProvider provider,
      Map<String, dynamic>? universalProps,
      Map<String, dynamic>? linkProps}) {
    throw ConfigError(
        "Deferred Link Service is not enabled. Please review the Ensemble documentation.");
  }
}
