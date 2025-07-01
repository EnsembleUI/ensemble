import 'dart:math';

import 'package:ensemble/controller/controller_mixins.dart';
import 'package:ensemble/framework/ensemble_widget.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/model.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/theme/theme_manager.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/ColorFilter_Composite.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';

import '../framework/view/page.dart';

class Shape extends EnsembleWidget<ShapeController> {
  static const type = 'Shape';

  const Shape._(super.controller, {super.key});

  factory Shape.build(dynamic controller) =>
      Shape._(controller is ShapeController ? controller : ShapeController());

  @override
  State<StatefulWidget> createState() => ShapeState();
}

enum ShapeVariant { square, rectangle, circle, oval }

class ShapeController extends EnsembleWidgetController
    with HasBorderController {
  ShapeVariant? variant;
  int? width;
  int? height;
  Color? backgroundColor;
  ColorFilterComposite? colorFilter;
  BlendMode blendMode = BlendMode.modulate;

  @override
  Map<String, Function> setters() => Map<String, Function>.from(super.setters())
    ..addAll(hasBorderSetters())
    ..addAll({
      'type': (type) => variant = ShapeVariant.values.from(type),
      'width': (value) => width = Utils.optionalInt(value),
      'height': (value) => height = Utils.optionalInt(value),
      'backgroundColor': (color) => backgroundColor = Utils.getColor(color),
      'colorFilter': (value) => colorFilter = ColorFilterComposite.from(value),

    });
}

class ShapeState extends EnsembleWidgetState<Shape> {
  @override
  Widget buildWidget(BuildContext context) => InternalShape(
        type: widget.controller.variant,
        width: widget.controller.width,
        height: widget.controller.height,
        backgroundColor: widget.controller.backgroundColor,
        borderGradient: widget.controller.borderGradient,
        colorFilter: widget.controller.colorFilter!,
        borderColor: widget.controller.borderColor,
        borderWidth: widget.controller.borderWidth,
        borderRadius: widget.controller.borderRadius?.getValue(),
      );
}

/// Shape that can also be used internally within our framework
class InternalShape extends StatelessWidget {
  const InternalShape(
      {super.key,
      this.type,
      this.width,
      this.height,
      this.backgroundColor,
      this.borderGradient,
      this.borderColor,
      this.borderWidth,
      this.colorFilter,
      this.borderRadius});

  final ShapeVariant? type;
  final int? width;
  final int? height;
  final Color? backgroundColor;
  final ColorFilterComposite? colorFilter;

  final LinearGradient? borderGradient;
  final Color? borderColor;
  final int? borderWidth;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    if (width == null && height == null) {
      throw RuntimeError("Shape's width or height is required");
    }
    double w = (width ?? height)!.toDouble();
    double h = (height ?? width)!.toDouble();
    Widget shape;
    switch (type) {
      case ShapeVariant.circle:
        shape = Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
                color: backgroundColor,
                shape: BoxShape.circle,
                border: _getBorder(context)));
      case ShapeVariant.oval:
        shape = Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(100),
                color: backgroundColor,
                shape: BoxShape.rectangle,
                border: _getBorder(context)));
      case ShapeVariant.square:
        shape = Container(
            width: min(w, h),
            height: min(w, h),
            decoration: BoxDecoration(
                borderRadius: borderRadius,
                color: backgroundColor,
                shape: BoxShape.rectangle,
                border: _getBorder(context)));
      case ShapeVariant.rectangle:
      default:
        shape = Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
                borderRadius: borderRadius,
                color: backgroundColor,
                shape: BoxShape.rectangle,
                border: _getBorder(context)));
    }
    if (colorFilter?.color != null) {
        return ColorFiltered(
          colorFilter: colorFilter!.getColorFilter()!,
          child: shape,
        );
    }
    return shape;
  }

  bool _hasBorder() =>
      borderGradient != null || borderColor != null || borderWidth != null;

  BoxBorder? _getBorder(BuildContext context) => !_hasBorder()
      ? null
      : borderGradient != null
          ? GradientBoxBorder(
              gradient: borderGradient!,
              width: borderWidth?.toDouble() ??
                  ThemeManager().getBorderThickness(context))
          : Border.all(
              color: borderColor ?? ThemeManager().getBorderColor(context),
              width: borderWidth?.toDouble() ??
                  ThemeManager().getBorderThickness(context));
}
