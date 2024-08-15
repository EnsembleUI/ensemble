import 'package:ensemble/framework/studio/studio_debugger.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';

class EnsembleDivider extends StatefulWidget
    with Invokable, HasController<DividerController, DividerState> {
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
      'direction': (value) =>
          _controller.direction = Utils.optionalString(value),
      'margin': (value) => _controller.margin = Utils.getInsets(value),
      'thickness': (value) => _controller.thickness = Utils.optionalInt(value),
      'color': (value) => _controller.color = Utils.getColor(value),
      'indent': (value) => _controller.indent = Utils.optionalInt(value),
      'endIndent': (value) => _controller.endIndent = Utils.optionalInt(value)
    };
  }
}

class DividerController extends WidgetController {
  String? direction;
  EdgeInsets? margin;
  int? thickness;
  Color? color;
  int? indent;
  int? endIndent;
}

class DividerState extends EWidgetState<EnsembleDivider> {
  @override
  Widget buildWidget(BuildContext context) {
    Widget rtn;
    if (widget._controller.direction == 'vertical') {
      rtn = VerticalDivider(
          width: (widget._controller.thickness ?? 1).toDouble(),
          thickness: (widget._controller.thickness ?? 1).toDouble(),
          indent: (widget._controller.indent ?? 0).toDouble(),
          endIndent: (widget._controller.endIndent ?? 0).toDouble(),
          color: widget._controller.color ?? const Color(0xFFD3D3D3));
      rtn = StudioDebugger()
          .assertHasBoundedHeight(rtn, "${EnsembleDivider.type} (vertical)");
    } else {
      rtn = Divider(
          height: (widget._controller.thickness ?? 1).toDouble(),
          thickness: (widget._controller.thickness ?? 1).toDouble(),
          indent: (widget._controller.indent ?? 0).toDouble(),
          endIndent: (widget._controller.endIndent ?? 0).toDouble(),
          color: widget._controller.color ?? const Color(0xFFD3D3D3));
      rtn = StudioDebugger().assertHasBoundedWidth(rtn, EnsembleDivider.type);
    }

    if (widget._controller.margin != null) {
      rtn = Padding(padding: widget._controller.margin!, child: rtn);
    }
    return rtn;
  }
}
