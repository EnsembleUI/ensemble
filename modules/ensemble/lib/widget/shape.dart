import 'dart:math';

import 'package:ensemble/controller/controller_mixins.dart';
import 'package:ensemble/framework/ensemble_widget.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/theme/theme_manager.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:flutter/material.dart';

class Shape extends EnsembleWidget<ShapeController> {
  static const type = 'Shape';

  Shape({super.key});

  @override
  State<StatefulWidget> createState() => ShapeState();

  @override
  ShapeController createController() => ShapeController();
}

enum ShapeVariant { square, rectangle, circle, oval }

class ShapeController extends EnsembleWidgetController
    with HasBorderController {
  ShapeVariant? variant;
  int? width;
  int? height;
  Color? backgroundColor;

  @override
  Map<String, Function> setters() => Map<String, Function>.from(super.setters())
    ..addAll(hasBorderSetters())
    ..addAll({
      'type': (type) => variant = ShapeVariant.values.from(type),
      'width': (value) => width = Utils.optionalInt(value),
      'height': (value) => height = Utils.optionalInt(value),
      'backgroundColor': (color) => backgroundColor = Utils.getColor(color),
    });
}

class ShapeState extends EnsembleWidgetState<Shape> {
  @override
  Widget buildWidget(BuildContext context, ScopeManager scopeManager) =>
      InternalShape(
        type: widget.controller.variant,
        width: widget.controller.width,
        height: widget.controller.height,
        backgroundColor: widget.controller.backgroundColor,
        borderGradient: widget.controller.borderGradient,
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
      this.borderRadius});

  final ShapeVariant? type;
  final int? width;
  final int? height;
  final Color? backgroundColor;

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
    switch (type) {
      case ShapeVariant.circle:
        return Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
                color: backgroundColor,
                shape: BoxShape.circle,
                border: _getBorder(context)));
      case ShapeVariant.oval:
        return Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(100),
                color: backgroundColor,
                shape: BoxShape.rectangle,
                border: _getBorder(context)));
      case ShapeVariant.square:
        return Container(
            width: min(w, h),
            height: min(w, h),
            decoration: BoxDecoration(
                borderRadius: borderRadius,
                color: backgroundColor,
                shape: BoxShape.rectangle,
                border: _getBorder(context)));
      case ShapeVariant.rectangle:
      default:
        return Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
                borderRadius: borderRadius,
                color: backgroundColor,
                shape: BoxShape.rectangle,
                border: _getBorder(context)));
    }
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
