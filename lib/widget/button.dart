
import 'package:ensemble/framework/action.dart' as ensemble;
import 'package:ensemble/layout/form.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/theme_utils.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/widget/form_helper.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:flutter/material.dart';
import 'package:ensemble/layout/form.dart' as ensembleForm;
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';

import '../framework/event.dart';

class Button extends StatefulWidget with Invokable, HasController<ButtonController, ButtonState> {
  static const type = 'Button';
  Button({Key? key}) : super(key: key);

  final ButtonController _controller = ButtonController();
  @override
  ButtonController get controller => _controller;

  @override
  Map<String, Function> getters() {
    return {};
  }
  @override
  Map<String, Function> setters() {
    return {
      'label': (value) => _controller.label = Utils.getString(value, fallback: ''),
      'onTap': (funcDefinition) => _controller.onTap = Utils.getAction(funcDefinition, initiator: this),
      'submitForm': (value) => _controller.submitForm = Utils.optionalBool(value),
      'validateForm': (value) => _controller.validateForm = Utils.optionalBool(value),
      'validateFields': (items) => _controller.validateFields = Utils.getList(items),

      'enabled': (value) => _controller.enabled = Utils.optionalBool(value),
      'outline': (value) => _controller.outline = Utils.optionalBool(value),
      'color': (value) => _controller.color = Utils.getColor(value),
      'fontSize': (value) => _controller.fontSize = Utils.optionalInt(value),
      'fontWeight': (value) => _controller.fontWeight = Utils.getFontWeight(value),
      'width': (value) => _controller.buttonWidth = Utils.optionalInt(value),
      'height': (value) => _controller.buttonHeight = Utils.optionalInt(value),
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
  Color? color;
  int? fontSize;
  FontWeight? fontWeight;
  int? buttonWidth;
  int? buttonHeight;
}


class ButtonState extends WidgetState<Button> {

  @override
  Widget buildWidget(BuildContext context) {
    bool isOutlineButton = widget._controller.outline ?? false;
    
    Text label = Text(Utils.translate(widget._controller.label ?? '', context));

    Widget? rtn;
    if (isOutlineButton) {
      rtn = TextButton(
        onPressed: isEnabled() ? () => onPressed(context) : null,
        style: getButtonStyle(context, isOutlineButton),
        child: label);
    } else {
      rtn = ElevatedButton(
        onPressed: isEnabled() ? () => onPressed(context) : null,
        style: getButtonStyle(context, isOutlineButton),
        child: label);
    }

    if(widget._controller.borderGradient!=null){
      return CustomPaint(
        foregroundPainter: _Painter(widget._controller.borderGradient!, widget._controller.borderRadius?.getValue(), widget._controller.borderWidth?.toDouble()??Size.zero.width) ,
        child: rtn,
      );
    }

    // add margin if specified
    return widget._controller.margin != null ?
      Padding(padding: widget._controller.margin!, child: rtn) :
      rtn;
  }
  
  ButtonStyle getButtonStyle(BuildContext context, bool isOutlineButton) {
    // we need to build a border which requires valid borderColor, borderThickness & borderRadius.
    // Let's get the default theme so we can overwrite only necessary styles
    RoundedRectangleBorder? border;
    OutlinedBorder? defaultShape = isOutlineButton ?
      Theme.of(context).textButtonTheme.style?.shape?.resolve({}) :
        Theme.of(context).elevatedButtonTheme.style?.shape?.resolve({});
    if (defaultShape is RoundedRectangleBorder) {
      // if we don't specify borderColor here, and the default border is none, stick with that
      BorderSide borderSide;
      if (widget._controller.borderColor == null && defaultShape.side.style == BorderStyle.none) {
        borderSide = defaultShape.side;
      } else {
        borderSide = BorderSide(
            color: widget._controller.borderColor ?? defaultShape.side.color,
            width: widget._controller.borderWidth?.toDouble() ?? defaultShape.side.width);
      }

      border = RoundedRectangleBorder(
        borderRadius: widget._controller.borderRadius == null ?
            defaultShape.borderRadius :
            widget._controller.borderRadius!.getValue(),
        // when we give [borderGradient] and [borderColor] it will draw that color also around borderSide
        // So when the borderGradient is there the side will be none
        side: widget._controller.borderGradient!=null?
              BorderSide.none :
              borderSide);
    }
        
    // we need to get the button shape from borderRadius, borderColor & borderThickness
    // and we do not want to override the default theme if not specified
    //int borderRadius = widget._controller.borderRadius ?? defaultButtonStyle?.

    return ThemeUtils.getButtonStyle(
        isOutline: isOutlineButton,
        color: widget._controller.color,
        backgroundColor: widget._controller.backgroundColor,
        border: border,
        buttonHeight: widget._controller.buttonHeight?.toDouble(),
        buttonWidth: widget._controller.buttonWidth?.toDouble(),
        padding: widget._controller.padding,
        fontSize: widget._controller.fontSize,
        fontWeight: widget._controller.fontWeight
    );
  }

  void onPressed(BuildContext context) {
    // validate if we are inside a Form
    if (widget._controller.validateForm != null && widget._controller.validateForm!) {
      ensembleForm.FormState? formState = EnsembleForm.of(context);
      if (formState != null) {
        // don't continue if validation fails
        if (!formState.validate()) {
          return;
        }
      }
    }
    // else validate specified fields
    else if (widget._controller.validateFields != null) {

    }

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
      ScreenController().executeAction(context, widget._controller.onTap!,event: EnsembleEvent(widget));
    }
  }

  bool isEnabled() {
    return widget._controller.enabled
        ?? EnsembleForm.of(context)?.widget.controller.enabled
        ?? true;
  }

}


class _Painter extends CustomPainter {
  final Gradient gradient;
  final BorderRadiusGeometry? borderRadius;
  final double strokeWidth;
  final TextDirection? textDirection;

  _Painter(this.gradient, this.borderRadius, this.strokeWidth, {this.textDirection});

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Rect.fromLTWH(strokeWidth / 2, strokeWidth / 2, size.width - strokeWidth, size.height - strokeWidth);
    final RRect rRect = borderRadius?.resolve(textDirection ?? TextDirection.ltr).toRRect(rect) ?? RRect.fromRectAndRadius(rect, Radius.zero);
    final Paint _paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = gradient.createShader(rect);
    canvas.drawRRect(rRect, _paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => oldDelegate != this;
}
