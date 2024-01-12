/// This class contains common widgets for use with Ensemble widgets.

import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/model.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/studio_debugger.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/layout/form.dart' as ensemble;
import 'package:ensemble/widget/input/form_helper.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/framework/theme/theme_manager.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Wrap around a widget to give it box property.
class EnsembleBoxWrapper extends StatelessWidget {
  const EnsembleBoxWrapper(
      {super.key,
      required this.widget,
      required this.boxController,

      // internal widget may want to handle padding itself (e.g. ListView so
      // its scrollbar lays on top of the padding and not the content)
      this.ignoresPadding = false,

      // sometimes our widget may register a gesture. Such gesture should not
      // include the margin. This allows it to handle the margin on its own.
      this.ignoresMargin = false,

      // width/height maybe applied at the child, or not applicable
      this.ignoresDimension = false,
      this.fallbackWidth,
      this.fallbackHeight,
      this.fallbackBorderRadius});

  final Widget widget;
  final EnsembleBoxController boxController;

  // child widget may want to control these themselves
  final bool ignoresPadding;
  final bool ignoresMargin;
  final bool ignoresDimension;
  final double? fallbackWidth;
  final double? fallbackHeight;
  final EBorderRadius? fallbackBorderRadius;

  bool _requiresBox() =>
      boxController.requiresBox(
          ignoresMargin: ignoresMargin,
          ignoresPadding: ignoresPadding,
          ignoresDimension: ignoresDimension) ||
      (!ignoresDimension &&
          (fallbackWidth != null || fallbackHeight != null)) ||
      fallbackBorderRadius != null;

  bool _hasBoxDecoration() =>
      boxController.hasBoxDecoration() || fallbackBorderRadius != null;

  EBorderRadius? get _borderRadius =>
      boxController.borderRadius ?? fallbackBorderRadius;

  @override
  Widget build(BuildContext context) {
    if (!_requiresBox()) {
      return widget;
    }
    // when we have a border radius, we need to clip the decoration.
    // Note that this clip only apply to the background decoration.
    // Some children (i.e. Images) might need an additional ClipRRect
    Clip clip = Clip.none;
    if (_hasBoxDecoration()) {
      clip = Clip.hardEdge;
    }
    ScopeManager? scopeManager = DataScopeWidget.getScope(context);
    final Widget? backgroundImage =
        boxController.backgroundImage?.getImageAsWidget(scopeManager);

    return Container(
      width: ignoresDimension
          ? null
          : boxController.width?.toDouble() ?? fallbackWidth,
      height: ignoresDimension
          ? null
          : boxController.height?.toDouble() ?? fallbackHeight,
      margin: ignoresMargin ? null : boxController.margin,
      padding: ignoresPadding ? null : boxController.padding,
      clipBehavior: clip,
      decoration: !_hasBoxDecoration()
          ? null
          : BoxDecoration(
              color: boxController.backgroundColor,
              gradient: boxController.backgroundGradient,
              border: !boxController.hasBorder()
                  ? null
                  : boxController.borderGradient != null
                      ? GradientBoxBorder(
                          gradient: boxController.borderGradient!,
                          width: boxController.borderWidth?.toDouble() ??
                              ThemeManager().getBorderThickness(context))
                      : Border.all(
                          color: boxController.borderColor ??
                              ThemeManager().getBorderColor(context),
                          width: boxController.borderWidth?.toDouble() ??
                              ThemeManager().getBorderThickness(context)),
              borderRadius: _borderRadius?.getValue(),
              boxShadow: !boxController.hasBoxShadow()
                  ? null
                  : <BoxShadow>[
                      BoxShadow(
                          color: boxController.shadowColor ??
                              ThemeManager().getShadowColor(context),
                          blurRadius: boxController.shadowRadius?.toDouble() ??
                              ThemeManager().getShadowRadius(context),
                          offset: boxController.shadowOffset ??
                              ThemeManager().getShadowOffset(context),
                          blurStyle: boxController.shadowStyle ??
                              ThemeManager().getShadowStyle(context))
                    ],
            ),
      child: backgroundImage != null
          ? Stack(
              children: [
                Positioned.fill(child: backgroundImage),
                _getWidget(),
              ],
            )
          : _getWidget(),
    );
  }

