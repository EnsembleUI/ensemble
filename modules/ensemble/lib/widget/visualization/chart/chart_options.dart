import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/visualization/chart/chart_styles.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

Map _map(dynamic value) => value is Map ? value : const {};

/// `xAxis` and `yAxis`, used by line, bar and scatter charts.
class ChartAxis {
  ChartAxis.from(dynamic value)
      : min = Utils.optionalDouble(_map(value)['min']),
        max = Utils.optionalDouble(_map(value)['max']),
        show = Utils.optionalBool(_map(value)['show']) ?? true,
        interval = Utils.optionalDouble(_map(value)['interval'], min: 0),
        labelStyle = Utils.getTextStyle(_map(value)['labelStyle']),
        labelSize = Utils.optionalDouble(_map(value)['labelSize'], min: 0),
        title = Utils.optionalString(_map(value)['title']),
        titleStyle = Utils.getTextStyle(_map(value)['titleStyle']),
        lineColor = Utils.getColor(_map(_map(value)['line'])['color']),
        lineWidth =
            Utils.optionalDouble(_map(_map(value)['line'])['width'], min: 0);

  /// Lowest and highest value shown. Bar charts only use them on the y axis.
  final double? min;
  final double? max;

  /// Shows the axis labels.
  final bool show;

  /// Distance between two labels, in values.
  final double? interval;
  final TextStyle? labelStyle;

  /// Space kept for the labels, in pixels.
  final double? labelSize;

  /// A name shown along the axis.
  final String? title;
  final TextStyle? titleStyle;

  /// Draws the axis line (`line: {color, width}`).
  final Color? lineColor;
  final double? lineWidth;

  bool get showLine => lineColor != null || lineWidth != null;

  BorderSide get lineSide => showLine
      ? BorderSide(
          color: lineColor ?? const Color(0xFF9E9E9E), width: lineWidth ?? 1)
      : BorderSide.none;
}

/// `grid`, the lines behind line, bar and scatter charts.
class ChartGrid {
  ChartGrid.from(dynamic value)
      : show = Utils.optionalBool(_map(value)['show']) ?? true,
        horizontal = Utils.optionalBool(_map(value)['horizontal']) ?? true,
        vertical = Utils.optionalBool(_map(value)['vertical']) ?? false,
        horizontalInterval =
            Utils.optionalDouble(_map(value)['horizontalInterval'], min: 0),
        verticalInterval =
            Utils.optionalDouble(_map(value)['verticalInterval'], min: 0),
        color = Utils.getColor(_map(value)['color']),
        width = Utils.optionalDouble(_map(value)['width'], min: 0),
        dashArray = parseDash(_map(value)['dashed']);

  final bool show;

  /// Draws lines across (on by default) and down (off by default).
  final bool horizontal;
  final bool vertical;
  final double? horizontalInterval;
  final double? verticalInterval;
  final Color? color;
  final double? width;

  /// `dashed: true`, or `[dash, gap]` in pixels.
  final List<int>? dashArray;
}

/// `clip`: cuts off the lines and dots of line and scatter charts where they
/// go past the edge of the plot, such as values below `xAxis.min`. fl_chart
/// can't clip bar charts.
/// `true` clips every side, or a map picks the sides:
/// `{left: true, right: true}`. Off by default, so a dot exactly on an edge
/// is drawn whole.
class ChartClip {
  ChartClip.from(dynamic value) : data = _parse(value);

  final FlClipData data;

  static FlClipData _parse(dynamic value) {
    if (value is Map) {
      bool side(String name) => Utils.optionalBool(value[name]) ?? false;
      return FlClipData(
        top: side('top'),
        bottom: side('bottom'),
        left: side('left'),
        right: side('right'),
      );
    }
    return Utils.optionalBool(value) == true
        ? const FlClipData.all()
        : const FlClipData.none();
  }
}

/// `frame`: a border around the plot of line, bar and scatter charts.
/// `true` draws all four sides in the grid's color, or a map sets `color`,
/// `width` and which sides to draw (`top`, `right`, `bottom`, `left`, all on
/// by default). `xAxis.line` and `yAxis.line` still draw the bottom and left
/// side when set.
class ChartFrame {
  ChartFrame.from(dynamic value)
      : show = value is Map
            ? Utils.optionalBool(value['show']) ?? true
            : Utils.optionalBool(value) ?? false,
        color = Utils.getColor(_map(value)['color']),
        width = Utils.optionalDouble(_map(value)['width'], min: 0),
        top = Utils.optionalBool(_map(value)['top']) ?? true,
        right = Utils.optionalBool(_map(value)['right']) ?? true,
        bottom = Utils.optionalBool(_map(value)['bottom']) ?? true,
        left = Utils.optionalBool(_map(value)['left']) ?? true;

  final bool show;

  /// Default to the grid's color and width, so the frame looks like the
  /// outer grid lines.
  final Color? color;
  final double? width;
  final bool top;
  final bool right;
  final bool bottom;
  final bool left;

  /// The border on one side, or none when the frame or that side is off.
  BorderSide side(bool on, ChartGrid grid) => show && on
      ? BorderSide(
          color: color ?? grid.color ?? const Color(0x33000000),
          width: width ?? grid.width ?? 1)
      : BorderSide.none;
}

