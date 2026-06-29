import 'dart:async';
// ignore: deprecated_member_use
import 'dart:html' as html;
import 'dart:ui_web' as ui;

import 'package:flutter/material.dart';

import 'js.dart';

///
///A generic library for exposing javascript widgets in Flutter webview.
///Took https://github.com/senthilnasa/high_chart as a start and genericized it
///
class JsWidget extends StatefulWidget {
  JsWidget(
      {required this.id,
      required this.createHtmlTag,
      required this.data,
      required this.scriptToInstantiate,
      required this.size,
      this.loader = const CircularProgressIndicator(),
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

  ///Widget data
  final String id;
  final Function scriptToInstantiate;
  final Function createHtmlTag;
  final Function? preCreateScript;
  final String data;
  final Function(String msg)? listener;

  ///Widget size
  ///
  ///Height and width of the widget is required
  ///
  ///```dart
  ///Size size = Size(400, 300);
  ///```
  final Size size;

  ///Scripts to be loaded
  final List<String> scripts;
  @override
  JsWidgetState createState() => JsWidgetState();
  void evalScript(String script) {
    eval(script);
  }
}

class JsWidgetState extends State<JsWidget> {
  static Map<String, Function(String msg)> listeners = {};
  static void addListener(String id, Function(String msg) listener) {
    listeners[id] = listener;
  }

  static Function(String msg)? removeListenersWithId(String id) {
    return listeners.remove(id);
  }

  static Function(String msg)? removeListener(
      String id, Function(String msg) listener) {
    for (int i = listeners.keys.length - 1; i >= 0; i--) {
      if (listeners[listeners.keys.elementAt(i)] == listener) {
        return listeners.remove(listeners.keys.elementAt(i));
      }
    }
    return null;
  }

  static void globalListener(String id, String msg) {
    if (listeners.containsKey(id)) {
      Function(String msg) f = listeners[id]!;
      f.call(msg);
    }
  }

  @override
  void didUpdateWidget(covariant JsWidget oldWidget) {
    if (oldWidget.data != widget.data ||
        oldWidget.size != widget.size ||
        oldWidget.scripts != widget.scripts ||
        oldWidget.loader != widget.loader) {
      _load();
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void initState() {
    if (widget.listener != null) {
      addListener(widget.id, widget.listener!);
      init(globalListener);
    }
    if (widget.preCreateScript != null) {
      eval(widget.preCreateScript!());
    }
    _load();

    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(widget.id, (int viewId) {
      final html.Element element = html.Element.html(widget.createHtmlTag());
      return element;
    });
    super.initState();
  }

  @override
  void dispose() {
    removeListenersWithId(widget.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
        height: widget.size.height,
        width: widget.size.width,
        child: HtmlElementView(viewType: widget.id));
  }

  Future<bool> _load() {
    return Future<bool>.delayed(const Duration(milliseconds: 250), () {
      String? str = widget.scriptToInstantiate(widget.data);
      if (str != null && str.isNotEmpty) {
        eval(str);
      }
      return true;
    });
  }
}