  /// The child widget need to clip separately from the Container's decoration
  Widget _getWidget() {
    // some widget (i.e. Image) will not respect the Container's boundary
    // even if clipBehavior is enabled. In these case we need to apply
    // an explicit ClipRRect around it. Note also that apply it around
    // another Container may cause clipping at the borderRadius's corners.
    // Also note that clipping is not necessary unless borderRadius is set
    return _borderRadius != null && boxController.clipContent == true
        ? ClipRRect(
            borderRadius: _borderRadius!.getValue(),
            clipBehavior: Clip.hardEdge,
            child: widget)
        : widget;
  }
}

/// TODO: Legacy - move to EnsembleBoxWrapper
/// wraps around a widget and gives it common box attributes
class BoxWrapper extends StatelessWidget {
  const BoxWrapper(
      {super.key,
      required this.widget,
      required this.boxController,

      // internal widget may want to handle padding itself (e.g. ListView so
      // its scrollbar lays on top of the padding and not the content)
      this.ignoresPadding = false,

      // sometimes our widget may register a gesture. Such gesture should not
      // include the margin. This allows it to handle the margin on its own.
      this.ignoresMargin = false,

      // width/height maybe applied at the child, or not applicable
      this.ignoresDimension = false});

  final Widget widget;
  final BoxController boxController;

  // child widget may want to control these themselves
  final bool ignoresPadding;
  final bool ignoresMargin;
  final bool ignoresDimension;

  @override
  Widget build(BuildContext context) {
    if (!boxController.requiresBox(
        ignoresMargin: ignoresMargin,
        ignoresPadding: ignoresPadding,
        ignoresDimension: ignoresDimension)) {
      return widget;
    }
    // when we have a border radius, we need to clip the decoration.
    // Note that this clip only apply to the background decoration.
    // Some children (i.e. Images) might need an additional ClipRRect
    Clip clip = Clip.none;
    if (boxController.borderRadius != null &&
        boxController.hasBoxDecoration()) {
      clip = Clip.hardEdge;
    }
    ScopeManager? scopeManager = DataScopeWidget.getScope(context);
    final Widget? backgroundImage =
        boxController.backgroundImage?.getImageAsWidget(scopeManager);

    return Container(
      width: ignoresDimension ? null : boxController.width?.toDouble(),
      height: ignoresDimension ? null : boxController.height?.toDouble(),
      margin: ignoresMargin ? null : boxController.margin,
      padding: ignoresPadding ? null : boxController.padding,
      clipBehavior: clip,
      decoration: !boxController.hasBoxDecoration()
          ? null
          : BoxDecoration(
              color: boxController.backgroundColor,
              gradient: boxController.backgroundGradient,
              border: !boxController.hasBorder()
                  ? null
                  : boxController.borderGradient != null
                      ? GradientBoxBorder(
                          gradient: boxController.borderGradient!,
                          width: boxController.borderWidth?.toDouble() ??
                              ThemeManager().getBorderThickness(context))
                      : Border.all(
                          color: boxController.borderColor ??
                              ThemeManager().getBorderColor(context),
                          width: boxController.borderWidth?.toDouble() ??
                              ThemeManager().getBorderThickness(context)),
              borderRadius: boxController.borderRadius?.getValue(),
              boxShadow: !boxController.hasBoxShadow()
                  ? null
                  : <BoxShadow>[
                      BoxShadow(
                          color: boxController.shadowColor ??
                              ThemeManager().getShadowColor(context),
                          blurRadius: boxController.shadowRadius?.toDouble() ??
                              ThemeManager().getShadowRadius(context),
                          offset: boxController.shadowOffset ??
                              ThemeManager().getShadowOffset(context),
                          blurStyle: boxController.shadowStyle ??
                              ThemeManager().getShadowStyle(context))
                    ],
            ),
      child: backgroundImage != null
          ? Stack(
              children: [
                Positioned.fill(child: backgroundImage),
                _getWidget(),
              ],
            )
          : _getWidget(),
    );
  }

  /// The child widget need to clip separately from the Container's decoration
  Widget _getWidget() {
    // some widget (i.e. Image) will not respect the Container's boundary
    // even if clipBehavior is enabled. In these case we need to apply
    // an explicit ClipRRect around it. Note also that apply it around
    // another Container may cause clipping at the borderRadius's corners.
    // Also note that clipping is not necessary unless borderRadius is set
    return boxController.borderRadius != null &&
            boxController.clipContent == true
        ? ClipRRect(
            borderRadius: boxController.borderRadius!.getValue(),
            clipBehavior: Clip.hardEdge,
            child: widget)
        : widget;
  }
}

/// wrap the input widget (which stretches 100% to its parent) to guard against
/// the case where it is put inside a Row without expanded flag.
class InputWrapper extends StatelessWidget {
  const InputWrapper(
      {super.key,
      required this.type,
      required this.widget,
      required this.controller});

