import 'package:flutter/material.dart';
import '../chart_js.dart';

class ChartJsState extends ChartJsStateBase {
  @override
  Widget buildWidget(BuildContext context) {
    return const Text("ChartJs is not supported on this platform");
  }

  @override
  void evalScript(String script) {}
}
