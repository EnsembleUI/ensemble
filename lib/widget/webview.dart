import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:webview_flutter/webview_flutter.dart';

class EnsembleWebView extends StatefulWidget with Invokable, HasController<MyController, WebViewState> {
  static const type = 'WebView';
  EnsembleWebView({Key? key}) : super(key: key);

  final MyController _controller = MyController();
  @override
  get controller => _controller;

  @override
  State<StatefulWidget> createState() => WebViewState();

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
      'uri': (value) => _controller.uri = Utils.optionalString(value)
    };
  }
}

class MyController extends WidgetController {
  String? uri;
}

class WebViewState extends WidgetState<EnsembleWebView> {
  double height = 0.0;
  WebViewController? viewController;

  @override
  Widget build(BuildContext context) {
    return
      SizedBox(
        height: height,
        child: WebView(
          initialUrl: widget._controller.uri,
          javascriptMode: JavascriptMode.unrestricted,
          onWebViewCreated: (controller) => viewController = controller,
          onPageFinished: (param) async {
            height = double.parse(
                await viewController!.runJavascriptReturningResult(
                    "document.documentElement.scrollHeight;"));
            setState(() {

            });

          })
        );

  }

}