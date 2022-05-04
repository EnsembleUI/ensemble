import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';

class EnsembleDivider extends StatefulWidget with Invokable, HasController<DividerController, DividerState> {
  static const type = 'Divider';
  EnsembleDivider({Key? key}) : super(key: key);

  final DividerController _controller = DividerController();
  @override
  DividerController get controller => _controller;

  @override
  State<StatefulWidget> createState() => DividerState();


  @override
  Map<String, Function> getters() {
    return {};
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {
      'thickness': (value) => Utils.getInt(value, fallback: 1),
      'color': (value) => Utils.optionalInt(value),
      'indent': (value) => Utils.optionalInt(value),
      'endIndent': (value) => Utils.optionalInt(value)
    };
  }

}

class DividerController extends WidgetController {
  late int thickness;
  int? color;
  int? indent;
  int? endIndent;
}

class DividerState extends WidgetState<EnsembleDivider> {
  @override
  Widget build(BuildContext context) {
    return Divider(
        thickness: widget._controller.thickness.toDouble(),
        indent: (widget._controller.indent ?? 0).toDouble(),
        endIndent: (widget._controller.endIndent ?? 0).toDouble(),
        color:
          widget._controller.color != null ?
          Color(widget._controller.color!) :
          const Color(0xFFD3D3D3)
    );
  }
}