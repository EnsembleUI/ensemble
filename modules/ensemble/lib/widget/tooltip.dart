import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/theme/theme_manager.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:ensemble/framework/widget/has_children.dart';
import 'package:ensemble/framework/widget/view_util.dart';

class ToolTip extends StatefulWidget
    with Invokable, HasController<ToolTipController, ToolTipState> {
  static const type = 'ToolTip';

  ToolTip({Key? key}) : super(key: key);

  final ToolTipController _controller = ToolTipController();

  @override
  ToolTipController get controller => _controller;

  @override
  State<StatefulWidget> createState() => ToolTipState();

  @override
  Map<String, Function> getters() {
    return {
      'isVisible': () => _controller.isVisible,
    };
  }

  @override
  Map<String, Function> setters() {
    return {
      'message': (value) => _controller.message = Utils.optionalString(value),
      'widget': (value) => _controller.widget = value,
      'textStyle': (value) => _controller.textStyle = Utils.getTextStyle(value),
      'verticalOffset': (value) =>
          _controller.verticalOffset = Utils.optionalDouble(value),
      'preferBelow': (value) =>
          _controller.preferBelow = Utils.optionalBool(value),
      'waitDuration': (value) =>
          _controller.waitDuration = Utils.getDuration(value),
      'showDuration': (value) =>
          _controller.showDuration = Utils.getDuration(value),
      'triggerMode': (value) =>
          _controller.triggerMode = TooltipTriggerMode.values.from(value),
      'onTriggered': (definition) => _controller.onTriggered =
          EnsembleAction.from(definition, initiator: this),
    };
  }

  @override
  Map<String, Function> methods() {
    return {
      'show': () => _controller.show(),
    };
  }
}

class ToolTipController extends BoxController {
  String? message;
  dynamic widget;
  TextStyle? textStyle;
  double? verticalOffset;
  bool? preferBelow;
  Duration? waitDuration;
  Duration? showDuration;
  TooltipTriggerMode? triggerMode;
  bool isVisible = false;
  EnsembleAction? onTriggered;

  void show() {
    isVisible = true;
    notifyListeners();
  }

  void hide() {
    isVisible = false;
    notifyListeners();
  }
}

class ToolTipState extends EWidgetState<ToolTip> with HasChildren<ToolTip> {
  final GlobalKey _tooltipKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() => setState(() {}));
  }

  void _showTooltip() {
    final dynamic tooltip = _tooltipKey.currentState;
    tooltip?.ensureTooltipVisible();
    widget.controller.show();
  }

  void _hideTooltip() {
    final dynamic tooltip = _tooltipKey.currentState;
    tooltip?.deactivate();
    widget.controller.hide();
  }

  @override
  Widget buildWidget(BuildContext context) {
    Widget child = widget.controller.widget != null
        ? buildChild(ViewUtil.buildModel(widget.controller.widget, null))
        : const SizedBox.shrink();

    if (kIsWeb && widget.controller.triggerMode == null) {
      child = MouseRegion(
        onEnter: (_) => _showTooltip(),
        onExit: (_) => _hideTooltip(),
        child: child,
      );
    }

    return Tooltip(
      key: _tooltipKey,
      message: widget.controller.message ?? '',
      textStyle: widget.controller.textStyle,
      height: widget.controller.height?.toDouble(),
      padding: widget.controller.padding,
      margin: widget.controller.margin,
      verticalOffset: widget.controller.verticalOffset,
      preferBelow: widget.controller.preferBelow,
      waitDuration:
          widget.controller.waitDuration ?? const Duration(milliseconds: 0),
      showDuration:
          widget.controller.showDuration ?? const Duration(milliseconds: 1500),
      triggerMode: widget.controller.triggerMode ??
          (kIsWeb ? null : TooltipTriggerMode.tap),
      enableFeedback: true,
      decoration: BoxDecoration(
          color: widget._controller.backgroundColor ?? Colors.grey[700],
          borderRadius: widget._controller.borderRadius?.getValue(),
          border: widget._controller.borderColor != null ||
                  widget._controller.borderWidth != null
              ? Border.all(
                  color: widget._controller.borderColor ??
                      ThemeManager().getBorderColor(context),
                  width: widget._controller.borderWidth?.toDouble() ??
                      ThemeManager().getBorderThickness(context),
                )
              : null),
      onTriggered: () {
        if (widget.controller.onTriggered != null) {
          ScreenController().executeAction(
            context,
            widget.controller.onTriggered!,
            event: EnsembleEvent(widget),
          );
        }
      },
      child: child,
    );
  }
}
