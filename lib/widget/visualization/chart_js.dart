import 'dart:io';
import 'dart:math';

import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:ensemble_ts_interpreter/parser/newjs_interpreter.dart';
import 'package:flutter/material.dart';
import 'package:js_widget/js_widget.dart';
import 'dart:convert';

class ChartJsController extends WidgetController {
  ChartJsController() {
    id = 'chartJs_' + (Random().nextInt(900000) + 100000).toString();
  }
  int width = ChartJs.defaultSize;
  int height = ChartJs.defaultSize;
  String get chartVar => 'myChart$id';
  String get chartDiv => 'div_$id';
  String get chartId => id!;
  dynamic config = '';
  Function? evalScript;
}

class ChartJs extends StatefulWidget
    with Invokable, HasController<ChartJsController, ChartJsState> {
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
    return {
      'addLabels': (List labels) {
        String labelsArr = jsonEncode(labels);
        String script = '''
        if ( !${controller.chartVar} ) {
          alert('chart var ${controller.chartVar} for chart with id=$id does not exist');
        }
        ${controller.chartVar}.data.labels.push(...$labelsArr);
        ''';
        if (controller.evalScript == null) {
          throw Exception(
              'Chartjs.addLabels: evalScript is being called on null as it has not yet been set by the state. ');
        }
        controller.evalScript!(script);
      },
      'addData': (int dataSet, List data) {
        String dataArr = jsonEncode(data);
        String script = '''
          
          if ( !${controller.chartVar} ) {
            alert('chart var ${controller.chartVar} for chart with id=$id does not exist');
          } else if ( $dataSet >= ${controller.chartVar}.data.datasets.length ) {
            alert('chart with id=$id only has '+${controller.chartVar}.data.datasets.length+' datasets.');
          } else {
            ${controller.chartVar}.data.datasets[$dataSet].data.push(...$dataArr);
          }
        ''';
        if (controller.evalScript == null) {
          throw Exception(
              'Chartjs.addData: evalScript is being called on null as it has not yet been set by the state. ');
        }
        controller.evalScript!(script);
      },
      'update': () {
        String script = '''
            if ( !${controller.chartVar} ) {
              alert('chart var ${controller.chartVar} for chart with id=$id does not exist');
            }
            ${controller.chartVar}.update();
          ''';
        if (controller.evalScript == null) {
          throw Exception(
              'Chartjs.update: evalScript is being called on null as it has not yet been set by the state. ');
        }
        controller.evalScript!(script);
      }
    };
  }

  @override
  Map<String, Function> setters() {
    return {
      'id': (value) =>
          _controller.id = Utils.getString(value, fallback: _controller.id!),
      'width': (value) =>
          _controller.width = Utils.getInt(value, fallback: defaultSize),
      'height': (value) =>
          _controller.height = Utils.getInt(value, fallback: defaultSize),
      'config': (value) {
        if (value is Map) {
          _controller.config = JSInterpreter.toJSString(value);
        } else {
          _controller.config = value;
        }
      }
    };
  }
}

class ChartJsState extends WidgetState<ChartJs> {
  JsWidget? jsWidget;
  void evalScript(String script) {
    if (jsWidget == null) {
      print('evalScript is being called on a jsWidget which is null');
    } else {
      jsWidget!.evalScript(script);
    }
  }

  @override
  void initState() {
    widget.controller.evalScript = evalScript;
    super.initState();
  }

  @override
  void dispose() {
    widget.controller.evalScript = null;
    super.dispose();
  }

  @override
  Widget buildWidget(BuildContext context) {
    if (widget.controller.config == '') {
      return const Text("");
    }
    jsWidget = JsWidget(
      id: widget.controller.id!,
      createHtmlTag: () =>
          '<div id="${widget.controller.chartDiv}"><canvas id="${widget.controller.chartId}"></canvas></div>',
      scriptToInstantiate: (String c) {
        return 'if (typeof ${widget.controller.chartVar} !== "undefined") ${widget.controller.chartVar}.destroy();${widget.controller.chartVar} = new Chart(document.getElementById("${widget.controller.chartId}"), $c);${widget.controller.chartVar}.update();';
      },
      size: Size(widget.controller.width.toDouble(),
          widget.controller.height.toDouble()),
      data: widget.controller.config,
      scripts: const [
        "https://cdn.jsdelivr.net/npm/chart.js",
      ],
    );
    return jsWidget!;
  }
}
