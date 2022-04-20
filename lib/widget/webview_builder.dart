import 'package:ensemble/page_model.dart';
import 'package:ensemble/widget/widget_builder.dart' as ensemble;
import 'package:ensemble/widget/widget_registry.dart';
import 'package:flutter/cupertino.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebViewBuilder extends ensemble.WidgetBuilder {
  static const type = 'WebView';
  WebViewBuilder({
    this.uri,
    styles
  }): super(styles: styles);
  String? uri;

  static WebViewBuilder fromDynamic(Map<String, dynamic> props, Map<String, dynamic> styles, {WidgetRegistry? registry})
  {
    return WebViewBuilder(
      // props
      uri: props['uri'].toString(),
      // styles
      styles: styles
    );
  }

  @override
  Widget buildWidget({
    List<Widget>? children,
    ItemTemplate? itemTemplate}) {
    return EnsembleWebView(builder: this);
  }

}

class EnsembleWebView extends StatefulWidget {
  const EnsembleWebView({
    required this.builder,
    Key? key
  }) : super(key: key);

  final WebViewBuilder builder;

  @override
  State<StatefulWidget> createState() => WebViewState();
}

class WebViewState extends State<EnsembleWebView> {
  double height = 0.0;
  WebViewController? viewController;

  @override
  Widget build(BuildContext context) {
    return
      SizedBox(
        height: height,
        child: WebView(
          initialUrl: widget.builder.uri,
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