import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/widget/webview/webview.dart';
import 'package:flutter/material.dart';

class WebViewState extends EWidgetState<EnsembleWebView> {
  double? height = 0;

  @override
  Widget buildWidget(BuildContext context) {
    return const Text("WebView is not supported on this platform");
  }
}
