import 'package:ensemble/util/chart_utils.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../chart_js.dart';

class ChartJsState extends ChartJsStateBase {
  late WebViewController _controller;

  @override
  void evalScript(String script) {
    _controller.runJavaScript('''
      try {
        if (typeof window.chart !== "undefined") {
          ${script.replaceAll(widget.controller.chartVar, "window.chart")}
        } else {
          console.error('Chart is not initialized');
          messageHandler.postMessage(JSON.stringify({error: 'Chart is not initialized'}));
        }
      } catch (error) {
        console.error('Script execution error:', error);
        messageHandler.postMessage(JSON.stringify({error: error.message}));
      }
    ''');
  }

  @override
  Widget buildWidget(BuildContext context) {
    if (widget.controller.config == '') return const Text("");

    _controller = WebViewController()
      ..setBackgroundColor(Colors.transparent)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'messageHandler',
        onMessageReceived: (JavaScriptMessage message) =>
            handleChartClick(message.message),
      )
      ..loadHtmlString(ChartUtils.getBaseHtml(
        widget.controller.chartId,
        widget.controller.config,
      ));

    return SizedBox(
      width: widget.controller.width.toDouble(),
      height: widget.controller.height.toDouble(),
      child: WebViewWidget(controller: _controller),
    );
  }
}
