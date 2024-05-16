import 'package:flutter/material.dart';

///
///A generic library for exposing javascript widgets in Flutter webview.
///Took https://github.com/senthilnasa/high_chart as a start and genericized it
///
class JsWidget extends StatefulWidget {
  JsWidget(
      { required this.id,
        required this.createHtmlTag,
        required this.data,
        required this.scriptToInstantiate,
        required this.size,
        this.loader = const Center(child: CircularProgressIndicator()),
        this.scripts = const [],
        this.listener,
        this.preCreateScript,
        Key? key})
      : super(key: key);

  ///Custom `loader` widget, until script is loaded
  ///
  ///Has no effect on Web
  ///
  ///Defaults to `CircularProgressIndicator`
  final Widget loader;

  ///Chart data
  final String id;
  final Function scriptToInstantiate;
  final Function createHtmlTag;
  final Function? preCreateScript;
  final String data;
  Function(String msg)? listener;

  ///Widget size
  ///
  ///Height and width of the widget is required
  ///
  ///```dart
  ///Size size = Size(400, 400);
  ///```
  final Size size;

  ///Scripts to be loaded
  final List<String> scripts;
  @override
  JsState createState() => JsState();
  void evalScript(String script) {}
}
class JsState extends State<JsWidget> {
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text("JsWidget: UnSupported Platform"));
  }
}