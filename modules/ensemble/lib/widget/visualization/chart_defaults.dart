import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

mixin ChartDefaults {
  FlTitlesData titlesData(List<String> labels) {
    return FlTitlesData(
      bottomTitles: AxisTitles(
        sideTitles: bottomTitles(labels),
      ),
      rightTitles: AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
      topTitles: AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
      leftTitles: AxisTitles(
        sideTitles: leftTitles(),
      ),
    );
  }

  SideTitles bottomTitles(List<String> labels) {
    return SideTitles(
        showTitles: true,
        reservedSize: 32,
        interval: 1,
        getTitlesWidget: (double value, TitleMeta meta) {
          const style = TextStyle(
            color: Color(0xff72719b),
            fontWeight: FontWeight.bold,
            fontSize: 12,
          );

          return SideTitleWidget(
            axisSide: meta.axisSide,
            space: 10,
            child: Text(labels[value.toInt()], style: style),
          );
        });
  }

  Widget leftTitleWidgets(double value, TitleMeta meta) {
    const style = TextStyle(
      color: Color(0xff75729e),
      fontWeight: FontWeight.bold,
      fontSize: 11,
    );
    return Text(value.toInt().toString(),
        style: style, textAlign: TextAlign.center);
  }

  SideTitles leftTitles() => SideTitles(
        getTitlesWidget: leftTitleWidgets,
        showTitles: true,
        interval: 10,
        reservedSize: 40,
      );
  LineTouchData get lineTouchData => LineTouchData(
        handleBuiltInTouches: true,
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (group) => Colors.blueGrey.withOpacity(0.8),
        ),
      );
  FlGridData get gridData => FlGridData(show: true);

  FlBorderData get borderData => FlBorderData(
        show: true,
        border: const Border(
          bottom: BorderSide(color: Color(0xff4e4965), width: 4),
          left: BorderSide(color: Colors.transparent),
          right: BorderSide(color: Colors.transparent),
          top: BorderSide(color: Colors.transparent),
        ),
      );
}