/// `zoom`: pinch to zoom and drag to pan line, bar and scatter charts.
class ChartZoom {
  ChartZoom.from(dynamic value)
      : axis = FlScaleAxis.values.from(_map(value)['axis']) ?? FlScaleAxis.none,
        minScale = Utils.optionalDouble(_map(value)['minScale'], min: 1),
        maxScale = Utils.optionalDouble(_map(value)['maxScale'], min: 1),
        pan = Utils.optionalBool(_map(value)['pan']) ?? true,
        scale = Utils.optionalBool(_map(value)['scale']) ?? true;

  /// Which way the chart zooms: none (default), horizontal, vertical or free.
  final FlScaleAxis axis;
  final double? minScale;
  final double? maxScale;

  /// Allows dragging and pinching. Both on by default once an axis is set.
  final bool pan;
  final bool scale;

  FlTransformationConfig config({required bool allowHorizontal}) {
    // A bar chart can't zoom sideways with alignment center, start or end.
    final scaleAxis = !allowHorizontal &&
            (axis == FlScaleAxis.horizontal || axis == FlScaleAxis.free)
        ? (axis == FlScaleAxis.free ? FlScaleAxis.vertical : FlScaleAxis.none)
        : axis;
    return FlTransformationConfig(
      scaleAxis: scaleAxis,
      minScale: minScale ?? 1,
      maxScale: maxScale ?? 2.5,
      panEnabled: pan,
      scaleEnabled: scale,
    );
  }
}

/// `errorBars`: how the `xError` and `yError` of values are drawn.
class ChartErrorBars {
  ChartErrorBars.from(dynamic value)
      : show = value is Map
            ? Utils.optionalBool(value['show']) ?? true
            : Utils.optionalBool(value) ?? true,
        color = Utils.getColor(_map(value)['color']),
        width = Utils.optionalDouble(_map(value)['width'], min: 0),
        capLength = Utils.optionalDouble(_map(value)['capLength'], min: 0),
        showValues = Utils.optionalBool(_map(value)['showValues']) ?? false,
        valueStyle = Utils.getTextStyle(_map(value)['valueStyle']);

  final bool show;
  final Color? color;
  final double? width;

  /// Width of the cap at each end, in pixels.
  final double? capLength;

  /// Writes the range next to each bar.
  final bool showValues;
  final TextStyle? valueStyle;

  FlErrorIndicatorData<T> data<T extends FlSpotErrorRangeCallbackInput>() =>
      FlErrorIndicatorData<T>(
        show: show,
        painter: (_) => FlSimpleErrorPainter(
          lineColor: color ?? const Color(0xFF757575),
          lineWidth: width ?? 1,
          capLength: capLength ?? 8,
          showErrorTexts: showValues,
          errorTextStyle: valueStyle ??
              const TextStyle(color: Color(0xFF757575), fontSize: 12),
        ),
      );
}

enum ChartLegendPosition { top, bottom, left, right }

/// `legend`: a key of colors and names. Lists the `labels` for pie and
/// doughnut charts, and each series' `label` for the others.
class ChartLegend {
  ChartLegend.from(dynamic value)
      : show = value is Map
            ? Utils.optionalBool(value['show']) ?? true
            : Utils.optionalBool(value) ?? false,
        position = ChartLegendPosition.values.from(_map(value)['position']) ??
            ChartLegendPosition.bottom,
        textStyle = Utils.getTextStyle(_map(value)['textStyle']),
        iconSize = Utils.optionalDouble(_map(value)['iconSize'], min: 0) ?? 10,
        spacing = Utils.optionalDouble(_map(value)['spacing'], min: 0) ?? 12;

  final bool show;
  final ChartLegendPosition position;
  final TextStyle? textStyle;
  final double iconSize;

  /// Space between the entries, and between the legend and the chart.
  final double spacing;
}

/// `touchTooltip`: the value shown while a bar, line or dot is touched.
class ChartTooltip {
  ChartTooltip.from(dynamic value)
      : show = value is Map
            ? Utils.optionalBool(value['show']) ?? true
            : Utils.optionalBool(value) ?? true,
        backgroundColor = Utils.getColor(_map(value)['backgroundColor']),
        textStyle = Utils.getTextStyle(_map(value)['textStyle']),
        borderRadius =
            Utils.optionalDouble(_map(value)['borderRadius'], min: 0);

  final bool show;
  final Color? backgroundColor;
  final TextStyle? textStyle;
  final double? borderRadius;
}

/// One of `referenceLines`: a line across the chart at a `y` (horizontal) or
/// an `x` (vertical) value, such as a target or an average.
class ChartReferenceLine {
  ChartReferenceLine._(Map value)
      : x = Utils.optionalDouble(value['x']),
        y = Utils.optionalDouble(value['y']),
        color = Utils.getColor(value['color']),
        width = Utils.optionalDouble(value['width'], min: 0),
        dashArray = parseDash(value['dashed']),
        label = Utils.optionalString(value['label']),
        labelStyle = Utils.getTextStyle(value['labelStyle']);

  final double? x;
  final double? y;
  final Color? color;
  final double? width;
  final List<int>? dashArray;
  final String? label;
  final TextStyle? labelStyle;

  /// Lines without an x or a y are skipped.
  static List<ChartReferenceLine> parse(dynamic value) => [
        if (value is List)
          for (final line in value)
            if (line is Map && (line['x'] != null || line['y'] != null))
              ChartReferenceLine._(line),
      ];
}
