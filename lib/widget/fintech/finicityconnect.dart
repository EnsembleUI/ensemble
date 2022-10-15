import 'dart:math';

import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:ensemble_ts_interpreter/parser/newjs_interpreter.dart';
import 'package:flutter/material.dart';
import 'package:js_widget/js_widget.dart';
import 'dart:convert';

class FinicityConnectController extends WidgetController {
  int width = 325;
  int height = 755;
  String id = 'finicityConnect';
  String uri = '';
}
class FinicityConnect extends StatefulWidget with Invokable, HasController<FinicityConnectController, FinicityConnectState> {
  static const type = 'FinicityConnect';
  FinicityConnect({Key? key}) : super(key: key);

  static const defaultSize = 200;

  final FinicityConnectController _controller = FinicityConnectController();
  @override
  FinicityConnectController get controller => _controller;

  @override
  State<StatefulWidget> createState() => FinicityConnectState();

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
      'id': (value) => _controller.id = Utils.getString(value, fallback: _controller.id),
      'width': (value) => _controller.width = Utils.getInt(value, fallback: defaultSize),
      'height': (value) => _controller.height = Utils.getInt(value, fallback: defaultSize),
      'uri': (value) => _controller.uri = Utils.getString(value, fallback: _controller.uri)
    };
  }
}
class FinicityConnectState extends WidgetState<FinicityConnect> {
  @override
  Widget buildWidget(BuildContext context) {
    if ( widget.controller.uri == '')  {
      return Text("Still Loading...");
    }
    return JsWidget(
      id: widget.controller.id,
      createHtmlTag: () => '<div></div>',
      scriptToInstantiate: (String c) {

        return '''window.finicityConnect.launch("$c", {
        selector: '#connect-container',
        overlay: 'rgba(255,255,255, 0)',
        success: (event) => {
          console.log('Yay! User went through Connect', event);
        }});
        ''';
        //return 'if (typeof ${widget.controller.chartVar} !== "undefined") ${widget.controller.chartVar}.destroy();${widget.controller.chartVar} = new Chart(document.getElementById("${widget.controller.chartId}"), $c);${widget.controller.chartVar}.update();';
      },
      size: Size(widget.controller.width.toDouble(), widget.controller.height.toDouble()),
      data: widget.controller.uri,
      scripts: const [
        "https://connect2.finicity.com/assets/sdk/finicity-connect.min.js",
      ],
    );
  }
}