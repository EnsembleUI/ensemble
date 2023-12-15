import 'dart:math';

import 'package:ensemble/action/haptic_action.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/ensemble_widget.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/model.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/widget/colored_box_placeholder.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/framework/widget/image.dart' as framework;
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:ensemble/widget/image.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';

class Avatar extends EnsembleWidget<AvatarController> {
  static const type = 'Avatar';

  const Avatar._(super.controller, {super.key});

  factory Avatar.build(dynamic controller) => Avatar._(
      controller is AvatarController ? controller : AvatarController());

  @override
  State<StatefulWidget> createState() => AvatarState();
}

class AvatarController extends EnsembleBoxController {
  AvatarController() {
    clipContent = true;
  }

  String? name;
  TextStyle? nameTextStyle;

  String? source;
  BoxFit? fit;
  Color? placeholderColor;

  AvatarVariant? variant;
  EnsembleAction? onTap;
  String? onTapHaptic;

  @override
  Map<String, Function> getters() {
    return {};
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() => Map<String, Function>.from(super.setters())
    ..addAll({
      'name': (value) => name = Utils.optionalString(value),
      'nameTextStyle': (value) => nameTextStyle = Utils.getTextStyle(value),
      'source': (value) => source = Utils.optionalString(value),
      'fit': (value) => fit = Utils.getBoxFit(value),
      'placeholderColor': (value) => placeholderColor = Utils.getColor(value),
      'variant': (value) => variant = AvatarVariant.values.from(value),
      'onTap': (func) => onTap = EnsembleAction.fromYaml(func, initiator: this),
      'onTapHaptic': (value) => onTapHaptic = Utils.optionalString(value)
    });
}

class AvatarState extends EnsembleWidgetState<Avatar> {
  static const defaultSize = 40.0;

  @override
  Widget buildWidget(BuildContext context) {
    return _buildAvatar();
  }

  Widget _buildAvatar() {
    String? source = widget.controller.source?.trim();
    Widget content = EnsembleBoxWrapper(
        widget: source != null && source.isNotEmpty
            ? _buildImage(source)
            : _buildFallback(),
        boxController: widget.controller,
        ignoresMargin: true,
        fallbackWidth: width,
        fallbackHeight: height,
        fallbackBorderRadius: _getVariantDefaultBorderRadius());

    if (widget.controller.onTap != null) {
      content = GestureDetector(
        child: content,
        onTap: () {
          if (widget.controller.onTapHaptic != null) {
            ScreenController().executeAction(
              context,
              HapticAction(
                type: widget.controller.onTapHaptic!,
                onComplete: null,
              ),
            );
          }

          ScreenController().executeAction(context, widget.controller.onTap!,
              event: EnsembleEvent(widget.controller));
        },
      );
    }
    if (widget.controller.margin != null) {
      content = Padding(padding: widget.controller.margin!, child: content);
    }
    return content;
  }

  EBorderRadius? _getVariantDefaultBorderRadius() {
    switch (widget.controller.variant) {
      case AvatarVariant.square:
        return null;
      case AvatarVariant.rounded:
        return EBorderRadius.all(10);
      case AvatarVariant.circle:
      default:
        return EBorderRadius.all(9999);
    }
  }

  Widget _buildImage(String source) => framework.Image(
      source: source,
      fit: widget.controller.fit,
      networkCacheManager: EnsembleImageCacheManager.instance,
      placeholderBuilder: (_, __) =>
          ColoredBoxPlaceholder(color: widget.controller.placeholderColor),
      errorBuilder: (_) => _buildFallback());

  /// build the initial or an empty box
  Widget _buildFallback() {
    String? initial;
    String? name = widget.controller.name?.trim();
    if (name != null && name.isNotEmpty) {
      List<String> tokens = name.split(RegExp(r'\s+'));
      initial = tokens[0][0].toUpperCase();
      if (tokens.length > 1) {
        initial += tokens[tokens.length - 1][0].toUpperCase();
      }
    }

    var textStyle = widget.controller.nameTextStyle ??
        TextStyle(fontSize: min(width, height) * .5);
    return initial != null
        ? Align(child: Text(initial, style: textStyle))
        : const SizedBox.shrink();
  }

  double get width =>
      (widget.controller.width ?? widget.controller.height)?.toDouble() ??
      defaultSize;

  double get height =>
      (widget.controller.height ?? widget.controller.width)?.toDouble() ??
      defaultSize;
}

enum AvatarVariant { circle, square, rounded }
