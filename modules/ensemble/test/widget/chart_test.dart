import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/widget/visualization/barchart.dart';
import 'package:ensemble/widget/visualization/chart/chart.dart';
import 'package:ensemble/widget/visualization/chart/chart_data.dart';
import 'package:ensemble/widget/visualization/chart/chart_options.dart';
import 'package:ensemble/widget/visualization/chart/chart_styles.dart';
import 'package:ensemble/widget/widget_registry.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:ensemble_ts_interpreter/invokables/invokablecontroller.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// Builds [yaml] the way a screen does, so `${...}` bindings resolve.
Future<ScopeManager> _pumpYaml(WidgetTester tester, String yaml) async {
  late ScopeManager scope;
  await tester.pumpWidget(MaterialApp(
    home: Builder(builder: (context) {
      scope = ScopeManager(DataContext(buildContext: context),
          PageData(customViewDefinitions: {}));
      final root = scope.buildWidgetFromDefinition(loadYaml(yaml));
      return DataScopeWidget(
          scopeManager: scope, child: Scaffold(body: Center(child: root)));
    }),
  ));
  await tester.pump();
  return scope;
}

T _chart<T extends Widget>(WidgetTester tester) =>
    tester.widget<T>(find.byType(T));

PieChartData _pie(WidgetTester tester) => _chart<PieChart>(tester).data;
BarChartData _bar(WidgetTester tester) => _chart<BarChart>(tester).data;
LineChartData _line(WidgetTester tester) => _chart<LineChart>(tester).data;
ScatterChartData _scatter(WidgetTester tester) =>
    _chart<ScatterChart>(tester).data;
RadarChartData _radar(WidgetTester tester) => _chart<RadarChart>(tester).data;

ChartController _controller(WidgetTester tester) =>
    tester.widget<Chart>(find.byType(Chart)).controller;

String _text(ScopeManager scope, String id) =>
    (scope.dataContext.getContextById(id) as Invokable).getProperty('text');

final _tap = FlTapUpEvent(TapUpDetails(kind: PointerDeviceKind.touch));

/// An onTap that writes the tapped value into the Text with id `result`,
/// indented to sit under a Chart inside a Column.
const _onTapWritesResult = r'''
        onTap:
          executeCode:
            body: |
              result.text = event.data.seriesIndex + '/' + event.data.index + '/' + event.data.label + '/' + event.data.value;
''';

