import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/widget/calendar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/framework/widget/has_children.dart';
import 'package:ensemble/framework/widget/view_util.dart';
import 'package:ensemble/framework/device.dart';
import 'package:yaml/yaml.dart';


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
      'child': (value) => _controller.child = value,
      'textStyle': (value) => _controller.textStyle = Utils.getTextStyle(value),
      'height': (value) => _controller.height = Utils.optionalDouble(value),
      'padding': (value) => _controller.padding = Utils.getInsets(value),
      'margin': (value) => _controller.margin = Utils.getInsets(value),
      'verticalOffset': (value) => _controller.verticalOffset = Utils.optionalDouble(value),
      'preferBelow': (value) => _controller.preferBelow = Utils.optionalBool(value),
      'excludeFromSemantics': (value) => _controller.excludeFromSemantics = Utils.optionalBool(value),
      'waitDuration': (value) => _controller.waitDuration = Utils.getDuration(value),
      'showDuration': (value) => _controller.showDuration = Utils.getDuration(value),
      'triggerMode': (value) => _controller.triggerMode = TooltipTriggerMode.values.from(value),
      'onShow': (definition) => _controller.onShow = EnsembleAction.from(definition, initiator: this),
      'onDismiss': (definition) => _controller.onDismiss = EnsembleAction.from(definition, initiator: this),
      'decoration': (value) => _controller.setDecoration(value),
    };
  }

  @override
  Map<String, Function> methods() {
    return {
      'show': () => _controller.show(),
      'hide': () => _controller.hide(),
    };
  }
}

class ToolTipController extends Controller {
  String? message;
  dynamic child;
  TextStyle? textStyle;
  double? height;
  EdgeInsetsGeometry? padding;
  EdgeInsetsGeometry? margin;
  double? verticalOffset;
  bool? preferBelow;
  bool? excludeFromSemantics;
  Duration? waitDuration;
  Duration? showDuration;
  TooltipTriggerMode? triggerMode;
  EnsembleAction? onShow;
  EnsembleAction? onDismiss;
  bool isVisible = false;
  BoxDecoration? tooltipDecoration;

  void setDecoration(YamlMap? decorationMap) {
    if (decorationMap == null) {
      tooltipDecoration = null;
      return;
    }

    var backgroundColor = Utils.getColor(decorationMap['backgroundColor']) ?? Colors.grey[700];
    var borderRadius = Utils.getBorderRadius(decorationMap['borderRadius']);
    var borderColor = Utils.getColor(decorationMap['borderColor']);
    var borderWidth = Utils.optionalDouble(decorationMap['borderWidth']);

    tooltipDecoration = BoxDecoration(
      color: backgroundColor,
      borderRadius: borderRadius?.getValue() ?? BorderRadius.circular(4.0),
      border: borderColor != null && borderWidth != null
          ? Border.all(color: borderColor, width: borderWidth)
          : null,
    );
  }
  

  void show() {
    isVisible = true;
  }

  void hide() {
    isVisible = false;
  }
}

class ToolTipState extends EWidgetState<ToolTip> with HasChildren<ToolTip> {
  final GlobalKey _tooltipKey = GlobalKey();
  bool _isHovering = false;

  void initState() {
    super.initState();
    widget.controller.addListener(() => setState(() {}));
  }

  void _showTooltip() {
    final dynamic tooltip = _tooltipKey.currentState;
    tooltip?.ensureTooltipVisible();
    widget.controller.show();
    if (widget.controller.onShow != null) {
      ScreenController().executeAction(context, widget.controller.onShow!);
    }
  }

  void _hideTooltip() {
    final dynamic tooltip = _tooltipKey.currentState;
    tooltip?.deactivate();
    widget.controller.hide();
    if (widget.controller.onDismiss != null) {
      ScreenController().executeAction(context, widget.controller.onDismiss!);
    }
  }

  @override
  Widget buildWidget(BuildContext context) {
    Widget child = widget.controller.child != null 
        ? buildChild(ViewUtil.buildModel(widget.controller.child, null)) 
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
      height: widget.controller.height,
      padding: widget.controller.padding,
      margin: widget.controller.margin,
      verticalOffset: widget.controller.verticalOffset,
      preferBelow: widget.controller.preferBelow,
      excludeFromSemantics: widget.controller.excludeFromSemantics ?? false,
      waitDuration: widget.controller.waitDuration ?? const Duration(milliseconds: 0),
      showDuration: widget.controller.showDuration ?? const Duration(milliseconds: 1500),
      triggerMode: widget.controller.triggerMode ?? (kIsWeb ? null : TooltipTriggerMode.tap),
      enableFeedback: true,
      decoration: widget.controller.tooltipDecoration,
      child: child,
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(() {});
    super.dispose();
  }
}