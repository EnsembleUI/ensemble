import 'dart:convert';

import 'package:meta/meta.dart';

class ChartUtils {
  static final RegExp _safeChartId = RegExp(r'^[a-zA-Z0-9_]+$');

  /// Returns true when [chartId] is safe to embed in HTML attributes and JS.
  @visibleForTesting
  static bool isSafeChartId(String chartId) => _safeChartId.hasMatch(chartId);

  /// Builds a JavaScript expression that evaluates to a Chart.js config object.
  ///
  /// Map-based configs may include author-defined JavaScript callbacks and are
  /// emitted as trusted object literals. String configs are validated as JSON
  /// and emitted via [jsonEncode] to prevent eval injection.
  @visibleForTesting
  static String buildSafeChartConfigExpression(
    String config, {
    required bool configFromMap,
  }) {
    if (configFromMap) {
      return config;
    }
    if (config.isEmpty) {
      return '{}';
    }
    try {
      final parsed = jsonDecode(config);
      return jsonEncode(parsed);
    } catch (_) {
      return '{}';
    }
  }

  static String getClickEventScript(String chartId, {bool isWeb = false}) {
    // For web, we use the chart variable name pattern
    final chartReference = isWeb ? 'myChart$chartId' : 'window.chart';
    
    String messageHandler = isWeb 
        ? 'window.handleMessage(\'$chartId\', JSON.stringify(dataCollection));'
        : 'messageHandler.postMessage(JSON.stringify(dataCollection));';

    return '''
      try {
        var activePoints = $chartReference.getElementsAtEventForMode(event, 'nearest', { intersect: true }, true);
        if (activePoints.length > 0) {
          var firstPoint = activePoints[0];
          var datasetIndex = firstPoint.datasetIndex;
          var index = firstPoint.index;
          var dataset = $chartReference.data.datasets[datasetIndex] || {};
          var dataCollection = { 
            data: {
              label: $chartReference.data.labels[index] || '',
              value: dataset.data ? dataset.data[index] : '',
              datasetLabel: dataset.label || '',
              datasetIndex: datasetIndex,
              index: index,
              backgroundColor: dataset.backgroundColor || '',
              borderColor: dataset.borderColor || '',
              x: firstPoint.element.x || 0,
              y: firstPoint.element.y || 0,
              chartType: $chartReference.config.type || '',
              options: JSON.parse(JSON.stringify($chartReference.options, 
                function(key, value) {
                  return (typeof value === 'function') ? value.toString() : value;
                }
              )) || {}
            }
          };
          $messageHandler
        }
      } catch (error) {
        console.error('Chart click handling error:', error);
        ${isWeb 
          ? 'window.handleMessage(\'' + chartId + '\', JSON.stringify({error: error.message}));'
          : 'messageHandler.postMessage(JSON.stringify({error: error.message}));'
        }
      }
    ''';
  }

  static String getBaseHtml(String chartId, String config,
      {bool configFromMap = false}) {
    final configExpr =
        buildSafeChartConfigExpression(config, configFromMap: configFromMap);
    return '''
      <!DOCTYPE html>
      <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
          <script src="https://cdn.jsdelivr.net/npm/chartjs-plugin-annotation"></script> 
          <style>
            html, body { margin: 0; padding: 0; width: 100%; height: 100%; }
            canvas { width: 100% !important; height: 100% !important; }
          </style>
        </head>
        <body>
          <canvas id="$chartId"></canvas>
          <script>
            try {
              window.chart = new Chart(document.getElementById("$chartId"), $configExpr);
              document.getElementById("$chartId").onclick = function(event) {
                ${getClickEventScript(chartId)}
              };
            } catch (error) {
              console.error('Chart initialization error:', error);
              messageHandler.postMessage(JSON.stringify({error: error.message}));
            }
          </script>
        </body>
      </html>
    ''';
  }
}