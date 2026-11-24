import 'package:ensemble/util/utils.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// The kinds of chart [Chart] can draw.
enum ChartType {
  line,
  bar,
  pie,
  doughnut,
  radar,
  scatter;

  bool get isCircular => this == pie || this == doughnut;

  /// Types drawn on an x and a y axis.
  bool get hasAxes => this == line || this == bar || this == scatter;
}

/// One value in a series. [x] is the value's position on the x axis: its
/// index, unless the YAML gives one (`[x, y]` or `{x, y}`). [y] is null for a
/// value that can't be read, which a line draws as a gap.
class ChartPoint {
  const ChartPoint(this.x, this.y,
      {this.size, this.color, this.xError, this.yError, this.priority});

  final double x;
  final double? y;

  /// Dot radius, for scatter charts.
  final double? size;
  final Color? color;

  /// How far the value may be off, drawn as error bars. [yError] works for
  /// line, bar and scatter charts; [xError] for line and scatter charts.
  final FlErrorRange? xError;
  final FlErrorRange? yError;

  /// Scatter dots with a higher priority are drawn on top.
  final int? priority;
}

/// One series of values, such as one line, one set of bars or the slices of a
/// pie.
class ChartSeries {
  const ChartSeries({
    required this.points,
    this.colors = const [],
    this.gradient = const [],
    this.label,
  });

  final List<ChartPoint> points;

  /// One color for the whole series, or one per value (per bar or slice).
  final List<Color> colors;

  /// Colors to blend along each bar or along the line, in place of [colors].
  final List<Color> gradient;
  final String? label;

  /// The y values, with values that can't be read as 0.
  List<double> get values => [for (final p in points) p.y ?? 0];

  /// The color of the value at [index]. Falls back to the first color, then to
  /// the default palette.
  Color colorAt(int index, {required int seriesIndex}) {
    if (colors.length > index) return colors[index];
    if (colors.length == 1) return colors.first;
    return ChartData.paletteColor(colors.isEmpty ? seriesIndex + index : index);
  }

  /// The series' own color, for a line, a radar shape or a legend entry.
  Color color({required int seriesIndex}) =>
      colors.isNotEmpty ? colors.first : ChartData.paletteColor(seriesIndex);
}

/// Reads chart values from YAML or JS.
///
/// Values can be written as a plain YAML list, come whole from an expression
/// (`data: ${myData}`), or be a YAML list with expressions inside. Expressions
/// often give strings, so numbers are also read from strings, and colors use
/// Ensemble's usual color parsing (`#hex`, names, `0x` numbers).
class ChartData {
  static const List<Color> defaultPalette = [
    Color(0xFF36A2EB),
    Color(0xFFFF6384),
    Color(0xFFFF9F40),
    Color(0xFF4BC0C0),
    Color(0xFF9966FF),
    Color(0xFFFFCD56),
  ];

  static Color paletteColor(int index) =>
      defaultPalette[index % defaultPalette.length];

  /// Reads `data`. Accepts:
  /// - a list of series: `[{values: [1, 2], colors: ['#f00'], label: 'A'}]`
  /// - a plain list of values, as a single series: `[1, 2, 3]`
  ///
  /// Anything else gives no series, so a binding that hasn't resolved yet
  /// draws an empty chart instead of failing.
  static List<ChartSeries> parseSeries(dynamic data) {
    if (data is! List || data.isEmpty) return const [];
    if (data.every((item) => item is! Map || _isPoint(item))) {
      return [ChartSeries(points: parsePoints(data))];
    }
    return [
      for (final item in data)
        if (item is Map)
          ChartSeries(
            points: parsePoints(item['values']),
            colors: parseColors(item['colors'] ?? item['color']),
            gradient: parseColors(item['gradient']),
            label: Utils.optionalString(item['label']),
          ),
    ];
  }

  /// A map with x or y is a point, not a series.
  static bool _isPoint(Map item) =>
      item.containsKey('y') || item.containsKey('x');

  /// Reads each value as a number, `[x, y]`, `[x, y, size]` or
  /// `{x, y, size, color, xError, yError, priority}`. A plain number sits at
  /// its index on the x axis.
  static List<ChartPoint> parsePoints(dynamic values) {
    if (values is! List) return const [];
    final points = <ChartPoint>[];
    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      if (value is List) {
        points.add(ChartPoint(
          value.isNotEmpty
              ? parseNumber(value[0]) ?? i.toDouble()
              : i.toDouble(),
          value.length > 1 ? parseNumber(value[1]) : null,
          size: value.length > 2 ? parseNumber(value[2]) : null,
        ));
      } else if (value is Map) {
        points.add(ChartPoint(
          parseNumber(value['x']) ?? i.toDouble(),
          parseNumber(value['y']),
          size: parseNumber(value['size']),
          color: Utils.getColor(value['color']),
          xError: parseErrorRange(value['xError']),
          yError: parseErrorRange(value['yError']),
          priority: Utils.optionalInt(value['priority']),
        ));
      } else {
        points.add(ChartPoint(i.toDouble(), parseNumber(value)));
      }
    }
    return points;
  }

  /// An error range: one number for the same amount below and above, or
  /// `[below, above]`. Negative amounts are ignored.
  static FlErrorRange? parseErrorRange(dynamic value) {
    final below =
        parseNumber(value is List && value.isNotEmpty ? value[0] : value);
    final above = value is List
        ? (value.length > 1 ? parseNumber(value[1]) : null)
        : below;
    if (below == null || above == null || below < 0 || above < 0) return null;
    return FlErrorRange(lowerBy: below, upperBy: above);
  }

  /// A number, or a numeric string. Null for anything else.
  static double? parseNumber(dynamic value) =>
      Utils.optionalDouble(value is String ? value.trim() : value);

  /// One color or a list of colors. Colors that can't be read are skipped.
  static List<Color> parseColors(dynamic colors) {
    final list = colors is List ? colors : (colors == null ? [] : [colors]);
    return list.map(Utils.getColor).whereType<Color>().toList();
  }

  static List<String> parseLabels(dynamic labels) {
    if (labels is! List) return const [];
    return labels.map((label) => Utils.optionalString(label) ?? '').toList();
  }

  /// Shows whole numbers without decimals and others with up to 2.
  static String format(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}
