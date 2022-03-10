import 'package:high_chart/high_chart.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/widget/widget_builder.dart' as ensemble;
import 'package:ensemble/widget/widget_registry.dart';
import 'package:flutter/material.dart';

class ChartBubbleBuilder extends ensemble.WidgetBuilder {
  static const type = 'BubbleChart';
  ChartBubbleBuilder();

  final String _chartData = '''{  
      chart: {
        type: 'packedbubble',
        width: 400,
        height: 400,
      },
      plotOptions: {
        packedbubble: {
            minSize: '40',
            maxSize: '140%',
            layoutAlgorithm: {
                splitSeries: false,
                gravitationalConstant: 0.02
            },
            dataLabels: {
                enabled: true,
                format: '',
                filter: {
                    property: 'y',
                    operator: '>',
                    value: 250
                },
                style: {
                    color: 'black',
                    textOutline: 'none',
                    fontWeight: 'normal'
                }
            }
        }
      },
      credits: {
        enabled: false
      },
      title: {
        text: null,
      },
      series: [
        {
            showInLegend: false, 
            data: [
                { name: 'Take home', value: 4025.13, color: '#8AC5A8'},
                { name: 'Taxes', value: 12485.34, color: '#DBD4B7'},
                { name: 'Benefits', value: 678.47, color: '#FFE7B9'},
                { name: 'Retirement', value: 325.12, color: '#AAD6DE'}
            ]
        }
      ]
    }''';


  static ChartBubbleBuilder fromDynamic(Map<String, dynamic> props, Map<String, dynamic> styles, {WidgetRegistry? registry})
  {
    return ChartBubbleBuilder(
      // props


      // styles
    );
  }


  @override
  Widget buildWidget({
    required BuildContext context,
    List<Widget>? children,
    ItemTemplate? itemTemplate}) {
    return BubbleChart(builder: this);
  }

}

class BubbleChart extends StatefulWidget {
  const BubbleChart({
    required this.builder,
    Key? key
  }) : super(key: key);

  final ChartBubbleBuilder builder;

  @override
  State<StatefulWidget> createState() => BubbleChartState();
}

class BubbleChartState extends State<BubbleChart> {
  @override
  Widget build(BuildContext context) {
    return HighCharts(
          loader: const SizedBox(
            child: LinearProgressIndicator(),
            width: 200,
          ),
          size: const Size(450, 450),
          data: widget.builder._chartData,
          scripts: const [
            'https://code.highcharts.com/highcharts.js',
            'https://code.highcharts.com/highcharts-more.js'
          ],
        );

  }


}