import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';

class Highcharts extends StatefulWidget
    with Invokable, HasController<HighchartsController, HighchartsState> {
  static const type = 'HighCharts';
  Highcharts({Key? key}) : super(key: key);

  static const defaultSize = 200;

  final HighchartsController _controller = HighchartsController();
  @override
  HighchartsController get controller => _controller;

  @override
  State<StatefulWidget> createState() => HighchartsState();

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
      'width': (value) =>
          _controller.width = Utils.getInt(value, fallback: defaultSize),
      'height': (value) =>
          _controller.height = Utils.getInt(value, fallback: defaultSize),
      'data': (value) => _controller.data = Utils.getString(value, fallback: '')
    };
  }
}

class HighchartsController extends WidgetController {
  int width = Highcharts.defaultSize;
  int height = Highcharts.defaultSize;
  dynamic data = '';
}

class HighchartsState extends EWidgetState<Highcharts> {
  @override
  Widget buildWidget(BuildContext context) {
    return Text('High Chart is not supported in newer version of please use chartJs instead');
  }
}
