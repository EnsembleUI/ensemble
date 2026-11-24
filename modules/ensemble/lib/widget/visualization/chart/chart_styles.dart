import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/util/utils.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Reads `dashed`: `true` for the default dash, or `[dash, gap]` in pixels.
List<int>? parseDash(dynamic value) {
  if (value is List) {
    final dash =
        value.map((v) => Utils.optionalInt(v, min: 1)).whereType<int>();
    return dash.length >= 2 ? dash.toList() : null;
  }
  return Utils.optionalBool(value) == true ? const [6, 4] : null;
}

Map _map(dynamic value) => value is Map ? value : const {};

/// `styles.pieStyle`, used by `type: pie` and `type: doughnut`.
class PieStyle {
  PieStyle.from(dynamic value)
      : holeSize = _map(value)['holeSize'],
        holeColor = Utils.getColor(_map(value)['holeColor']),
        spacing = Utils.optionalDouble(_map(value)['spacing'], min: 0),
        startAngle = Utils.optionalDouble(_map(value)['startAngle']),
        showValues = Utils.optionalBool(_map(value)['showValues']) ?? false,
        valueType = PieValueType.values.from(_map(value)['valueType']) ??
            PieValueType.value,
        valueStyle = Utils.getTextStyle(_map(value)['valueStyle']),
        valuePosition =
            Utils.optionalDouble(_map(value)['valuePosition'], min: 0, max: 1),
        borderColor = Utils.getColor(_map(value)['borderColor']),
        borderWidth = Utils.optionalDouble(_map(value)['borderWidth'], min: 0);

  /// Radius of the empty middle, in pixels (`54`) or as a share of the
  /// chart's radius (`'50%'`). 0 draws a full pie. When not set, a doughnut
  /// uses 50% and a pie 0.
  final dynamic holeSize;
  final Color? holeColor;

  /// Gap between slices, in pixels.
  final double? spacing;

  /// Where the first slice starts, in degrees clockwise from 12 o'clock.
  final double? startAngle;

  /// Writes each slice's value on it.
  final bool showValues;

  /// Shows the value itself or its share of the total.
  final PieValueType valueType;
  final TextStyle? valueStyle;

  /// Where the value sits: 0 is the inner edge of the slice, 1 the outer edge.
  final double? valuePosition;

  final Color? borderColor;
  final double? borderWidth;

  /// The hole's radius in pixels for a chart of [radius].
  double holeRadius(double radius, {required bool doughnut}) {
    final value = holeSize;
    if (value is String && value.trim().endsWith('%')) {
      final percent = double.tryParse(value.trim().replaceFirst('%', '')) ?? 0;
      return (radius * percent / 100).clamp(0, radius);
    }
    final pixels = Utils.optionalDouble(value);
    if (pixels != null) return pixels.clamp(0, radius);
    return doughnut ? radius / 2 : 0;
  }
}

/// What [PieStyle.showValues] writes on a slice: `value` or `percent`.
enum PieValueType { value, percent }

/// `styles.barStyle`, used by `type: bar`.
class BarStyle {
  BarStyle.from(dynamic value)
      : width = Utils.optionalDouble(_map(value)['width'], min: 0),
        borderRadius =
            Utils.optionalDouble(_map(value)['borderRadius'], min: 0),
        groupSpace = Utils.optionalDouble(_map(value)['groupSpace'], min: 0),
        barSpace = Utils.optionalDouble(_map(value)['barSpace'], min: 0),
        stacked = Utils.optionalBool(_map(value)['stacked']) ?? false,
        alignment = BarChartAlignment.values.from(_map(value)['alignment']),
        backgroundColor = Utils.getColor(_map(value)['backgroundColor']),
        borderColor = Utils.getColor(_map(value)['borderColor']),
        borderWidth = Utils.optionalDouble(_map(value)['borderWidth'], min: 0);

  /// Width of each bar, in pixels.
  final double? width;

  /// Corner radius of each bar, in pixels.
  final double? borderRadius;

  /// Space between groups, used with `alignment: center`, `start` or `end`.
  final double? groupSpace;

  /// Space between the bars of one group.
  final double? barSpace;

  /// Stacks the series on top of each other instead of side by side.
  final bool stacked;

  /// start, end, center, spaceEvenly, spaceAround or spaceBetween.
  final BarChartAlignment? alignment;

