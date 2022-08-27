import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'package:js_widget/js_widget.dart';

class ChartJsController extends WidgetController {
  int width = ChartJs.defaultSize;
  int height = ChartJs.defaultSize;
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
      'width': (value) => _controller.width = Utils.getInt(value, fallback: defaultSize),
      'height': (value) => _controller.height = Utils.getInt(value, fallback: defaultSize),
      'config': (value) => _controller.config = Utils.getString(value, fallback: '')
    };
  }
}
class ChartJsState extends WidgetState<ChartJs> {
  @override
  Widget build(BuildContext context) {
    return JsWidget(
      createHtmlTag: (
          [htmlId = 'chartJs']) => ''' <canvas id="$htmlId"></canvas>''',
      scriptToInstantiate: (String c,
          [htmlId = 'chartJs']) => '''const myChart = new Chart(document.getElementById('$htmlId'),$c);''',

      size: Size(widget.controller.width.toDouble(), widget.controller.height.toDouble()),
      data: widget.controller.config,
      scripts: const [
        "https://cdn.jsdelivr.net/npm/chart.js",
      ],
    );
  }
}