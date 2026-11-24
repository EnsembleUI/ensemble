import 'dart:math';

import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/data_utils.dart';
import 'package:ensemble/framework/ensemble_widget.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/box_wrapper.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/visualization/chart/chart_data.dart';
import 'package:ensemble/widget/visualization/chart/chart_options.dart';
import 'package:ensemble/widget/visualization/chart/chart_styles.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// A native chart drawn in Flutter with fl_chart: line, bar, pie, doughnut,
/// radar or scatter. Works the same on every platform, with no WebView.
///
/// ```yaml
/// Chart:
///   type: doughnut
///   labels: [Done, Remaining]
///   data:
///     - values: ["${done}", "${remaining}"]
///       colors: ["#4CAF50", "#E0E0E0"]
///   styles:
///     width: 120
///     height: 120
///     pieStyle:
///       holeSize: 54
///       spacing: 2
/// ```
///
/// Replaces `BarChart` and `LineChart`, and covers the charts that needed
/// `ChartJs` (a WebView).
class Chart extends EnsembleWidget<ChartController> {
  static const type = 'Chart';

  /// Size used when neither width nor height is set.
  static const double defaultSize = 200;

  const Chart._(super.controller);

  factory Chart.build(dynamic controller) =>
      Chart._(controller is ChartController ? controller : ChartController());

  @override
  State<StatefulWidget> createState() => ChartState();
}

class ChartController extends EnsembleBoxController with HasDeepBindings {
  ChartType type = ChartType.bar;

  /// `data` as given, for JS to read back.
  dynamic data;
  List<ChartSeries> series = const [];
  List<String> labels = const [];

  ChartAxis xAxis = ChartAxis.from(null);
  ChartAxis yAxis = ChartAxis.from(null);
  ChartGrid grid = ChartGrid.from(null);
  ChartLegend legend = ChartLegend.from(null);
  ChartTooltip touchTooltip = ChartTooltip.from(null);
  List<ChartReferenceLine> referenceLines = const [];
  Duration animationDuration = const Duration(milliseconds: 150);

  /// Rotates line, bar and scatter charts clockwise, in quarter turns (0-3).
  /// 1 gives horizontal bars.
  int quarterTurns = 0;
  ChartZoom zoom = ChartZoom.from(null);
  ChartErrorBars errorBars = ChartErrorBars.from(null);

  PieStyle pieStyle = PieStyle.from(null);
  BarStyle barStyle = BarStyle.from(null);
  LineStyle lineStyle = LineStyle.from(null);
  RadarStyle radarStyle = RadarStyle.from(null);
  ScatterStyle scatterStyle = ScatterStyle.from(null);

  /// Runs when a bar, slice, point or radar value is tapped.
  EnsembleAction? onTap;

  /// `data` is a list of series, each with a list of values and colors, so
  /// `${...}` can sit three levels down (`data[0].values[1]`).
  @override
  Set<String> get deepBindingProperties =>
      const {'data', 'labels', 'referenceLines'};

  @override
  Map<String, Function> getters() => {
        ...super.getters(),
        'type': () => type.name,
        'data': () => data,
        'labels': () => labels,
      };

  @override
  Map<String, Function> setters() => Map<String, Function>.from(super.setters())
    ..addAll({
      'type': (value) => type = ChartType.values.from(value) ?? ChartType.bar,
      'data': (value) {
        data = value;
        series = ChartData.parseSeries(value);
      },
      'labels': (value) => labels = ChartData.parseLabels(value),
      'xAxis': (value) => xAxis = ChartAxis.from(value),
      'yAxis': (value) => yAxis = ChartAxis.from(value),
      'grid': (value) => grid = ChartGrid.from(value),
      'legend': (value) => legend = ChartLegend.from(value),
      'touchTooltip': (value) => touchTooltip = ChartTooltip.from(value),
      'referenceLines': (value) =>
          referenceLines = ChartReferenceLine.parse(value),
      'quarterTurns': (value) =>
          quarterTurns = Utils.optionalInt(value, min: 0, max: 3) ?? 0,
      'zoom': (value) => zoom = ChartZoom.from(value),
      'errorBars': (value) => errorBars = ChartErrorBars.from(value),
      'animationDuration': (value) => animationDuration =
          Utils.getDurationMs(value) ?? const Duration(milliseconds: 150),
      'pieStyle': (value) => pieStyle = PieStyle.from(value),
      'barStyle': (value) => barStyle = BarStyle.from(value),
      'lineStyle': (value) => lineStyle = LineStyle.from(value),
      'radarStyle': (value) => radarStyle = RadarStyle.from(value),
      'scatterStyle': (value) => scatterStyle = ScatterStyle.from(value),
      'onTap': (value) => onTap = EnsembleAction.from(value, initiator: this),
    });
}

