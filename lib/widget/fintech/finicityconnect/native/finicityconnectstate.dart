import 'package:ensemble/widget/fintech/finicityconnect/finicityconnect.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show Factory;
import 'package:webview_flutter/webview_flutter.dart';

class FinicityConnectState extends FinicityConnectStateBase {
  @override
  Widget buildWidget(BuildContext context) {
    if (widget.controller.uri == '') {
      return const Text("");
    }
    Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers = {
      Factory(() => EagerGestureRecognizer())
    };
    WebViewController webViewController = WebViewController()
      ..setBackgroundColor(Colors.transparent)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('messageHandler',
          onMessageReceived: (JavaScriptMessage message) {
        print('message inside finicity and the message is ${message.message}');
        executeAction(json.decode(message.message));
      });
    webViewController.loadRequest(Uri.parse(
        'https://studio.ensembleui.com/static/finicity.html?uri=${Uri.encodeComponent(widget.controller.uri)}'));
    return SizedBox(
        child: WebViewWidget(
            controller: webViewController,
            gestureRecognizers: gestureRecognizers));
  }
}
