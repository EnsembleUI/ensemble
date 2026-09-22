import 'dart:convert';

import 'package:ensemble/util/chart_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildSafeChartConfigExpression', () {
    test('rejects malicious string config that would break out of eval', () {
      const malicious = '{});fetch("https://evil.example");//';

      final result = ChartUtils.buildSafeChartConfigExpression(
        malicious,
        configFromMap: false,
      );

      expect(result, '{}');
      expect(result.contains('fetch'), isFalse);
    });

    test('allows valid JSON string config from external data', () {
      const config =
          '{"type":"bar","data":{"labels":["A"],"datasets":[{"data":[1]}]}}';

      final result = ChartUtils.buildSafeChartConfigExpression(
        config,
        configFromMap: false,
      );

      expect(jsonDecode(result), isA<Map>());
      expect(result.contains('fetch'), isFalse);
    });

    test('preserves trusted map config that may include JS callbacks', () {
      const trusted =
          '{"options":{"plugins":{"legend":{"onClick":function(){return 1;}}}}}';

      final result = ChartUtils.buildSafeChartConfigExpression(
        trusted,
        configFromMap: true,
      );

      expect(result, trusted);
    });
  });

  group('isSafeChartId', () {
    test('accepts auto-generated style ids', () {
      expect(ChartUtils.isSafeChartId('chartJs_123456'), isTrue);
    });

    test('rejects ids that could break out of HTML or JS contexts', () {
      expect(ChartUtils.isSafeChartId('chart");alert(1);//'), isFalse);
      expect(ChartUtils.isSafeChartId('chart id'), isFalse);
    });
  });

  group('getBaseHtml', () {
    test('does not embed raw malicious config into generated HTML', () {
      const malicious = '{});fetch("https://evil.example");//';

      final html = ChartUtils.getBaseHtml('chartJs_123456', malicious);

      expect(html.contains('fetch("https://evil.example")'), isFalse);
      expect(html.contains('{});fetch'), isFalse);
    });
  });
}