void main() {
  group('ChartData', () {
    test('reads a list of series with values, colors, gradient and label', () {
      final series = ChartData.parseSeries([
        {
          'values': [1, 2.5, '3'],
          'colors': ['#FF0000', 'blue', 0xFF00FF00],
          'gradient': ['#000000', '#FFFFFF'],
          'label': 'Goals',
        }
      ]);
      expect(series, hasLength(1));
      expect(series.first.values, [1.0, 2.5, 3.0]);
      expect(series.first.colors, [
        const Color(0xFFFF0000),
        Colors.blue,
        const Color(0xFF00FF00),
      ]);
      expect(series.first.gradient,
          [const Color(0xFF000000), const Color(0xFFFFFFFF)]);
      expect(series.first.label, 'Goals');
    });

    test('reads numbers from strings, as expressions often give strings', () {
      final points = ChartData.parsePoints(['45', ' 54.5 ', 12]);
      expect(points.map((p) => p.y), [45.0, 54.5, 12.0]);
      expect(points.map((p) => p.x), [0, 1, 2]);
    });

    test('keeps values it cannot read as gaps, counted as 0 in values', () {
      final series =
          ChartSeries(points: ChartData.parsePoints(['abc', null, 7]));
      expect(series.points.map((p) => p.y), [null, null, 7.0]);
      expect(series.values, [0.0, 0.0, 7.0]);
    });

    test('reads points as [x, y], [x, y, size] and {x, y, size, color}', () {
      final points = ChartData.parsePoints([
        [2, 3],
        [4, '5', 9],
        {'x': 6, 'y': 7, 'size': 3, 'color': '#FF0000'},
        {'y': 8},
      ]);
      expect(points.map((p) => (p.x, p.y)),
          [(2.0, 3.0), (4.0, 5.0), (6.0, 7.0), (3.0, 8.0)]);
      expect(points[1].size, 9);
      expect(points[2].size, 3);
      expect(points[2].color, const Color(0xFFFF0000));
    });

    test('reads a plain list of values or points as one series', () {
      expect(ChartData.parseSeries([4, '5', 6]).single.values, [4, 5, 6]);
      expect(
          ChartData.parseSeries([
            {'x': 1, 'y': 2},
            {'x': 3, 'y': 4},
          ]).single.points.map((p) => p.y),
          [2, 4]);
    });

    test('accepts one color instead of a list', () {
      final series = ChartData.parseSeries([
        {
          'values': [1, 2],
          'color': '#00FF00',
        }
      ]);
      expect(series.first.colors, [const Color(0xFF00FF00)]);
      expect(series.first.colorAt(1, seriesIndex: 0), const Color(0xFF00FF00));
    });

    test('skips colors it cannot read', () {
      expect(ChartData.parseColors(['#FF0000', 'not-a-color']),
          [const Color(0xFFFF0000)]);
    });

    test('gives no series for data that has not loaded yet', () {
      expect(ChartData.parseSeries(null), isEmpty);
      expect(ChartData.parseSeries(''), isEmpty);
      expect(ChartData.parseSeries([]), isEmpty);
    });

    test('falls back to the default palette without colors', () {
      final series = ChartData.parseSeries([
        {
          'values': [1, 2]
        }
      ]);
      expect(
          series.first.colorAt(0, seriesIndex: 0), ChartData.defaultPalette[0]);
      expect(
          series.first.colorAt(1, seriesIndex: 0), ChartData.defaultPalette[1]);
      expect(series.first.color(seriesIndex: 7), ChartData.defaultPalette[1]);
    });

    test('formats whole numbers without decimals', () {
      expect(ChartData.format(3), '3');
      expect(ChartData.format(2.5), '2.5');
      expect(ChartData.format(1 / 3), '0.33');
    });
  });

  group('options', () {
    test('pie hole size takes pixels or a percentage, within the radius', () {
      PieStyle style(dynamic holeSize) => PieStyle.from({'holeSize': holeSize});
      expect(style(54).holeRadius(60, doughnut: true), 54);
      expect(style('50%').holeRadius(60, doughnut: true), 30);
      expect(style(80).holeRadius(60, doughnut: true), 60);
      expect(style('150%').holeRadius(60, doughnut: true), 60);
      expect(style(null).holeRadius(60, doughnut: true), 30);
      expect(style(null).holeRadius(60, doughnut: false), 0);
    });

    test('dashed takes true or [dash, gap]', () {
      expect(parseDash(true), [6, 4]);
      expect(parseDash([8, 2]), [8, 2]);
      expect(parseDash(false), isNull);
      expect(parseDash([3]), isNull);
    });

    test('legend shows when set to true or a map, not by default', () {
      expect(ChartLegend.from(null).show, isFalse);
      expect(ChartLegend.from(true).show, isTrue);
      expect(ChartLegend.from({'position': 'right'}).show, isTrue);
      expect(ChartLegend.from({'position': 'right'}).position,
          ChartLegendPosition.right);
      expect(ChartLegend.from({'show': false}).show, isFalse);
    });

    test('reference lines need an x or a y', () {
      final lines = ChartReferenceLine.parse([
        {'y': 5},
        {'x': '2'},
        {'color': 'red'},
        'bad',
      ]);
      expect(lines.map((l) => (l.x, l.y)), [(null, 5.0), (2.0, null)]);
    });
  });

  group('Chart widget', () {
    test('is registered as Chart with the modern widgets', () {
      expect(WidgetRegistry().widgetMap[Chart.type]!(null), isA<Chart>());
    });

    testWidgets('JS can read type, data and labels', (tester) async {
      await _pumpYaml(tester, r'''
Chart:
  type: line
  labels: [A, B]
  data: [1, 2]
''');
      final controller = _controller(tester);
      expect(controller.getProperty('type'), 'line');
      expect(controller.getProperty('data'), [1, 2]);
      expect(controller.getProperty('labels'), ['A', 'B']);
    });

    for (final type in ChartType.values) {
      for (final data in ['""', '[]', r'"${notLoadedYet}"']) {
        testWidgets('draws $type with data: $data without errors',
            (tester) async {
          await _pumpYaml(tester, """
Chart:
  type: ${type.name}
  data: $data
  labels: [A, B, C]
  legend: true
  styles:
    width: 200
    height: 200
""");
          expect(tester.takeException(), isNull);
          expect(find.byType(Chart), findsOneWidget);
        });
      }
    }

    testWidgets('uses bar for an unknown type', (tester) async {
      await _pumpYaml(tester, r'''
Chart:
  type: Doughnut
  data: [1, 2]
''');
      expect(find.byType(BarChart), findsOneWidget);
    });

    testWidgets('takes margin, padding and background like other widgets',
        (tester) async {
      await _pumpYaml(tester, r'''
Chart:
  type: pie
  data: [1, 1]
  styles:
    width: 140
    height: 140
    padding: 10
    margin: 5
    backgroundColor: "#EEEEEE"
''');
      expect(tester.getSize(find.byType(Chart)), const Size(150, 150));
      // The pie's radius is half the space inside the padding.
      expect(_pie(tester).sections.first.radius, 60);
    });
  });

  group('pie and doughnut', () {
    testWidgets('draws a doughnut from bound values', (tester) async {
      await _pumpYaml(tester, r'''
Column:
  children:
    - Text:
        id: done
        text: "40"
    - Text:
        id: remaining
        text: "60"
    - Chart:
        type: doughnut
        labels: [Done, Remaining]
        data:
          - values: ["${done.text}", "${remaining.text}"]
            colors: ["#FF6A00", "#00C300"]
        styles:
          width: 120
          height: 120
          pieStyle:
            holeSize: 54
            spacing: 2
''');
      expect(tester.getSize(find.byType(Chart)), const Size(120, 120));
      final data = _pie(tester);
      expect(data.sections.map((s) => s.value), [40, 60]);
      expect(data.sections.map((s) => s.color),
          [const Color(0xFFFF6A00), const Color(0xFF00C300)]);
      expect(data.centerSpaceRadius, 54);
      // Ring thickness: outer radius (60) minus the hole.
      expect(data.sections.first.radius, 6);
      expect(data.sectionsSpace, 2);
      // Starts at 12 o'clock, like Chart.js.
      expect(data.startDegreeOffset, -90);
      expect(data.sections.every((s) => !s.showTitle), isTrue);
      // Not touchable without onTap.
      expect(data.pieTouchData.enabled, isFalse);
    });

    testWidgets('redraws when a bound value changes', (tester) async {
      final scope = await _pumpYaml(tester, r'''
Column:
  children:
    - Text:
        id: done
        text: "40"
    - Text:
        id: remaining
        text: "60"
    - Chart:
        type: doughnut
        data:
          - values: ["${done.text}", "${remaining.text}"]
''');
      expect(_pie(tester).sections.map((s) => s.value), [40, 60]);

      final done = scope.dataContext.getContextById('done') as Invokable;
      final remaining =
          scope.dataContext.getContextById('remaining') as Invokable;
      InvokableController.setProperty(done, 'text', '75');
      InvokableController.setProperty(remaining, 'text', '25');
      await tester.pump();
      await tester.pump();

      expect(_pie(tester).sections.map((s) => s.value), [75, 25]);
    });

    testWidgets('redraws when JS sets data', (tester) async {
      await _pumpYaml(tester, r'''
Chart:
  id: ring
  type: pie
  data: [1, 1]
''');
      _controller(tester).setProperty('data', [2, 3, 5]);
      await tester.pump();
      expect(_pie(tester).sections.map((s) => s.value), [2, 3, 5]);
    });

    testWidgets('takes the whole data list from an expression', (tester) async {
      await _pumpYaml(tester, r'''
Chart:
  type: pie
  data: "${[1, 1 + 2]}"
''');
      final data = _pie(tester);
      expect(data.sections.map((s) => s.value), [1, 3]);
      expect(
          data.sections.map((s) => s.color), ChartData.defaultPalette.take(2));
      expect(data.centerSpaceRadius, 0);
      // No size given: a 200x200 square.
      expect(tester.getSize(find.byType(Chart)), const Size(200, 200));
    });

    testWidgets('draws nothing for a ring with no values yet', (tester) async {
      await _pumpYaml(tester, r'''
Chart:
  type: doughnut
  data:
    - values: [0, 0]
''');
      expect(find.byType(PieChart), findsNothing);
    });

    testWidgets('shows values, percentages, borders and hole color',
        (tester) async {
      await _pumpYaml(tester, r'''
Chart:
  type: doughnut
  data: [1, 3]
  styles:
    pieStyle:
      showValues: true
      valueType: percent
      valuePosition: 0.8
      valueStyle:
        fontSize: 20
      holeColor: "#000000"
      borderColor: "#FFFFFF"
      borderWidth: 2
      startAngle: 90
''');
      final data = _pie(tester);
      expect(data.sections.map((s) => s.title), ['25%', '75%']);
      expect(data.sections.every((s) => s.showTitle), isTrue);
      expect(data.sections.first.titlePositionPercentageOffset, 0.8);
      expect(data.sections.first.titleStyle?.fontSize, 20);
      expect(data.sections.first.borderSide,
          const BorderSide(color: Color(0xFFFFFFFF), width: 2));
      expect(data.centerSpaceColor, const Color(0xFF000000));
      expect(data.startDegreeOffset, 0);
    });

    testWidgets('skips empty slices but reports the right one on tap',
        (tester) async {
      final scope = await _pumpYaml(tester, '''
Column:
  children:
    - Text:
        id: result
        text: ""
    - Chart:
        type: pie
        labels: [A, B, C]
        data: [2, 0, 5]
$_onTapWritesResult''');
      final data = _pie(tester);
      expect(data.sections.map((s) => s.value), [2, 5]);
      expect(data.pieTouchData.enabled, isTrue);

      // The second slice drawn is C, the third value.
      data.pieTouchData.touchCallback!(
          _tap, PieTouchResponse(PieTouchedSection(null, 1, 0, 0)));
      await tester.pumpAndSettle();
      expect(_text(scope, 'result'), '0/2/C/5');
    });

    testWidgets('only reads the style group for its own type', (tester) async {
      await _pumpYaml(tester, r'''
Chart:
  type: doughnut
  data: [1, 1]
  styles:
    width: 100
    barStyle:
      width: 30
    pieStyle:
      holeSize: "40%"
''');
      expect(_pie(tester).centerSpaceRadius, 20);
    });
  });

  group('legend', () {
    testWidgets('lists the slices of a pie with their colors', (tester) async {
      await _pumpYaml(tester, r'''
Chart:
  type: pie
  labels: [Done, Remaining]
  data:
    - values: [1, 2]
      colors: ["#FF0000", "#0000FF"]
  legend:
    position: right
  styles:
    width: 300
    height: 150
''');
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Remaining'), findsOneWidget);
      // Right of the chart.
      expect(tester.getTopLeft(find.text('Done')).dx,
          greaterThan(tester.getTopRight(find.byType(PieChart)).dx));
      final dots = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .map((d) => d.color)
          .toList();
      expect(dots,
          containsAll([const Color(0xFFFF0000), const Color(0xFF0000FF)]));
    });

    testWidgets('lists the series of a line chart, above it', (tester) async {
      await _pumpYaml(tester, r'''
Chart:
  type: line
  data:
    - label: First
      values: [1, 2]
    - label: Second
      values: [2, 1]
    - values: [0, 0]
  legend:
    position: top
  styles:
    width: 300
''');
      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);
      expect(tester.getBottomLeft(find.text('First')).dy,
          lessThan(tester.getTopLeft(find.byType(LineChart)).dy));
    });

    testWidgets('is hidden unless set', (tester) async {
      await _pumpYaml(tester, r'''
Chart:
  type: pie
  labels: [Done, Remaining]
  data: [1, 2]
''');
      expect(find.text('Done'), findsNothing);
    });
  });

  group('bar', () {
    testWidgets('draws bars with barStyle and yAxis', (tester) async {
      await _pumpYaml(tester, r'''
Chart:
  type: bar
  labels: [Mon, Tue, Wed]
  data:
    - values: [3, "5", 2]
      colors: ["#00C300"]
  yAxis:
    min: 0
    max: 10
  styles:
    width: 300
    height: 200
    barStyle:
      width: 12
      borderRadius: 4
      alignment: center
      groupSpace: 8
      backgroundColor: "#EEEEEE"
      borderColor: "#000000"
      borderWidth: 1
''');
      final data = _bar(tester);
      expect(data.minY, 0);
      expect(data.maxY, 10);
      expect(data.alignment, BarChartAlignment.center);
      expect(data.groupsSpace, 8);
      expect(data.barGroups, hasLength(3));
      final rods = data.barGroups.map((g) => g.barRods.single).toList();
      expect(rods.map((r) => r.toY), [3, 5, 2]);
      expect(rods.every((r) => r.color == const Color(0xFF00C300)), isTrue);
      expect(rods.first.width, 12);
      expect(rods.first.borderRadius, BorderRadius.circular(4));
      expect(rods.first.borderSide,
          const BorderSide(color: Color(0xFF000000), width: 1));
      // The track goes up to the top of the y axis.
      expect(rods.first.backDrawRodData.show, isTrue);
      expect(rods.first.backDrawRodData.toY, 10);
      expect(rods.first.backDrawRodData.color, const Color(0xFFEEEEEE));
      expect(find.text('Tue'), findsOneWidget);
    });

    testWidgets('draws one bar per series in each group', (tester) async {
      await _pumpYaml(tester, r'''
Chart:
  type: bar
  labels: [Q1, Q2]
  data:
    - values: [1, 2]
      color: "#FF0000"
    - values: [3, 4]
      color: "#0000FF"
  styles:
    width: 300
    barStyle:
      barSpace: 6
''');
      final group = _bar(tester).barGroups.first;
      expect(group.barRods.map((r) => r.toY), [1, 3]);
      expect(group.barRods.map((r) => r.color),
          [const Color(0xFFFF0000), const Color(0xFF0000FF)]);
      expect(group.barsSpace, 6);
    });

    testWidgets('stacks series and reports the tapped part', (tester) async {
      final scope = await _pumpYaml(tester, '''
Column:
  children:
    - Text:
        id: result
        text: ""
    - Chart:
        type: bar
        labels: [Q1, Q2]
        data:
          - values: [1, 2]
            color: "#FF0000"
          - values: [3, 4]
            color: "#0000FF"
        styles:
          width: 300
          barStyle:
            stacked: true
$_onTapWritesResult''');
      final data = _bar(tester);
      final rod = data.barGroups[1].barRods.single;
      expect(rod.toY, 6);
      expect(rod.rodStackItems.map((i) => (i.fromY, i.toY, i.color)), [
        (0.0, 2.0, const Color(0xFFFF0000)),
        (2.0, 6.0, const Color(0xFF0000FF)),
      ]);

      data.barTouchData.touchCallback!(
          _tap,
          BarTouchResponse(BarTouchedSpot(data.barGroups[1], 1, rod, 0,
              rod.rodStackItems[1], 1, const FlSpot(1, 6), Offset.zero)));
      await tester.pumpAndSettle();
      expect(_text(scope, 'result'), '1/1/Q2/4');
    });

    testWidgets('uses a gradient when a series has one', (tester) async {
      await _pumpYaml(tester, r'''
Chart:
  type: bar
  data:
    - values: [1]
      gradient: ["#000000", "#FFFFFF"]
  styles:
    width: 100
''');
      final rod = _bar(tester).barGroups.single.barRods.single;
      expect((rod.gradient as LinearGradient).colors,
          [const Color(0xFF000000), const Color(0xFFFFFFFF)]);
    });

    testWidgets('draws a horizontal reference line with a label',
        (tester) async {
      await _pumpYaml(tester, r'''
Chart:
  type: bar
  data: [1, 2]
  referenceLines:
    - y: 1.5
      color: "#FF0000"
      width: 2
      dashed: true
      label: Average
    - x: 1
  styles:
    width: 300
''');
      final lines = _bar(tester).extraLinesData;
      final line = lines.horizontalLines.single;
      expect(line.y, 1.5);
      expect(line.color, const Color(0xFFFF0000));
      expect(line.strokeWidth, 2);
      expect(line.dashArray, [6, 4]);
      expect(line.label.show, isTrue);
      expect(line.label.labelResolver(line), 'Average');
      // Bar charts have no vertical lines.
      expect(lines.verticalLines, isEmpty);
    });

    testWidgets('shows the series label and value in the tooltip',
        (tester) async {
      await _pumpYaml(tester, r'''
Chart:
  type: bar
  data:
    - label: Goals
      values: [3]
  touchTooltip:
    backgroundColor: "#123456"
    borderRadius: 8
    textStyle:
      fontSize: 18
  styles:
    width: 100
''');
      final touch = _bar(tester).barTouchData;
      expect(touch.enabled, isTrue);
      final group = _bar(tester).barGroups.single;
      final item = touch.touchTooltipData
          .getTooltipItem(group, 0, group.barRods.single, 0)!;
      expect(item.text, 'Goals: 3');
      expect(item.textStyle.fontSize, 18);
      expect(touch.touchTooltipData.getTooltipColor(group),
          const Color(0xFF123456));
      expect(touch.touchTooltipData.tooltipRoundedRadius, 8);
    });

    testWidgets('turns touch off without a tooltip or onTap', (tester) async {
      await _pumpYaml(tester, r'''
Chart:
  type: bar
  data: [1]
  touchTooltip: false
  styles:
    width: 100
''');
      expect(_bar(tester).barTouchData.enabled, isFalse);
    });
  });

  group('axes and grid', () {
    testWidgets('sets labels, titles, intervals and axis lines',
        (tester) async {
      await _pumpYaml(tester, r'''
Chart:
  type: line
  data: [1, 5, 3]
  xAxis:
    title: Minute
    labelSize: 20
    line:
      color: "#FF0000"
      width: 2
  yAxis:
    interval: 2
    show: false
  styles:
    width: 300
''');
      final data = _line(tester);
      final titles = data.titlesData;
      expect(titles.leftTitles.sideTitles.showTitles, isFalse);
      expect(titles.leftTitles.sideTitles.interval, 2);
      expect(titles.bottomTitles.sideTitles.reservedSize, 20);
      expect(find.text('Minute'), findsOneWidget);
      expect(data.borderData.show, isTrue);
      expect(data.borderData.border.bottom,
          const BorderSide(color: Color(0xFFFF0000), width: 2));
      expect(data.borderData.border.left, BorderSide.none);
      // The grid follows the y axis interval.
      expect(data.gridData.horizontalInterval, 2);
    });

    testWidgets('shows horizontal grid lines by default', (tester) async {
      await _pumpYaml(tester, r'''
Chart:
  type: bar
  data: [1]
  styles:
    width: 100
''');
      final grid = _bar(tester).gridData;
      expect(grid.show, isTrue);
      expect(grid.drawHorizontalLine, isTrue);
      expect(grid.drawVerticalLine, isFalse);
    });

    testWidgets('styles the grid', (tester) async {
      await _pumpYaml(tester, r'''
Chart:
  type: line
  data: [1, 2]
  grid:
    vertical: true
    color: "#00FF00"
    width: 3
    dashed: [2, 2]
    verticalInterval: 1
  styles:
    width: 300
''');
      final grid = _line(tester).gridData;
      expect(grid.drawVerticalLine, isTrue);
      expect(grid.verticalInterval, 1);
      final line = grid.getDrawingHorizontalLine(0);
      expect(line.color, const Color(0xFF00FF00));
      expect(line.strokeWidth, 3);
      expect(line.dashArray, [2, 2]);
    });

    testWidgets('ignores an interval of 0, which fl_chart rejects',
        (tester) async {
      await _pumpYaml(tester, r'''
Chart:
  type: line
  data: [1, 2]
  yAxis:
    interval: 0
  styles:
    width: 300
''');
      expect(_line(tester).titlesData.leftTitles.sideTitles.interval, isNull);
    });
  });

  group('line', () {
    testWidgets('draws lines with lineStyle', (tester) async {
      await _pumpYaml(tester, r'''
Chart:
  type: line
  labels: [A, B, C]
  data:
    - values: [1, 4, 2]
      color: "#FF0000"
    - values: [2, 2, 3]
  xAxis:
    min: 0
    max: 2
  styles:
    width: 300
    lineStyle:
      width: 3
      curved: true
      curveSmoothness: 0.5
      preventCurveOvershoot: true
      dashed: true
      fillArea: true
      fillOpacity: 0.5
      showDots: true
      dotSize: 5
''');
      final data = _line(tester);
      expect(data.minX, 0);
      expect(data.maxX, 2);
      expect(data.lineBarsData, hasLength(2));
      final line = data.lineBarsData.first;
      expect(line.spots.map((s) => s.y), [1, 4, 2]);
      expect(line.color, const Color(0xFFFF0000));
      expect(line.barWidth, 3);
      expect(line.isCurved, isTrue);
      expect(line.curveSmoothness, 0.5);
      expect(line.preventCurveOverShooting, isTrue);
      expect(line.dashArray, [6, 4]);
      expect(line.belowBarData.show, isTrue);
      expect(line.belowBarData.color,
          const Color(0xFFFF0000).withValues(alpha: 0.5));
      expect(line.dotData.show, isTrue);
      final dot = line.dotData.getDotPainter(line.spots.first, 0, line, 0)
          as FlDotCirclePainter;
      expect(dot.radius, 5);
      expect(dot.color, const Color(0xFFFF0000));
      expect(data.lineBarsData[1].color, ChartData.defaultPalette[1]);
    });

    testWidgets('draws steps, gaps and points with their own x',
        (tester) async {
      await _pumpYaml(tester, r'''
Chart:
  type: line
  data:
    - values: [[0, 1], [5, 3], [10, null], [12, 4]]
  styles:
    width: 300
    lineStyle:
      stepped: true
''');
      final line = _line(tester).lineBarsData.single;
      expect(line.isStepLineChart, isTrue);
      expect(line.spots[1], const FlSpot(5, 3));
      expect(line.spots[2].isNull(), isTrue);
    });

    testWidgets('draws vertical and horizontal reference lines',
        (tester) async {
      await _pumpYaml(tester, r'''
Chart:
  type: line
  data: [1, 2, 3]
  referenceLines:
    - x: 1
    - y: 2
  styles:
    width: 300
''');
      final lines = _line(tester).extraLinesData;
      expect(lines.verticalLines.single.x, 1);
      expect(lines.horizontalLines.single.y, 2);
      expect(lines.verticalLines.single.label.show, isFalse);
    });

    testWidgets('reports the tapped value', (tester) async {
      final scope = await _pumpYaml(tester, '''
Column:
  children:
    - Text:
        id: result
        text: ""
    - Chart:
        type: line
        labels: [A, B, C]
        data:
          - values: [1, 2, 3]
          - values: [4, 5, 6]
        styles:
          width: 300
$_onTapWritesResult''');
      final data = _line(tester);
      final bar = data.lineBarsData[1];
      data.lineTouchData.touchCallback!(
          _tap, LineTouchResponse([TouchLineBarSpot(bar, 1, bar.spots[2], 0)]));
      await tester.pumpAndSettle();
      expect(_text(scope, 'result'), '1/2/C/6');
    });
  });

  group('scatter', () {
    testWidgets('draws points with their own size and color', (tester) async {
      await _pumpYaml(tester, r'''
Chart:
  type: scatter
  data:
    - color: "#FF0000"
      values:
        - [1, 2]
        - [3, 4, 10]
        - {x: 5, y: 6, color: "#0000FF"}
        - [7, "n/a"]
  yAxis:
    min: 0
    max: 8
  styles:
    width: 300
    scatterStyle:
      dotSize: 4
      borderColor: "#000000"
      borderWidth: 1
''');
      final data = _scatter(tester);
      expect(data.minY, 0);
      expect(data.maxY, 8);
      // The point that can't be read is left out.
      expect(data.scatterSpots.map((s) => (s.x, s.y)),
          [(1.0, 2.0), (3.0, 4.0), (5.0, 6.0)]);
      final painters = data.scatterSpots
          .map((s) => s.dotPainter as FlDotCirclePainter)
          .toList();
      expect(painters.map((p) => p.radius), [4, 10, 4]);
      expect(painters.map((p) => p.color), [
        const Color(0xFFFF0000),
        const Color(0xFFFF0000),
        const Color(0xFF0000FF),
      ]);
      expect(painters.first.strokeWidth, 1);
      expect(painters.first.strokeColor, const Color(0xFF000000));
    });

    testWidgets('reports the tapped point across series', (tester) async {
      final scope = await _pumpYaml(tester, '''
Column:
  children:
    - Text:
        id: result
        text: ""
    - Chart:
        type: scatter
        labels: [first, second]
        data:
          - values: [[1, 1], [2, "n/a"]]
          - values: [[3, 3], [4, 4]]
        styles:
          width: 300
$_onTapWritesResult''');
      final data = _scatter(tester);
      // The third dot drawn is the second series' second point.
      data.scatterTouchData.touchCallback!(_tap,
          ScatterTouchResponse(ScatterTouchedSpot(data.scatterSpots[2], 2)));
      await tester.pumpAndSettle();
      expect(_text(scope, 'result'), '1/1/second/4');
    });
  });

  group('radar', () {
    testWidgets('draws each series on the labelled axes', (tester) async {
      await _pumpYaml(tester, r'''
Chart:
  type: radar
  labels: [Speed, Power, Skill, Stamina]
  data:
    - label: First
      values: [3, 4, 5, 2]
      color: "#FF0000"
    - label: Second
      values: [5, 3, 2]
  styles:
    width: 300
    height: 300
    radarStyle:
      shape: polygon
      tickCount: 4
      gridColor: "#CCCCCC"
      borderColor: "#999999"
      backgroundColor: "#FAFAFA"
      lineWidth: 3
      fillOpacity: 0.4
      dotSize: 5
      labelPosition: 0.2
''');
      final data = _radar(tester);
      expect(data.radarShape, RadarShape.polygon);
      expect(data.tickCount, 4);
      expect(data.gridBorderData.color, const Color(0xFFCCCCCC));
      expect(data.radarBorderData.color, const Color(0xFF999999));
      expect(data.radarBackgroundColor, const Color(0xFFFAFAFA));
      expect(data.titlePositionPercentageOffset, 0.2);
      expect(data.getTitle!(1, 0).text, 'Power');

      final first = data.dataSets.first;
      expect(first.dataEntries.map((e) => e.value), [3, 4, 5, 2]);
      expect(first.borderColor, const Color(0xFFFF0000));
      expect(first.fillColor, const Color(0xFFFF0000).withValues(alpha: 0.4));
      expect(first.borderWidth, 3);
      expect(first.entryRadius, 5);
      // A shorter series is padded with 0, as fl_chart needs equal lengths.
      expect(data.dataSets[1].dataEntries.map((e) => e.value), [5, 3, 2, 0]);
    });

    testWidgets('draws nothing with fewer than 3 axes', (tester) async {
      await _pumpYaml(tester, r'''
Chart:
  type: radar
  data: [1, 2]
  styles:
    width: 200
''');
      expect(find.byType(RadarChart), findsNothing);
    });

    testWidgets('reports the tapped value', (tester) async {
      final scope = await _pumpYaml(tester, '''
Column:
  children:
    - Text:
        id: result
        text: ""
    - Chart:
        type: radar
        labels: [A, B, C]
        data: [1, 2, 3]
        styles:
          width: 200
$_onTapWritesResult''');
      final data = _radar(tester);
      final set = data.dataSets.single;
      data.radarTouchData.touchCallback!(
          _tap,
          RadarTouchResponse(RadarTouchedSpot(
              set, 0, set.dataEntries[1], 1, const FlSpot(0, 0), Offset.zero)));
      await tester.pumpAndSettle();
      expect(_text(scope, 'result'), '0/1/B/2');
    });
  });

  group('BarChart (deprecated)', () {
    test('reads colors as #hex strings, not only ints', () {
      final controller = EnsembleBarChartController()
        ..setMetaData([
          {'y': 2, 'color': '#FF0000'},
          {'y': 3, 'color': 0xFF0000FF},
        ]);
      final rods = controller.data.map((g) => g.barRods.single).toList();
      expect(rods.map((r) => r.color),
          [const Color(0xFFFF0000), const Color(0xFF0000FF)]);
    });
  });
}
