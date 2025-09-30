import 'package:ensemble/widget/visualization/chart_defaults.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class LineChartProperties {
  bool asArea = false;
  bool curved = false;
  final double minY, maxY;
  LineChartProperties(this.minY, this.maxY);
}

class EnsembleLineChartController extends Controller {
  String? _title;
  String? get title => _title;
  set title(String? t) {
    _title = t;
    dispatchChanges(KeyValue('title', _title));
  }

  List<String> _labels = [];
  List<String> get labels => _labels;
  set labels(List<String> l) {
    _labels = l;
    dispatchChanges(KeyValue('labels', _labels));
  }

  List metaData = [];
  bool isDirty = false;
  void setMetaData(List metaData) {
    this.metaData = metaData;
    isDirty = true;
  }

  List<LineChartBarData> _data = [];
  List<LineChartBarData> get data {
    if (!isDirty) {
      return _data;
    }
    List<LineChartBarData> chartData = [];
    for (Map m in metaData) {
      LineChartBarData lineData;
      Color? color;
      List<FlSpot> spots = [];
      int colorValue = 0;
      m.forEach((key, value) {
        if (key == 'color') {
          colorValue = value;
          color = Color(colorValue);
        } else if (key == 'data') {
          for (var i = 0; i < (value as List).length; i++) {
            dynamic metaValue = value[i];
            double val;
            if (metaValue is int) {
              val = metaValue.toDouble();
            } else if (metaValue is String) {
              val = double.parse(metaValue);
            } else if (metaValue is double) {
              val = metaValue;
            } else {
              throw Exception(
                  "Only double values are allowed for data in linecharts");
            }
            spots.add(FlSpot(i.toDouble(), val));
          }
        }
      });
      chartData.add(LineChartBarData(
          isCurved: properties.curved,
          color: color,
          barWidth: 2,
          isStrokeCapRound: true,
          dotData: FlDotData(show: false),
          belowBarData: BarAreaData(
              show: properties.asArea,
              color: Color(colorValue).withValues(alpha: 0.2)),
          spots: spots));
    }
    isDirty = false;
    data = chartData;
    return _data;
  }

  set data(List<LineChartBarData> l) {
    _data = l;
    dispatchChanges(KeyValue('data', _data));
  }

  late LineChartProperties _properties;
  LineChartProperties get properties => _properties;
  set properties(LineChartProperties props) {
    _properties = props;
    isDirty = true;
    dispatchChanges(KeyValue('properties', _properties));
  }
}

class EnsembleLineChartState extends BaseWidgetState<EnsembleLineChart>
    with ChartDefaults {
  final EnsembleLineChartController controller;
  EnsembleLineChartState(this.controller);
  @override
  Widget build(BuildContext context) {
    if (controller.labels.isEmpty) {
      //widget's data has not yet been initialized, we'll skip
      return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const <Widget>[
            SizedBox(
              height: 4,
            ),
            Text("Loading..."),
            SizedBox(
              height: 4,
            )
          ]);
    }
    return AspectRatio(
      aspectRatio: 1.30,
      child: Container(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(18)),
          gradient: LinearGradient(
            colors: [
              Color(0xFFFFFFFF),
              Color(0xFFFFFFFF),
            ],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
        ),
        child: Stack(
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(
                  height: 4,
                ),
                Text(
                  (controller.title != null) ? controller.title! : "",
                  style: const TextStyle(
                    color: Color(0xff827daa),
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(
                  height: 4,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 2.0, left: 2.0),
                    child: LineChart(LineChartData(
                      lineTouchData: lineTouchData,
                      gridData: gridData,
                      titlesData: titlesData(controller.labels),
                      borderData: borderData,
                      lineBarsData: controller.data,
                      minX: 0,
                      maxX: (controller.labels.length - 1).toDouble(),
                      maxY: controller.properties.maxY,
                      minY: controller.properties.minY,
                    )),
                  ),
                ),
                const SizedBox(
                  height: 4,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class EnsembleLineChart extends StatefulWidget
    with
        Invokable,
        HasController<EnsembleLineChartController, EnsembleLineChartState> {
  static const type = 'LineChart';
  final EnsembleLineChartController _controller = EnsembleLineChartController();
  EnsembleLineChart({Key? key}) : super(key: key);
  @override
  EnsembleLineChartController get controller => _controller;

  @override
  EnsembleLineChartState createState() => EnsembleLineChartState(controller);

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
      "title": (Object t) => this.controller.title = getString(t),
      "labels": (Object mLabels) {
        List? metaLabels = getList(mLabels);
        if (metaLabels == null) {
          throw Exception('LineChart.data must be a list but is not');
        }
        List<String> labels = [];
        for (Object node in metaLabels) {
          labels.add(getString(node)!);
        }
        controller.labels = labels;
      },
      "properties": (Object mProps) {
        Map? metaProps = getMap(mProps);
        if (metaProps == null) {
          throw Exception(
              "Properties cannot be set ot null and must be set to a map");
        }
        if (metaProps['minY'] == null || metaProps['maxY'] == null) {
          throw Exception('both minY and maxY must be specified for lincharts');
        }
        LineChartProperties props = LineChartProperties(
            metaProps['minY'].toDouble(), metaProps['maxY'].toDouble());
        if (metaProps['asArea']) {
          props.asArea = metaProps['asArea'] as bool;
        }
        if (metaProps['curved']) {
          props.curved = metaProps['curved'] as bool;
        }
        controller.properties = props;
      },
      "data": (Object data) {
        List? l = getList(data);
        if (l == null) {
          throw Exception('LineChart.data must be a list but is not');
        }
        controller.setMetaData(l);
      }
    };
  }
}
/*
  LineChartBarData get lineChartBarData1_3 => LineChartBarData(
    isCurved: true,
    color: const Color(0xff27b6fc),
    barWidth: 2,
    isStrokeCapRound: true,
    dotData: FlDotData(show: false),
    belowBarData: BarAreaData(show: true,
        color: const Color(0xff27b6fc).withValues(alpha: 0.5)),
    spots: const [
      FlSpot(1, 2.8),
      FlSpot(3, 1.9),
      FlSpot(6, 3),
      FlSpot(10, 1.3),
      FlSpot(13, 2.5),
    ],
  );
 */
