import 'package:flutter/material.dart';
import 'package:plaid_flutter/plaid_flutter.dart';

typedef PlaidLinkSuccessCallback = void Function(LinkSuccess);
typedef PlaidLinkEventCallback = void Function(LinkEvent);
typedef PlaidLinkErrorCallback = void Function(LinkExit);

class PlaidLinkController {
  static final PlaidLinkController _instance = PlaidLinkController._internal();
  PlaidLinkController._internal();

  factory PlaidLinkController() {
    return _instance;
  }

  void openPlaidLink(
      BuildContext context,
      String plaidLink,
      PlaidLinkSuccessCallback onSuccess,
      PlaidLinkEventCallback onEvent,
      PlaidLinkErrorCallback onExit) {
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