  final String type;
  final Widget widget;
  final FormFieldController controller;

  @override
  Widget build(BuildContext context) {
    final isFloatLabel =
        controller.floatLabel != null && controller.floatLabel == true;

    Widget rtn = controller.maxWidth == null
        ? buildTextWidget(context, isFloatLabel)
        : ConstrainedBox(
            constraints:
                BoxConstraints(maxWidth: controller.maxWidth!.toDouble()),
            child: buildTextWidget(context, isFloatLabel));

    // we'd like to use LayoutBuilder to detect layout anomaly, but certain
    // containers don't like LayoutBuilder, since it doesn't support returning
    // intrinsic Width/Height
    RequiresChildWithIntrinsicDimension? requiresChildWithIntrinsicDimension =
        context.dependOnInheritedWidgetOfExactType<
            RequiresChildWithIntrinsicDimension>();
    if (requiresChildWithIntrinsicDimension == null) {
      // InputWidget takes the parent width, so if the parent is a Row
      // it'll caused an error. Assert against this in Studio's debugMode
      if (StudioDebugger().debugMode) {
        return StudioDebugger().assertHasBoundedWidthWrapper(rtn, type);
      }
    }
    return rtn;
  }

  Widget buildTextWidget(context, bool isFloatLabel) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (shouldShowLabel(context) &&
              controller.label != null &&
              !isFloatLabel)
            Container(
              margin: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                controller.label!,
                style: controller.labelStyle ??
                    Theme.of(context).inputDecorationTheme.labelStyle,
              ),
            ),
          widget,
          if (shouldShowLabel(context) && controller.description != null)
            Container(
              margin: const EdgeInsets.only(top: 12.0),
              child: Text(controller.description!),
            ),
        ],
      );

  bool shouldShowLabel(BuildContext context) {
    ensemble.FormState? formState = ensemble.EnsembleForm.of(context);
    if (formState != null) {
      return formState.widget.shouldFormFieldShowLabel;
    }
    return true;
  }
}

/// Display a Text content followed by a clear icon.
/// Clicking the icon will invoke the callback.
/// Note that this is a StatelessWidget, so clearing out the value
/// is the responsibility of the parent widget who uses this.
class ClearableInput extends StatelessWidget {
  const ClearableInput(
      {super.key, required this.text, required this.onCleared, this.textStyle});

  final String text;
  final TextStyle? textStyle;
  final dynamic onCleared;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Flexible(child: Text(text, maxLines: 1, style: textStyle)),
      const SizedBox(width: 4),
      InkWell(onTap: onCleared, child: const Icon(Icons.close, size: 20))
    ]);
  }
}

mixin GradientBorder {
  BorderSide get bottom => BorderSide.none;

  BorderSide get top => BorderSide.none;

  bool get isUniform => true;

  void paintRect(
      Canvas canvas, Rect rect, LinearGradient gradient, double width) {
    canvas.drawRect(rect.deflate(width / 2), _getPaint(rect, gradient, width));
  }

  void paintRRect(Canvas canvas, Rect rect, BorderRadius borderRadius,
      LinearGradient gradient, double width) {
    final rrect = borderRadius.toRRect(rect).deflate(width / 2);
    canvas.drawRRect(rrect, _getPaint(rect, gradient, width));
  }

  Paint _getPaint(Rect rect, LinearGradient gradient, double width) {
    return Paint()
      ..strokeWidth = width
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke;
  }
}

class GradientBoxBorder extends BoxBorder with GradientBorder {
  const GradientBoxBorder({required this.gradient, required this.width});

  final LinearGradient gradient;
  final double width;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(width);

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    TextDirection? textDirection,
    BoxShape shape = BoxShape.rectangle,
    BorderRadius? borderRadius,
  }) {
    if (borderRadius != null) {
      paintRRect(canvas, rect, borderRadius, gradient, width);
      return;
    }
    paintRect(canvas, rect, gradient, width);
  }

  @override
  ShapeBorder scale(double t) {
    return this;
  }
}

/// a wrapper around a widget and enable Tap action.
class TapOverlay extends StatelessWidget {
  const TapOverlay({super.key, required this.widget, required this.onTap});

  final Widget widget;
  final TapOverlayFunc onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(children: <Widget>[
      widget,
      Positioned.fill(
          child:
              Material(color: Colors.transparent, child: InkWell(onTap: onTap)))
    ]);
  }
}

typedef TapOverlayFunc = void Function();
