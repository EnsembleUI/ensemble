import 'dart:math';

import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:ensemble_ts_interpreter/parser/newjs_interpreter.dart';
import 'package:flutter/cupertino.dart';
import 'package:js_widget/js_widget.dart';

class TopologyChartController extends WidgetController {
  TopologyChartController() {
    id = 'topologychart_' + (Random().nextInt(900000) + 100000).toString();
  }
  double width = TopologyChart.defaultSize;
  double height = TopologyChart.defaultSize;
  String get chartVar => 'chartvar_$id';
  String get chartDiv => 'div_$id';
  String get chartId => id!;
  dynamic config = '';
}

class TopologyChart extends StatefulWidget
    with Invokable, HasController<TopologyChartController, TopologyChartState> {
  static const type = 'TopologyChart';
  @override
  final TopologyChartController controller = TopologyChartController();
  static const double defaultSize = 1000;
  TopologyChart({super.key});

  @override
  State<StatefulWidget> createState() => TopologyChartState();

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
      'id': (value) =>
          controller.id = Utils.getString(value, fallback: controller.id!),
      'width': (value) =>
          controller.width = Utils.getDouble(value, fallback: defaultSize),
      'height': (value) =>
          controller.height = Utils.getDouble(value, fallback: defaultSize),
      'config': (value) {
        if (value is Map) {
          controller.config = JSInterpreter.toJSString(value);
        } else {
          controller.config = value;
        }
      }
    };
  }
}

class TopologyChartState extends WidgetState<TopologyChart> {
  @override
  Widget buildWidget(BuildContext context) {
    if (widget.controller.config == '') {
      return const Text("");
    }
    return JsWidget(
      id: widget.controller.id!,
      createHtmlTag: () =>
          '<div id="${widget.controller.chartDiv}" class="main-wrapper main-section"></div>',
      preCreateScript: () => 'removeChart("${widget.controller.chartDiv}")',
      scriptToInstantiate: (String c) {
        return 'buildElement("${widget.controller.chartDiv}",$c)';
      },
      size: Size(widget.controller.width.toDouble(),
          widget.controller.height.toDouble()),
      data: widget.controller.config,
      scripts: const [
        "https://cdn.jsdelivr.net/npm/chart.js",
      ],
    );
  }
}
