import 'dart:math';

import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'package:js_widget/js_widget.dart';
import 'dart:convert';

class ChartJsController extends WidgetController {
  int width = ChartJs.defaultSize;
  int height = ChartJs.defaultSize;
  String id = 'chartJs_'+(Random().nextInt(900000) + 100000).toString();
  String get chartVar => 'myChart$id';
  String get chartDiv => 'div_$id';
  String get chartId => id;
  dynamic config = '';

}
class ChartJs extends StatefulWidget with Invokable, HasController<ChartJsController, ChartJsState> {
  static const type = 'ChartJs';
  ChartJs({Key? key}) : super(key: key);

  static const defaultSize = 200;

  final ChartJsController _controller = ChartJsController();
  @override
  ChartJsController get controller => _controller;

  @override
  State<StatefulWidget> createState() => ChartJsState();

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
      'config': (value) {
        if ( value is Map ) {
          _controller.config = json.encode(value);
        } else {
          _controller.config = value;
        }
      }
    };
  }
}
class ChartJsState extends WidgetState<ChartJs> {
  @override
  Widget build(BuildContext context) {
    if ( widget.controller.config == '')  {
      return Text("Still Loading...");
    }
    return JsWidget(
      id: widget.controller.id,
      createHtmlTag: () => '<div id="${widget.controller.chartDiv}"><canvas id="${widget.controller.chartId}"></canvas></div>',
      scriptToInstantiate: (String c) {
        return 'if (typeof ${widget.controller.chartVar} !== "undefined") ${widget.controller.chartVar}.destroy();${widget.controller.chartVar} = new Chart(document.getElementById("${widget.controller.chartId}"), $c);${widget.controller.chartVar}.update();';
      },

      size: Size(widget.controller.width.toDouble(), widget.controller.height.toDouble()),
      data: widget.controller.config,
      scripts: const [
        "https://cdn.jsdelivr.net/npm/chart.js",
      ],
    );
  }
}