  /// Draws a track behind each bar, up to the top of the y axis.
  final Color? backgroundColor;

  final Color? borderColor;
  final double? borderWidth;
}

/// `styles.lineStyle`, used by `type: line`.
class LineStyle {
  LineStyle.from(dynamic value)
      : width = Utils.optionalDouble(_map(value)['width'], min: 0),
        curved = Utils.optionalBool(_map(value)['curved']) ?? false,
        curveSmoothness = Utils.optionalDouble(_map(value)['curveSmoothness'],
            min: 0, max: 1),
        preventCurveOvershoot =
            Utils.optionalBool(_map(value)['preventCurveOvershoot']) ?? false,
        stepped = Utils.optionalBool(_map(value)['stepped']) ?? false,
        dashArray = parseDash(_map(value)['dashed']),
        fillArea = Utils.optionalBool(_map(value)['fillArea']) ?? false,
        fillOpacity =
            Utils.optionalDouble(_map(value)['fillOpacity'], min: 0, max: 1),
        showDots = Utils.optionalBool(_map(value)['showDots']) ?? false,
        dotSize = Utils.optionalDouble(_map(value)['dotSize'], min: 0);

  /// Line thickness, in pixels.
  final double? width;

  /// Draws smooth curves instead of straight segments.
  final bool curved;

  /// How round the curves are, from 0 to 1.
  final double? curveSmoothness;

  /// Keeps curves from overshooting past the values.
  final bool preventCurveOvershoot;

  /// Draws steps instead of slopes between values.
  final bool stepped;

  /// `dashed: true`, or `[dash, gap]` in pixels.
  final List<int>? dashArray;

  /// Fills the area under each line with a light shade of its color.
  final bool fillArea;

  /// Opacity of that fill, from 0 to 1.
  final double? fillOpacity;

  /// Shows a dot on each value.
  final bool showDots;

  /// Dot radius, in pixels, unless a point sets its own `size`.
  final double? dotSize;
}

/// `styles.radarStyle`, used by `type: radar`.
class RadarStyle {
  RadarStyle.from(dynamic value)
      : shape = RadarShape.values.from(_map(value)['shape']),
        tickCount = Utils.optionalInt(_map(value)['tickCount'], min: 1),
        tickStyle = Utils.getTextStyle(_map(value)['tickStyle']),
        labelStyle = Utils.getTextStyle(_map(value)['labelStyle']),
        labelPosition = Utils.optionalDouble(_map(value)['labelPosition']),
        gridColor = Utils.getColor(_map(value)['gridColor']),
        borderColor = Utils.getColor(_map(value)['borderColor']),
        backgroundColor = Utils.getColor(_map(value)['backgroundColor']),
        lineWidth = Utils.optionalDouble(_map(value)['lineWidth'], min: 0),
        fillOpacity =
            Utils.optionalDouble(_map(value)['fillOpacity'], min: 0, max: 1),
        dotSize = Utils.optionalDouble(_map(value)['dotSize'], min: 0);

  /// circle or polygon.
  final RadarShape? shape;

  /// Number of rings, and their scale labels.
  final int? tickCount;
  final TextStyle? tickStyle;

  /// Style of the `labels` at the end of each axis.
  final TextStyle? labelStyle;

  /// How far out the labels sit: 0 at the edge, more to move them out.
  final double? labelPosition;

  /// Color of the rings and the lines from the middle.
  final Color? gridColor;

  /// Color of the outer ring.
  final Color? borderColor;
  final Color? backgroundColor;

  /// Outline width of each series.
  final double? lineWidth;

  /// Opacity of each series' fill, from 0 to 1.
  final double? fillOpacity;

  /// Radius of the dot on each value, in pixels.
  final double? dotSize;
}

/// `styles.scatterStyle`, used by `type: scatter`.
class ScatterStyle {
  ScatterStyle.from(dynamic value)
      : dotSize = Utils.optionalDouble(_map(value)['dotSize'], min: 0),
        borderColor = Utils.getColor(_map(value)['borderColor']),
        borderWidth = Utils.optionalDouble(_map(value)['borderWidth'], min: 0);

  /// Dot radius, unless a point sets its own `size`.
  final double? dotSize;
  final Color? borderColor;
  final double? borderWidth;
}
