import 'package:high_chart/high_chart.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/widget/widget_builder.dart' as ensemble;
import 'package:ensemble/widget/widget_registry.dart';
import 'package:flutter/material.dart';

class ChartPieBuilder extends ensemble.WidgetBuilder {
  static const type = 'PieChart';
  ChartPieBuilder({
    this.size = 200,
  });

  int? size;





  static ChartPieBuilder fromDynamic(Map<String, dynamic> props, Map<String, dynamic> styles, {WidgetRegistry? registry})
  {
    return ChartPieBuilder(
      // props


      // styles
      size: props['size']
    );
  }

  String getChartData() {
    return '''{  
      chart: {
        type: 'pie'
      },
      plotOptions: {
        pie: {
            size: $size,
            innerSize: '0%',
            borderWidth: 4,
            borderColor: '#FFF',
            dataLabels: {
                enabled: false
            }
        }
      },
      credits: {
        enabled: false
      },
      title: {
        text: 'Take home<br> \$500',
        //floating: true, 
        //verticalAlign: 'middle',
      },
      series: [{
          data: [
            { name: 'Take home', y: 23, color: '#8AC5A8'},
            { name: 'Taxes', y: 23, color: '#DBD4B7'},
            { name: 'Benefits', y: 23, color: '#FFE7B9'},
            { name: 'Retirement', y: 23, color: '#AAD6DE'}
          ]
        }]
    }''';
  }


  @override
  Widget buildWidget({
    required BuildContext context,
    List<Widget>? children,
    ItemTemplate? itemTemplate}) {
    return EnsemblePieChart(builder: this);
  }

}

class EnsemblePieChart extends StatefulWidget {
  const EnsemblePieChart({
    required this.builder,
    Key? key
  }) : super(key: key);

  final ChartPieBuilder builder;

  @override
  State<StatefulWidget> createState() => PieChartState();
}

class PieChartState extends State<EnsemblePieChart> {
  @override
  Widget build(BuildContext context) {
    return HighCharts(
          loader: const SizedBox(
            child: LinearProgressIndicator(),
            width: 200,
          ),
          size: const Size(400, 280),
          data: widget.builder.getChartData(),
          scripts: const [
            'https://code.highcharts.com/highcharts.js',
            'https://code.highcharts.com/modules/networkgraph.js'
          ],
        );

  }


}