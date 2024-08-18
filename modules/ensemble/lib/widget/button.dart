import 'package:ensemble/action/haptic_action.dart';
import 'package:ensemble/framework/action.dart' as ensemble;
import 'package:ensemble/framework/theme/theme_manager.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/layout/form.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/framework/widget/icon.dart' as ensembleIcon;
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/widget/helpers/form_helper.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:flutter/material.dart';
import 'package:ensemble/layout/form.dart' as ensembleForm;
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';

import '../framework/event.dart';
import '../framework/model.dart';
import '../framework/scope.dart';
import '../framework/view/page.dart';
import 'helpers/widgets.dart';

class Button extends StatefulWidget
    with Invokable, HasController<ButtonController, ButtonState> {
  static const type = 'Button';

  Button({Key? key}) : super(key: key);

  final ButtonController _controller = ButtonController();

  @override
  ButtonController get controller => _controller;

  @override
  Map<String, Function> getters() {
    return {
      'label': () => _controller.label,
      'labelStyle': () => _controller.labelStyle,
      'gap': () => Utils.getInt(_controller.gap, fallback: 0),
      'enabled': () => Utils.getBool(_controller.enabled, fallback: true),
      'outline': () => Utils.getBool(_controller.outline, fallback: false),
      'width': () => _controller.buttonWidth,
      'height': () => _controller.buttonHeight
    };
  }

  @override
  List<String> passthroughSetters() => ["body"];

  @override
  Map<String, Function> setters() {
    return {
      'label': (value) =>
          _controller.label = Utils.getString(value, fallback: ''),
      'labelStyle': (style) => _controller.labelStyle =
          Utils.getTextStyleAsComposite(_controller, style: style),
      'startingIcon': (value) =>
          _controller.startingIcon = Utils.getIcon(value),
      'endingIcon': (value) => _controller.endingIcon = Utils.getIcon(value),
      'gap': (value) => _controller.gap = Utils.optionalInt(value),
      'body': (widget) => _controller.body = widget,
      'onTap': (funcDefinition) => _controller.onTap =
          ensemble.EnsembleAction.from(funcDefinition, initiator: this),
      'onTapHaptic': (value) =>
          _controller.onTapHaptic = Utils.optionalString(value),
      'submitForm': (value) =>
          _controller.submitForm = Utils.optionalBool(value),
      'validateForm': (value) =>
          _controller.validateForm = Utils.optionalBool(value),
      'validateFields': (items) =>
          _controller.validateFields = Utils.getList(items),
      'enabled': (value) => _controller.enabled = Utils.optionalBool(value),
      'outline': (value) => _controller.outline = Utils.optionalBool(value),
      'width': (value) => _controller.buttonWidth = Utils.optionalInt(value),
      'height': (value) => _controller.buttonHeight = Utils.optionalInt(value),
      'loading': (value) => _controller.loading = Utils.optionalBool(value),
      'loadingIndicator': (widget) => _controller.loadingIndicator = widget,
    };
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  State<StatefulWidget> createState() => ButtonState();
}

class ButtonController extends BoxController {
  ensemble.EnsembleAction? onTap;
  String? onTapHaptic;

  TextStyleComposite? _labelStyle;

  TextStyleComposite get labelStyle => _labelStyle ??= TextStyleComposite(this);

  set labelStyle(TextStyleComposite style) => _labelStyle = style;

  /// whether to trigger a form submission.
  /// This has no effect if the button is not inside a form
  bool? submitForm;

  // whether this button will invoke form validation or not
  // this has no effect if the button is not inside a form
  bool? validateForm;

  // a list of field IDs to validate. TODO: implement this
  List<dynamic>? validateFields;
  bool? enabled;
  bool? outline;
  int? buttonWidth;
  int? buttonHeight;
  int? gap;

  dynamic body;

  IconModel? startingIcon;
  IconModel? endingIcon;

  bool? loading;
  dynamic loadingIndicator;
}

class ButtonState extends EWidgetState<Button> {
  @override
  Widget buildWidget(BuildContext context) {
    bool isOutlineButton = widget._controller.outline ?? false;

    Widget rtn = isOutlineButton
        ? BoxWrapper(
            boxController: widget.controller,
            ignoresPadding: true,
            ignoresMargin: true,
            widget: TextButton(
                onPressed: isEnabled() ? () => onPressed(context) : null,
                style: getButtonStyle(context, isOutlineButton),
                child: _buildButtonChild()),
          )
        : BoxWrapper(
            boxController: widget.controller,
            ignoresPadding: true,
            ignoresMargin: true,
            widget: FilledButton(
                onPressed: isEnabled() ? () => onPressed(context) : null,
                style: getButtonStyle(context, isOutlineButton),
                child: _buildButtonChild()),
          );

    // add margin if specified
    return widget._controller.margin != null
        ? Padding(padding: widget._controller.margin!, child: rtn)
        : rtn;
  }

  Widget _buildButtonChild() {
    if (widget._controller.loading == true) {
      // Measure text size to keep the button consistent
      final textSpan = TextSpan(
          text: widget._controller.label ?? '',
          style: widget._controller.labelStyle.getTextStyle());
      final textPainter = TextPainter(
        text: textSpan,
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout();

      // Show a CircularProgressIndicator
      return SizedBox(
        width: textPainter.width + 24,
        height: textPainter.height,
        child: Center(
            child: SizedBox(
          width: 24,
          height: 24,
          child: widget._controller.loadingIndicator != null &&
                  scopeManager != null
              ? scopeManager!.buildWidgetFromDefinition(
                  widget._controller.loadingIndicator)
              : CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                  widget._controller.labelStyle.color != null
                      ? widget._controller.labelStyle.color!.withOpacity(0.5)
                      : Colors.white.withOpacity(0.5),
                )),
        )),
      );
    }

    // use the body widget if specified
    if (widget._controller.body != null && scopeManager != null) {
      return scopeManager!.buildWidgetFromDefinition(widget._controller.body);
    }

    List<Widget> labelParts = [
      Text(Utils.translate(widget._controller.label ?? '', context),
          textAlign: widget._controller.labelStyle.textAlign,
          style: widget._controller.labelStyle.getTextStyle())
    ];
    final hasGap = widget._controller.gap != null;

    if (widget._controller.startingIcon != null) {
      labelParts
          .add(ensembleIcon.Icon.fromModel(widget._controller.startingIcon!));
      if (hasGap)
        labelParts.add(SizedBox(width: widget._controller.gap!.toDouble()));
    }
    if (widget._controller.endingIcon != null) {
      if (hasGap)
        labelParts.add(SizedBox(width: widget._controller.gap!.toDouble()));
      labelParts
          .add(ensembleIcon.Icon.fromModel(widget._controller.endingIcon!));
    }
    return labelParts.length == 1
        ? labelParts[0]
        : Row(mainAxisSize: MainAxisSize.min, children: labelParts);
  }

  ButtonStyle getButtonStyle(BuildContext context, bool isOutlineButton) {
    // we need to build a border which requires valid borderColor, borderThickness & borderRadius.
    // Let's get the default theme so we can overwrite only necessary styles
    RoundedRectangleBorder? border;
    OutlinedBorder? defaultShape = isOutlineButton
        ? Theme.of(context).textButtonTheme.style?.shape?.resolve({})
        : Theme.of(context).elevatedButtonTheme.style?.shape?.resolve({});
    if (defaultShape is RoundedRectangleBorder) {
      // if we don't specify borderColor here, and the default border is none, stick with that
      BorderSide borderSide;
      if (widget._controller.borderColor == null &&
          defaultShape.side.style == BorderStyle.none) {
        borderSide = defaultShape.side;
      } else {
        borderSide = BorderSide(
            color: widget._controller.borderColor ?? defaultShape.side.color,
            width: widget._controller.borderWidth?.toDouble() ??
                defaultShape.side.width);
      }

      border = RoundedRectangleBorder(
          borderRadius: widget._controller.borderRadius == null
              ? defaultShape.borderRadius
              : widget._controller.borderRadius!.getValue(),
          // when we give [borderGradient] and [borderColor] it will draw that color also around borderSide
          // So when the borderGradient is there the side will be none
          side: widget._controller.borderGradient != null
              ? BorderSide.none
              : borderSide);
    } else {
      if (isOutlineButton) {
        border = const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.zero),
        );
      }
    }

    // we need to get the button shape from borderRadius, borderColor & borderThickness
    // and we do not want to override the default theme if not specified
    //int borderRadius = widget._controller.borderRadius ?? defaultButtonStyle?.

    return ThemeManager().getButtonStyle(
        isOutline: isOutlineButton,
        backgroundColor: widget._controller.backgroundGradient == null
            ? widget._controller.backgroundColor
            : Colors.transparent,
        border: border,
        buttonHeight: widget._controller.buttonHeight?.toDouble(),
        buttonWidth: widget._controller.buttonWidth?.toDouble(),
        padding: widget._controller.padding);
  }

  void onPressed(BuildContext context) {
    // validate if we are inside a Form
    if (widget._controller.validateForm != null &&
        widget._controller.validateForm!) {
      ensembleForm.FormState? formState = EnsembleForm.of(context);
      if (formState != null) {
        // don't continue if validation fails
        if (!formState.validate()) {
          return;
        }
      }
    }
    // else validate specified fields
    else if (widget._controller.validateFields != null) {}

    // if focus in on a formfield (e.g. TextField), clicking on button will
    // not remove focus, so its value is never updated. Unfocus here before
    // executing button click ensure we get all the latest value of the form fields
    FocusManager.instance.primaryFocus?.unfocus();

    // submit the form if specified
    if (widget._controller.submitForm == true) {
      FormHelper.submitForm(context);
    }

    // execute the onTap action
    if (widget._controller.onTap != null) {
      if (widget._controller.onTapHaptic != null) {
        ScreenController().executeAction(
          context,
          HapticAction(type: widget._controller.onTapHaptic!, onComplete: null),
        );
      }

      ScreenController().executeAction(context, widget._controller.onTap!,
          event: EnsembleEvent(widget));
    }
  }

  bool isEnabled() {
    if (widget._controller.loading == true) {
      return false;
    }
    return widget._controller.enabled ??
        EnsembleForm.of(context)?.widget.controller.enabled ??
        true;
  }
}
