import 'package:ensemble/util/chart_utils.dart';
import 'package:flutter/material.dart';
import 'package:js_widget/js_widget.dart';
import '../chart_js.dart';

class ChartJsState extends ChartJsStateBase {
  JsWidget? jsWidget;

  void evalScript(String script) {
    if (jsWidget == null) {
      print('evalScript is being called on a jsWidget which is null');
    } else {
      jsWidget!.evalScript(script);
    }
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
      scriptToInstantiate: (String c) => '''
        if (typeof ${widget.controller.chartVar} !== "undefined") ${widget.controller.chartVar}.destroy();
        ${widget.controller.chartVar} = new Chart(document.getElementById("${widget.controller.chartId}"), $c);
        ${widget.controller.chartVar}.update();
        
        document.getElementById("${widget.controller.chartId}").onclick = function(event) {
          ${ChartUtils.getClickEventScript(widget.controller.id!, isWeb: true)}
        };
      ''',
      size: Size(widget.controller.width.toDouble(),
          widget.controller.height.toDouble()),
      data: widget.controller.config,
      scripts: const ["https://cdn.jsdelivr.net/npm/chart.js"],
      listener: handleChartClick,
    );
    return jsWidget!;
  }
}
