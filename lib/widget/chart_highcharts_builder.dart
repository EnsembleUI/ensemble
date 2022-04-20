import 'package:high_chart/high_chart.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/widget/widget_builder.dart' as ensemble;
import 'package:ensemble/widget/widget_registry.dart';
import 'package:flutter/material.dart';

class ChartHighChartsBuilder extends ensemble.WidgetBuilder {
  static const type = 'HighCharts';
  ChartHighChartsBuilder({
    required this.data,
    this.width = 200,
    this.height = 200,
    styles
  }): super(styles: styles);

  int? width;
  int? height;
  dynamic data;





  static ChartHighChartsBuilder fromDynamic(Map<String, dynamic> props, Map<String, dynamic> styles, {WidgetRegistry? registry})
  {
    return ChartHighChartsBuilder(
      // props
      data: props['data'],

      // styles
      width: styles['width'],
      height: styles['height'],
      styles: styles
    );
  }



  @override
  Widget buildWidget({
    List<Widget>? children,
    ItemTemplate? itemTemplate}) {
    return EnsembleHighCharts(builder: this);
  }

}

class EnsembleHighCharts extends StatefulWidget {
  const EnsembleHighCharts({
    required this.builder,
    Key? key
  }) : super(key: key);

  final ChartHighChartsBuilder builder;

  @override
  State<StatefulWidget> createState() => HighChartsState();
}

class HighChartsState extends State<EnsembleHighCharts> {
  @override
  Widget build(BuildContext context) {
    return HighCharts(
      loader: const SizedBox(
        child: LinearProgressIndicator(),
        width: 200,
      ),
      size: Size(widget.builder.width!.toDouble(), widget.builder.height!.toDouble()),
      data: widget.builder.data,
      scripts: const [
        'https://code.highcharts.com/highcharts.js',
        'https://code.highcharts.com/highcharts-more.js'
      ],
    );
  }


}