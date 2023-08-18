import 'package:ensemble/framework/error_handling.dart';

typedef PlaidLinkSuccessCallback = void Function(dynamic);
typedef PlaidLinkEventCallback = void Function(dynamic);
typedef PlaidLinkErrorCallback = void Function(dynamic);

abstract class PlaidLinkManager {
  void openPlaidLink(String plaidLink, PlaidLinkSuccessCallback onSuccess,
      PlaidLinkEventCallback onEvent, PlaidLinkErrorCallback onExit);
}

class PlaidLinkManagerStub extends PlaidLinkManager {
  @override
  void openPlaidLink(String plaidLink, PlaidLinkSuccessCallback onSuccess,
      PlaidLinkEventCallback onEvent, PlaidLinkErrorCallback onExit) {
    throw ConfigError(
        "Plaid Link Service is not enabled. Please review the Ensemble documentation.");
  }
}