class ChartState extends EnsembleWidgetState<Chart> {
  ChartController get _controller => widget.controller;

  @override
  Widget buildWidget(BuildContext context) {
    final chart = switch (_controller.type) {
      ChartType.pie || ChartType.doughnut => _buildPieChart(),
      ChartType.bar => _buildBarChart(),
      ChartType.line => _buildLineChart(),
      ChartType.scatter => _buildScatterChart(),
      ChartType.radar => _buildRadarChart(),
    };
    final circular = _controller.type.isCircular;
    return EnsembleBoxWrapper(
      boxController: _controller,
      // Pie and doughnut default to a square; the others to the default
      // height and the width of their parent.
      fallbackWidth:
          circular ? _controller.height?.toDouble() ?? Chart.defaultSize : null,
      fallbackHeight: circular
          ? _controller.width?.toDouble() ?? Chart.defaultSize
          : Chart.defaultSize,
      widget: _withLegend(chart),
    );
  }

  TextStyle get _textStyle =>
      Theme.of(context).textTheme.bodySmall ?? const TextStyle(fontSize: 12);

  /// Runs `onTap` with the tapped value in `event.data`.
  void _onTap(int seriesIndex, int index) {
    final action = _controller.onTap;
    if (action == null || seriesIndex >= _controller.series.length) return;
    final series = _controller.series[seriesIndex];
    final point = index < series.points.length ? series.points[index] : null;
    ScreenController().executeAction(context, action,
        event: EnsembleEvent(_controller, data: {
          'seriesIndex': seriesIndex,
          'index': index,
          'series': series.label,
          'label': index < _controller.labels.length
              ? _controller.labels[index]
              : null,
          'x': _plain(point?.x),
          'value': _plain(point?.y),
        }));
  }

  /// Whole numbers as ints, so JS shows `5` rather than `5.0`.
  static num? _plain(double? value) =>
      value != null && value == value.roundToDouble() ? value.toInt() : value;

  bool get _touchEnabled =>
      _controller.touchTooltip.show || _controller.onTap != null;

  /// The tooltip's text: the value, after the series' label when it has one.
  String _tooltipText(int seriesIndex, double value) {
    final label = seriesIndex < _controller.series.length
        ? _controller.series[seriesIndex].label
        : null;
    final text = ChartData.format(value);
    return label == null || label.isEmpty ? text : '$label: $text';
  }

  BorderRadius get _tooltipRadius =>
      BorderRadius.circular(_controller.touchTooltip.borderRadius ?? 4);

