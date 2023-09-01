import 'dart:math';

import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/model.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';

import '../framework/view/page.dart';

class Shape extends StatefulWidget
    with Invokable, HasController<BoxContainerController, ShapeState> {
  static const type = 'Shape';
  Shape({Key? key}) : super(key: key);

  final BoxContainerController _controller = BoxContainerController();
  @override
  get controller => _controller;

  @override
  State<StatefulWidget> createState() => ShapeState();

  @override
  Map<String, Function> setters() {
    return {
      'type': (type) => _controller.type = ShapeType.values.from(type),
      'width': (value) => _controller.width = Utils.optionalInt(value),
      'height': (value) => _controller.height = Utils.optionalInt(value),
      'borderRadius': (value) => _controller.borderRadius = Utils.getBorderRadius(value),
      'backgroundColor': (color) => _controller.backgroundColor = Utils.getColor(color),

    };
  }

  @override
  Map<String, Function> getters() {
    return {};
  }

  @override
  Map<String, Function> methods() {
    return {};
  }
}

enum ShapeType {
  square, rectangle, circle, oval
}

class BoxContainerController extends WidgetController {
  ShapeType? type;
  int? width;
  int? height;
  EBorderRadius? borderRadius;
  Color? backgroundColor;

}

class ShapeState extends WidgetState<Shape> {
  @override
  Widget buildWidget(BuildContext context) => InternalShape(
      type: widget._controller.type,
      width: widget._controller.width,
      height: widget._controller.height,
      borderRadius: widget._controller.borderRadius?.getValue(),
      backgroundColor: widget._controller.backgroundColor);

}

/// Shape that can also be used internally within our framework
class InternalShape extends StatelessWidget {
  const InternalShape({super.key, this.type, this.width, this.height,
    this.borderRadius, this.backgroundColor});

  final ShapeType? type;
  final int? width;
  final int? height;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    if (width == null && height == null) {
      throw RuntimeError("Shape's width or height is required");
    }
    double w = (width ?? height)!.toDouble();
    double h = (height ?? width)!.toDouble();
    switch (type) {
      case ShapeType.circle:
        return Container(width: w, height: h, decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle));
      case ShapeType.oval:
        return Container(width: w, height: h, decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(100),
            color: backgroundColor,
            shape: BoxShape.rectangle));
      case ShapeType.square:
        return Container(
            width: min(w, h),
            height: min(w, h),
            decoration: BoxDecoration(
                borderRadius: borderRadius,
                color: backgroundColor,
                shape: BoxShape.rectangle));
      case ShapeType.rectangle:
      default:
        return Container(width: w, height: h, decoration: BoxDecoration(
            borderRadius:borderRadius,
            color: backgroundColor,
            shape: BoxShape.rectangle));

    }
  }

}
