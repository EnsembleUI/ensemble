import 'package:flutter/material.dart';
import 'package:js_widget/js_widget.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: ExampleChart());
  }
}

class ExampleChart extends StatefulWidget {
  const ExampleChart({Key? key}) : super(key: key);
  final String id = "chartJs";
  @override
  ExampleChartState createState() => ExampleChartState();
}

class ExampleChartState extends State<ExampleChart> {
  final String config = '''
    {
    type: 'line',
    data: {
      labels: [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
    ],
    datasets: [{
      label: 'My First dataset',
      backgroundColor: 'rgb(255, 99, 132)',
      borderColor: 'rgb(255, 99, 132)',
      data: [0, 10, 5, 2, 20, 30, 45],
    }]
  },
    options: {}
  }''';
  final String _chartData = '''
  const labels = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
  ];

  const data = {
    labels: labels,
    datasets: [{
      label: 'My First dataset',
      backgroundColor: 'rgb(255, 99, 132)',
      borderColor: 'rgb(255, 99, 132)',
      data: [0, 10, 5, 2, 20, 30, 45],
    }]
  };

  const config = {
    type: 'line',
    data: {
      labels: [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
    ],
    datasets: [{
      label: 'My First dataset',
      backgroundColor: 'rgb(255, 99, 132)',
      borderColor: 'rgb(255, 99, 132)',
      data: [0, 10, 5, 2, 20, 30, 45],
    }]
  },
    options: {}
  };
  
  ''';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        centerTitle: true,
        title: const Text('ChartJs Example App'),
      ),
      body: JsWidget(
        id: widget.id,
        createHtmlTag: () =>
            ''' <div style="height:100%;width:100%;" id="${widget.id}Div"><canvas id="${widget.id}"></canvas></div>''',
        scriptToInstantiate: (String c, [htmlId = 'chartJs']) =>
            '''const myChart = new Chart(document.getElementById('${widget.id}'),$c);''',
        loader: const SizedBox(
          child: LinearProgressIndicator(),
          width: 200,
        ),
        size: const Size(400, 400),
        data: config,
        scripts: const [
          "https://cdn.jsdelivr.net/npm/chart.js",
        ],
      ),
    );
  }
}