  TextStyle get _tooltipTextStyle =>
      _controller.touchTooltip.textStyle ??
      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold);

  /// Each legend entry's color and name.
  List<(Color, String)> get _legendEntries {
    final series = _controller.series;
    if (_controller.type.isCircular) {
      if (series.isEmpty) return const [];
      return [
        for (var i = 0; i < _controller.labels.length; i++)
          (series.first.colorAt(i, seriesIndex: 0), _controller.labels[i]),
      ];
    }
    return [
      for (var s = 0; s < series.length; s++)
        if (series[s].label?.isNotEmpty == true)
          (series[s].color(seriesIndex: s), series[s].label!),
    ];
  }

  Widget _withLegend(Widget chart) {
    final legend = _controller.legend;
    final entries = _legendEntries;
    if (!legend.show || entries.isEmpty) return chart;

    final textStyle = _textStyle.merge(legend.textStyle);
    final items = [
      for (final (color, label) in entries)
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: legend.iconSize,
            height: legend.iconSize,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(child: Text(label, style: textStyle)),
        ]),
    ];
    final position = legend.position;
    final vertical = position == ChartLegendPosition.left ||
        position == ChartLegendPosition.right;
    final legendWidget = vertical
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) SizedBox(height: legend.spacing / 2),
                items[i],
              ],
            ],
          )
        : Wrap(
            alignment: WrapAlignment.center,
            spacing: legend.spacing,
            runSpacing: 4,
            children: items,
          );
    final gap = SizedBox(width: legend.spacing, height: legend.spacing);
    final legendFirst = position == ChartLegendPosition.top ||
        position == ChartLegendPosition.left;
    final children = legendFirst
        ? [legendWidget, gap, Expanded(child: chart)]
        : [Expanded(child: chart), gap, legendWidget];
    return vertical ? Row(children: children) : Column(children: children);
  }

  /// Labels and titles along the x and y axes.
  FlTitlesData _titles({required bool labelsOnX}) {
    final xAxis = _controller.xAxis;
    final yAxis = _controller.yAxis;
    final labels = _controller.labels;
    final hasLabels = labelsOnX && labels.isNotEmpty;
    final base = _textStyle;
    // Turned sideways, the x labels sit beside the chart and need more width.
    final sideways = _controller.quarterTurns.isOdd;

    Widget? axisName(ChartAxis axis) => axis.title == null
        ? null
        : Text(axis.title!, style: base.merge(axis.titleStyle));

    return FlTitlesData(
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        axisNameWidget: axisName(yAxis),
        axisNameSize: yAxis.title == null ? 16 : 20,
        sideTitles: SideTitles(
          showTitles: yAxis.show,
          reservedSize: yAxis.labelSize ?? (sideways ? 24 : 40),
          interval: _positive(yAxis.interval),
          getTitlesWidget: (value, meta) => SideTitleWidget(
            meta: meta,
            child:
                Text(meta.formattedValue, style: base.merge(yAxis.labelStyle)),
          ),
        ),
      ),
      bottomTitles: AxisTitles(
        axisNameWidget: axisName(xAxis),
        axisNameSize: xAxis.title == null ? 16 : 20,
        sideTitles: SideTitles(
          // Bars sit at their index, so without labels there's nothing to show.
          showTitles:
              xAxis.show && (hasLabels || _controller.type != ChartType.bar),
          reservedSize: xAxis.labelSize ?? (sideways ? 64 : 32),
          interval: _positive(xAxis.interval) ?? (hasLabels ? 1 : null),
          getTitlesWidget: (value, meta) {
            String text = meta.formattedValue;
            if (hasLabels) {
              final index = value.toInt();
              if (index != value || index < 0 || index >= labels.length) {
                return const SizedBox.shrink();
              }
              text = labels[index];
            }
            return SideTitleWidget(
              meta: meta,
              child: Text(text, style: base.merge(xAxis.labelStyle)),
            );
          },
        ),
      ),
    );
  }

  /// fl_chart asserts that intervals aren't 0.
  static double? _positive(double? value) =>
      value != null && value > 0 ? value : null;

  FlGridData get _grid {
    final grid = _controller.grid;
    final custom =
        grid.color != null || grid.width != null || grid.dashArray != null;
    FlLine line(double _) => FlLine(
          color: grid.color ?? const Color(0x33000000),
          strokeWidth: grid.width ?? 1,
          dashArray: grid.dashArray,
        );
    return FlGridData(
      show: grid.show,
      drawHorizontalLine: grid.horizontal,
      drawVerticalLine: grid.vertical,
      horizontalInterval: _positive(grid.horizontalInterval) ??
          _positive(_controller.yAxis.interval),
      verticalInterval: _positive(grid.verticalInterval) ??
          _positive(_controller.xAxis.interval),
      getDrawingHorizontalLine: custom ? line : defaultGridLine,
      getDrawingVerticalLine: custom ? line : defaultGridLine,
    );
  }

  /// Draws the axis lines set with `xAxis.line` and `yAxis.line`.
  FlBorderData get _axisLines {
    final xAxis = _controller.xAxis;
    final yAxis = _controller.yAxis;
    return FlBorderData(
      show: xAxis.showLine || yAxis.showLine,
      border: Border(bottom: xAxis.lineSide, left: yAxis.lineSide),
    );
  }

  ExtraLinesData _referenceLines({required bool vertical}) {
    final lines = _controller.referenceLines;
    final labelStyle = _textStyle;
    return ExtraLinesData(
      horizontalLines: [
        for (final line in lines)
          if (line.y != null)
            HorizontalLine(
              y: line.y!,
              color: line.color ?? const Color(0xFF9E9E9E),
              strokeWidth: line.width ?? 1,
              dashArray: line.dashArray,
              label: HorizontalLineLabel(
                show: line.label != null,
                style: labelStyle.merge(line.labelStyle),
                labelResolver: (_) => line.label ?? '',
              ),
            ),
      ],
      verticalLines: [
        if (vertical)
          for (final line in lines)
            if (line.x != null)
              VerticalLine(
                x: line.x!,
                color: line.color ?? const Color(0xFF9E9E9E),
                strokeWidth: line.width ?? 1,
                dashArray: line.dashArray,
                label: VerticalLineLabel(
                  show: line.label != null,
                  style: labelStyle.merge(line.labelStyle),
                  labelResolver: (_) => line.label ?? '',
                ),
              ),
      ],
    );
  }

  Widget _buildPieChart() {
    final series =
        _controller.series.isNotEmpty ? _controller.series.first : null;
    if (series == null) return const SizedBox.shrink();
    final values = series.values;
    final total = values.fold<double>(0, (sum, v) => sum + max(v, 0));
    if (total <= 0) return const SizedBox.shrink();

    // Slices with no value are left out; this maps a slice back to its value.
    final indexes = [
      for (var i = 0; i < values.length; i++)
        if (values[i] > 0) i
    ];
    final style = _controller.pieStyle;
    final border = style.borderWidth != null || style.borderColor != null
        ? BorderSide(
            color: style.borderColor ?? Colors.white,
            width: style.borderWidth ?? 1)
        : null;
    final valueStyle = _textStyle
        .copyWith(color: Colors.white, fontWeight: FontWeight.bold)
        .merge(style.valueStyle);

    return LayoutBuilder(builder: (context, constraints) {
      final radius = min(constraints.maxWidth, constraints.maxHeight) / 2;
      final hole = style.holeRadius(radius,
          doughnut: _controller.type == ChartType.doughnut);
      return PieChart(
        PieChartData(
          // fl_chart starts at 3 o'clock; startAngle counts from 12 o'clock.
          startDegreeOffset: (style.startAngle ?? 0) - 90,
          centerSpaceRadius: hole,
          centerSpaceColor: style.holeColor,
          sectionsSpace: style.spacing ?? 0,
          borderData: FlBorderData(show: false),
          pieTouchData: PieTouchData(
            enabled: _controller.onTap != null,
            touchCallback: (event, response) {
              final slice = response?.touchedSection?.touchedSectionIndex;
              if (event is FlTapUpEvent &&
                  slice != null &&
                  slice >= 0 &&
                  slice < indexes.length) {
                _onTap(0, indexes[slice]);
              }
            },
          ),
          sections: [
            for (final i in indexes)
              PieChartSectionData(
                value: values[i],
                color: series.colorAt(i, seriesIndex: 0),
                radius: radius - hole,
                showTitle: style.showValues,
                title: style.valueType == PieValueType.percent
                    ? '${ChartData.format(values[i] / total * 100)}%'
                    : ChartData.format(values[i]),
                titleStyle: valueStyle,
                titlePositionPercentageOffset: style.valuePosition,
                borderSide: border,
              ),
          ],
        ),
        duration: _controller.animationDuration,
      );
    });
  }

  Widget _buildBarChart() {
    final style = _controller.barStyle;
    final allSeries = _controller.series;
    final count = allSeries.fold<int>(
        _controller.labels.length, (n, s) => max(n, s.points.length));
    double valueAt(int s, int x) =>
        x < allSeries[s].points.length ? allSeries[s].points[x].y ?? 0 : 0;
    FlErrorRange? errorAt(int s, int x) =>
        x < allSeries[s].points.length ? allSeries[s].points[x].yError : null;

    // The top of the background track behind each bar.
    double highest = 0;
    for (var x = 0; x < count; x++) {
      final values = [for (var s = 0; s < allSeries.length; s++) valueAt(s, x)];
      highest = max(
          highest,
          style.stacked
              ? values.fold(0, (sum, v) => sum + max(v, 0))
              : values.fold(0, max));
    }
    final background = style.backgroundColor == null
        ? null
        : BackgroundBarChartRodData(
            show: true,
            toY: _controller.yAxis.max ?? highest,
            color: style.backgroundColor,
          );
    final border = style.borderWidth != null || style.borderColor != null
        ? BorderSide(
            color: style.borderColor ?? Colors.black,
            width: style.borderWidth ?? 1)
        : null;
    final radius = style.borderRadius == null
        ? null
        : BorderRadius.circular(style.borderRadius!);

    BarChartRodData rod(int s, int x, {required double toY, Color? color}) {
      final gradient = allSeries[s].gradient;
      return BarChartRodData(
        toY: toY,
        color: color ??
            (allSeries.length == 1
                ? allSeries[s].colorAt(x, seriesIndex: s)
                : allSeries[s].color(seriesIndex: s)),
        gradient: gradient.length >= 2
            ? LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: gradient)
            : null,
        width: style.width,
        borderRadius: radius,
        borderSide: border,
        backDrawRodData: background,
        toYErrorRange: errorAt(s, x),
      );
    }

    BarChartGroupData group(int x) {
      if (!style.stacked || allSeries.isEmpty) {
        return BarChartGroupData(
          x: x,
          barsSpace: style.barSpace,
          barRods: [
            for (var s = 0; s < allSeries.length; s++)
              rod(s, x, toY: valueAt(s, x)),
          ],
        );
      }
      // One rod split into a part per series. Every series gets a part, even
      // an empty one, so a touched part's index is its series index.
      final items = <BarChartRodStackItem>[];
      double top = 0;
      for (var s = 0; s < allSeries.length; s++) {
        final value = max(valueAt(s, x), 0.0);
        items.add(BarChartRodStackItem(
            top, top + value, allSeries[s].color(seriesIndex: s)));
        top += value;
      }
      return BarChartGroupData(x: x, barRods: [
        BarChartRodData(
          toY: top,
          color: Colors.transparent,
          rodStackItems: items,
          width: style.width,
          borderRadius: radius,
          borderSide: border,
          backDrawRodData: background,
        ),
      ]);
    }

    // fl_chart can't zoom bars sideways when they're packed to one side.
    final packed = style.alignment == BarChartAlignment.center ||
        style.alignment == BarChartAlignment.start ||
        style.alignment == BarChartAlignment.end;
    return BarChart(
      transformationConfig: _controller.zoom.config(allowHorizontal: !packed),
      BarChartData(
        rotationQuarterTurns: _controller.quarterTurns,
        errorIndicatorData:
            _controller.errorBars.data<BarChartSpotErrorRangeCallbackInput>(),
        alignment: style.alignment,
        groupsSpace: style.groupSpace,
        minY: _controller.yAxis.min,
        maxY: _controller.yAxis.max,
        gridData: _grid,
        borderData: _axisLines,
        titlesData: _titles(labelsOnX: true),
        extraLinesData: _referenceLines(vertical: false),
        barTouchData: BarTouchData(
          enabled: _touchEnabled,
          handleBuiltInTouches: _controller.touchTooltip.show,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: _controller.touchTooltip.backgroundColor == null
                ? defaultBarTooltipColor
                : (_) => _controller.touchTooltip.backgroundColor!,
            tooltipBorderRadius: _tooltipRadius,
            getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                BarTooltipItem(
              style.stacked
                  ? ChartData.format(rod.toY)
                  : _tooltipText(rodIndex, rod.toY),
              _tooltipTextStyle,
            ),
          ),
          touchCallback: (event, response) {
            final spot = response?.spot;
            if (event is! FlTapUpEvent || spot == null) return;
            final seriesIndex = style.stacked
                ? max(spot.touchedStackItemIndex, 0)
                : spot.touchedRodDataIndex;
            _onTap(seriesIndex, spot.touchedBarGroupIndex);
          },
        ),
        barGroups: [for (var x = 0; x < count; x++) group(x)],
      ),
      duration: _controller.animationDuration,
    );
  }

  Widget _buildLineChart() {
    final style = _controller.lineStyle;
    final allSeries = _controller.series;
    return LineChart(
      transformationConfig: _controller.zoom.config(allowHorizontal: true),
      LineChartData(
        rotationQuarterTurns: _controller.quarterTurns,
        minX: _controller.xAxis.min,
        maxX: _controller.xAxis.max,
        minY: _controller.yAxis.min,
        maxY: _controller.yAxis.max,
        gridData: _grid,
        borderData: _axisLines,
        titlesData: _titles(labelsOnX: true),
        extraLinesData: _referenceLines(vertical: true),
        lineTouchData: LineTouchData(
          enabled: _touchEnabled,
          handleBuiltInTouches: _controller.touchTooltip.show,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: _controller.touchTooltip.backgroundColor == null
                ? defaultLineTooltipColor
                : (_) => _controller.touchTooltip.backgroundColor!,
            tooltipBorderRadius: _tooltipRadius,
            getTooltipItems: (spots) => [
              for (final spot in spots)
                LineTooltipItem(
                    _tooltipText(spot.barIndex, spot.y), _tooltipTextStyle),
            ],
          ),
          touchCallback: (event, response) {
            final spots = response?.lineBarSpots;
            if (event is! FlTapUpEvent || spots == null || spots.isEmpty) {
              return;
            }
            _onTap(spots.first.barIndex, spots.first.spotIndex);
          },
        ),
        lineBarsData: [
          for (var s = 0; s < allSeries.length; s++)
            _line(allSeries[s], s, style),
        ],
      ),
      duration: _controller.animationDuration,
    );
  }

  LineChartBarData _line(ChartSeries series, int s, LineStyle style) {
    final color = series.color(seriesIndex: s);
    return LineChartBarData(
      // A value that can't be read leaves a gap in the line.
      spots: [
        for (final point in series.points)
          point.y == null
              ? FlSpot.nullSpot
              : FlSpot(point.x, point.y!,
                  xError: point.xError, yError: point.yError),
      ],
      color: color,
      gradient: series.gradient.length >= 2
          ? LinearGradient(colors: series.gradient)
          : null,
      barWidth: style.width ?? 2,
      isCurved: style.curved,
      curveSmoothness: style.curveSmoothness ?? 0.35,
      preventCurveOverShooting: style.preventCurveOvershoot,
      isStepLineChart: style.stepped,
      dashArray: style.dashArray,
      isStrokeCapRound: true,
      errorIndicatorData:
          _controller.errorBars.data<LineChartSpotErrorRangeCallbackInput>(),
      dotData: FlDotData(
        show: style.showDots,
        getDotPainter: (spot, _, __, index) => FlDotCirclePainter(
          radius: (index < series.points.length
                  ? series.points[index].size
                  : null) ??
              style.dotSize ??
              4,
          color: (index < series.points.length
                  ? series.points[index].color
                  : null) ??
              color,
          strokeWidth: 0,
        ),
      ),
      belowBarData: BarAreaData(
        show: style.fillArea,
        color: color.withValues(alpha: style.fillOpacity ?? 0.2),
      ),
    );
  }

  Widget _buildScatterChart() {
    final style = _controller.scatterStyle;
    final allSeries = _controller.series;
    final spots = <ScatterSpot>[];
    // Each dot's series and index, to report which one was tapped.
    final sources = <(int, int)>[];
    for (var s = 0; s < allSeries.length; s++) {
      final series = allSeries[s];
      for (var i = 0; i < series.points.length; i++) {
        final point = series.points[i];
        if (point.y == null) continue;
        spots.add(ScatterSpot(
          point.x,
          point.y!,
          xError: point.xError,
          yError: point.yError,
          renderPriority: point.priority,
          dotPainter: FlDotCirclePainter(
            radius: point.size ?? style.dotSize ?? 6,
            color: point.color ??
                (series.colors.length > 1
                    ? series.colorAt(i, seriesIndex: s)
                    : series.color(seriesIndex: s)),
            strokeWidth: style.borderWidth ?? 0,
            strokeColor: style.borderColor ?? Colors.transparent,
          ),
        ));
        sources.add((s, i));
      }
    }

    return ScatterChart(
      transformationConfig: _controller.zoom.config(allowHorizontal: true),
      ScatterChartData(
        scatterSpots: spots,
        rotationQuarterTurns: _controller.quarterTurns,
        errorIndicatorData: _controller.errorBars
            .data<ScatterChartSpotErrorRangeCallbackInput>(),
        minX: _controller.xAxis.min,
        maxX: _controller.xAxis.max,
        minY: _controller.yAxis.min,
        maxY: _controller.yAxis.max,
        gridData: _grid,
        borderData: _axisLines,
        titlesData: _titles(labelsOnX: false),
        scatterTouchData: ScatterTouchData(
          enabled: _touchEnabled,
          handleBuiltInTouches: _controller.touchTooltip.show,
          touchTooltipData: ScatterTouchTooltipData(
            getTooltipColor: _controller.touchTooltip.backgroundColor == null
                ? defaultScatterTooltipColor
                : (_) => _controller.touchTooltip.backgroundColor!,
            tooltipBorderRadius: _tooltipRadius,
            getTooltipItems: (spot) => ScatterTooltipItem(
              '(${ChartData.format(spot.x)}, ${ChartData.format(spot.y)})',
              textStyle: _tooltipTextStyle,
            ),
          ),
          touchCallback: (event, response) {
            final index = response?.touchedSpot?.spotIndex;
            if (event is! FlTapUpEvent ||
                index == null ||
                index < 0 ||
                index >= sources.length) {
              return;
            }
            _onTap(sources[index].$1, sources[index].$2);
          },
        ),
      ),
      duration: _controller.animationDuration,
    );
  }

  Widget _buildRadarChart() {
    final style = _controller.radarStyle;
    final allSeries = _controller.series;
    final labels = _controller.labels;
    // fl_chart needs at least 3 axes and the same number of values in every
    // series, so shorter series are padded with 0.
    final axes =
        allSeries.fold<int>(labels.length, (n, s) => max(n, s.points.length));
    if (allSeries.isEmpty || axes < 3) return const SizedBox.shrink();

    final grid = style.gridColor == null
        ? null
        : BorderSide(color: style.gridColor!, width: 1);
    return RadarChart(
      RadarChartData(
        dataSets: [
          for (var s = 0; s < allSeries.length; s++)
            RadarDataSet(
              dataEntries: [
                for (var i = 0; i < axes; i++)
                  RadarEntry(
                      value: i < allSeries[s].points.length
                          ? allSeries[s].values[i]
                          : 0),
              ],
              fillColor: allSeries[s]
                  .color(seriesIndex: s)
                  .withValues(alpha: style.fillOpacity ?? 0.2),
              borderColor: allSeries[s].color(seriesIndex: s),
              borderWidth: style.lineWidth ?? 2,
              entryRadius: style.dotSize ?? 3,
            ),
        ],
        radarShape: style.shape,
        radarBackgroundColor: style.backgroundColor ?? Colors.transparent,
        radarBorderData: style.borderColor == null
            ? null
            : BorderSide(color: style.borderColor!, width: 1),
        gridBorderData: grid,
        tickBorderData: grid,
        tickCount: style.tickCount,
        ticksTextStyle: style.tickStyle,
        titleTextStyle: _textStyle.merge(style.labelStyle),
        titlePositionPercentageOffset: style.labelPosition,
        isMinValueAtCenter: style.minValueAtCenter,
        getTitle: labels.isEmpty
            ? null
            : (index, _) => RadarChartTitle(
                text: index < labels.length ? labels[index] : ''),
        radarTouchData: RadarTouchData(
          enabled: _controller.onTap != null,
          touchCallback: (event, response) {
            final spot = response?.touchedSpot;
            if (event is FlTapUpEvent && spot != null) {
              _onTap(spot.touchedDataSetIndex, spot.touchedRadarEntryIndex);
            }
          },
        ),
      ),
      duration: _controller.animationDuration,
    );
  }
}
