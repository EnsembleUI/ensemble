import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

class EnsembleSignatureController extends WidgetController {
  Color penColor = Colors.black;
  double penStrokeWidth = 3.0;
  Color backgroundColor = Colors.transparent;
  double? height, width;
  Color? exportBackgroundColor;
  Color? exportPenColor;
  SignatureController createSignatureController() {
    return SignatureController(
        penStrokeWidth: penStrokeWidth,
        penColor: penColor,
        exportBackgroundColor: exportBackgroundColor,
        exportPenColor: exportPenColor);
  }
}

class EnsembleSignature extends StatefulWidget
    with
        Invokable,
        HasController<EnsembleSignatureController, EnsembleSignatureState> {
  static const type = 'Signature';
  EnsembleSignature({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => EnsembleSignatureState();
  final EnsembleSignatureController _controller = EnsembleSignatureController();
  @override
  get controller => _controller;

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
      'penColor': (color) {
        Color? c = Utils.getColor(color);
        if (c != null) {
          controller.penColor = c;
        }
      },
      'backgroundColor': (color) => controller.backgroundColor =
          Utils.getColor(color) ?? controller.backgroundColor,
      'width': (w) => controller.width = Utils.optionalDouble(w),
      'height': (h) => controller.height = Utils.optionalDouble(h),
      'penStrokeWidth': (w) => controller.penStrokeWidth =
          Utils.getDouble(w, fallback: controller.penStrokeWidth)
    };
  }
}

class EnsembleSignatureState extends EWidgetState<EnsembleSignature> {
  @override
  Widget buildWidget(BuildContext context) {
    return Signature(
        controller: widget._controller.createSignatureController(),
        backgroundColor: widget.controller.backgroundColor,
        width: widget.controller.width,
        height: widget.controller.height);
  }
}
