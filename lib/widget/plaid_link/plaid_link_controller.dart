import 'package:flutter/material.dart';
import 'package:plaid_flutter/plaid_flutter.dart';

typedef PaidLinkSuccessCallback = void Function(LinkSuccess);
typedef PaidLinkEventCallback = void Function(LinkEvent);
typedef PaidLinkErrorCallback = void Function(LinkExit);

class PlaidLinkController {
  static final PlaidLinkController _instance = PlaidLinkController._internal();
  PlaidLinkController._internal();

  factory PlaidLinkController() {
    return _instance;
  }

  void openPlaidLink(
      BuildContext context,
      String plaidLink,
      PaidLinkSuccessCallback onSuccess,
      PaidLinkEventCallback onEvent,
      PaidLinkErrorCallback onExit) {
    // Subscribe to all events

    PlaidLink.onSuccess.listen((successData) {
      onSuccess(successData);
    });
    PlaidLink.onEvent.listen((eventData) {
      onEvent(eventData);
    });
    PlaidLink.onExit.listen((exitData) {
      onExit(exitData);
    });

    PlaidLink.open(configuration: LinkTokenConfiguration(token: plaidLink));
  }
}
