import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../framework/action.dart';
import '../../screen_controller.dart';
import '../../util/utils.dart';

class TabaPayConnectController extends WidgetController {
  String uri =
      "https://developers.tabapay.com/reference/iframe-implementation-starter-guide";
  double? width;
  double? height;
  EnsembleAction? onSuccess;
  EnsembleAction? onCancel;
  EnsembleAction? onError;
}

class TabaPayConnect extends StatefulWidget
    with
        Invokable,
        HasController<TabaPayConnectController, TabaPayConnectState> {
  static const type = 'TabaPay';

  final _controller = TabaPayConnectController();

  @override
  TabaPayConnectController get controller => _controller;

  @override
  State<StatefulWidget> createState() => TabaPayConnectState();

  @override
  Map<String, Function> getters() {
    return {};
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {
      'id': (value) =>
          _controller.id = Utils.getString(value, fallback: _controller.id!),
      'uri': (value) =>
          _controller.uri = Utils.getString(value, fallback: _controller.uri),
      'width': (value) =>
          _controller.width = Utils.getDouble(value, fallback: 0),
      'height': (value) =>
          _controller.height = Utils.getDouble(value, fallback: 0),
      'onSuccess': (funcDefinition) => _controller.onSuccess =
          EnsembleAction.from(funcDefinition, initiator: this),
      'onCancel': (funcDefinition) => _controller.onCancel =
          EnsembleAction.from(funcDefinition, initiator: this),
      'onError': (funcDefinition) => _controller.onError =
          EnsembleAction.from(funcDefinition, initiator: this),
    };
  }
}

class TabaPayConnectState extends EWidgetState<TabaPayConnect> {
  WebViewController? _webViewController;

  @override
  Widget buildWidget(BuildContext context) {
    if (widget.controller.uri == '') {
      return const Text("");
    }
    Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers = {
      Factory(() => EagerGestureRecognizer())
    };
    if (_webViewController == null) {
      _webViewController = WebViewController();
      _webViewController
        ?..setBackgroundColor(Colors.transparent)
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..addJavaScriptChannel('messageHandler',
            onMessageReceived: _handleTabaPayMessage)
        ..setNavigationDelegate(
            NavigationDelegate(onPageFinished: (String url) {
          _webViewController?.runJavaScript(
              'window.addEventListener("message", (event) => messageHandler.postMessage(event.data))');
        }));
      _webViewController?.loadRequest(Uri.parse(widget.controller.uri));
    }

    double height = MediaQuery.of(context).size.height;
    var padding = MediaQuery.of(context).viewPadding;
    double safeHeight = height - padding.top - padding.bottom;
    return SizedBox(
        width: widget.controller.width,
        height: widget.controller.height ?? safeHeight,
        child: WebViewWidget(
            controller: _webViewController!,
            gestureRecognizers: gestureRecognizers));
  }

  void _handleTabaPayMessage(JavaScriptMessage jsMessage) {
    final message = jsMessage.message;
    // https://developers.tabapay.com/reference/iframe-implementation-starter-guide#function-to-handle-return-from-tabapay-iframe
    if (message == "Close") {
      _executeAction(widget._controller.onCancel, {});
    } else if (message.startsWith("Error: ")) {
      _executeAction(widget._controller.onError, {'message': message});
    } else {
      final parts = message.split("|");
      if (parts.length != 4) {
        _executeAction(widget._controller.onError,
            {'message': 'Unexpected response from TabaPay'});
      } else {
        var lastDigits = parts[0];
        var expiration = parts[1];
        var token = parts[2];
        var zipCode = parts[3];

        _executeAction(widget._controller.onSuccess, {
          'last4': lastDigits,
          'expiration': expiration,
          'token': token,
          'zipCode': zipCode,
          'data': message
        });
      }
    }
  }

  void _executeAction(EnsembleAction? action, Map<String, dynamic> payload) {
    if (action == null) {
      return;
    }
    ScreenController().executeAction(context, action,
        event: EnsembleEvent(widget, data: payload));
  }
}
