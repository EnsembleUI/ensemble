
import 'package:ensemble/framework/action.dart' as ensemble;
import 'package:ensemble/layout/form.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/theme_utils.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/widget/form_helper.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
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
      'height': (value) => _controller.buttonHeight = Utils.optionalInt(value),
      'width': (value) => _controller.buttonWidth = Utils.optionalInt(value),
      'fontWeight': (value) => _controller.fontWeight = Utils.getFontWeight(value),
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
  int? buttonHeight;
  int? buttonWidth;
  bool? outline;
  Color? color;
  int? fontSize;
  FontWeight? fontWeight;
}


class ButtonState extends WidgetState<Button> {

  @override
  Widget buildWidget(BuildContext context) {
    bool isOutlineButton = widget._controller.outline ?? false;
    
    Text label = Text(Utils.translate(widget._controller.label ?? '', context));
//  painter:widget._controller.borderGradient!=null?
//         Painter(widget._controller.borderGradient as LinearGradient,  widget._controller.borderWidth?.toDouble()??1,  10):null,
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

    // add margin if specified
    return widget._controller.margin != null ?
      Padding(padding: widget._controller.margin!, child: rtn) :
      rtn;
  }
  
  ButtonStyle getButtonStyle(BuildContext context, bool isOutlineButton) {
    // // we need to build a border which requires valid borderColor, borderThickness & borderRadius.
    // // Let's get the default theme so we can overwrite only necessary styles
    // RoundedRectangleBorder? border;
    // OutlinedBorder? defaultShape = isOutlineButton ?
    //   Theme.of(context).textButtonTheme.style?.shape?.resolve({}) :
    //     Theme.of(context).elevatedButtonTheme.style?.shape?.resolve({});
    // if (defaultShape is RoundedRectangleBorder) {
    //   // if we don't specify borderColor here, and the default border is none, stick with that
    //   BorderSide borderSide;
    //   if (widget._controller.borderColor == null && defaultShape.side.style == BorderStyle.none) {
    //     borderSide = defaultShape.side;
    //   } else {
    //     borderSide = BorderSide(
    //         color: widget._controller.borderColor ?? Colors.transparent,
    //         width: widget._controller.borderWidth?.toDouble() ?? defaultShape.side.width);
    //   }

    //   border = RoundedRectangleBorder(
    //     borderRadius: widget._controller.borderRadius == null ?
    //         defaultShape.borderRadius :
    //         widget._controller.borderRadius!.getValue(),
    //     side: borderSide);
    // }
        
    // // we need to get the button shape from borderRadius, borderColor & borderThickness
    // // and we do not want to override the default theme if not specified
    // //int borderRadius = widget._controller.borderRadius ?? defaultButtonStyle?.

    // return ThemeUtils.getButtonStyle(
    //     isOutline: isOutlineButton,
    //     color: widget._controller.color,
    //     backgroundColor: widget._controller.backgroundColor,
    //     border: border,
    //     padding: widget._controller.padding,
    //     height: widget._controller.buttonHeight?.toDouble(),

    //     width: widget._controller.buttonWidth?.toDouble(),
    //     fontSize: widget._controller.fontSize,
    //     fontWeight: widget._controller.fontWeight
    // );
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
        color: widget._controller.borderColor ?? Colors.transparent,
        width: widget._controller.borderWidth?.toDouble() ?? defaultShape.side.width);
  }

 widget._controller.borderGradient!=null?
    border=  GradientRoundedRectangleBorder(
      gradient: widget._controller.borderGradient??const LinearGradient(colors: [Colors.red,Colors.green]),
      width: widget._controller.borderWidth?.toDouble()??borderSide.width,
      radius: widget._controller.borderRadius == null ?
          defaultShape.borderRadius :
          widget._controller.borderRadius!.getValue(),
          // borderSide: borderSide
          // borderSide: borderSide
  ):
  border=RoundedRectangleBorder(
    borderRadius:widget._controller.borderRadius == null ?
          defaultShape.borderRadius :
          widget._controller.borderRadius!.getValue(),
    side: borderSide
  );
}

// we need to get the button shape from borderRadius, borderColor & borderThickness
// and we do not want to override the default theme if not specified
//int borderRadius = widget._controller.borderRadius ?? defaultButtonStyle?.

return ThemeUtils.getButtonStyle(
    isOutline: isOutlineButton,
    color: widget._controller.color,
    backgroundColor: widget._controller.backgroundColor,
    border: border,
    padding: widget._controller.padding,
    height: widget._controller.buttonHeight?.toDouble(),

    width: widget._controller.buttonWidth?.toDouble(),
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


class Painter extends CustomPainter {
  final Paint _paint = Paint();
  final Gradient gradient;
  final double strokeWidth;
  final double radius;

  Painter(this.gradient,  this.strokeWidth,this.radius );

  // @override
  // void paint(Canvas canvas, Size size) {
  //   final Rect rect = Rect.fromLTWH(width / 2, width / 2.1, size.width - width, size.height - width);
  //   final RRect rRect = RRect.fromRectAndRadius(rect, borderRadius);
  //   final Paint _paint = Paint()
  //     ..style = PaintingStyle.stroke
  //     ..strokeWidth = width
  //     ..shader = gradient.createShader(rect);
  //   canvas.drawRRect(rRect, _paint);
  // }
  @override
  void paint(Canvas canvas, Size size) {
    // create outer rectangle equals size
    Rect outerRect = Offset.zero & size;
    var outerRRect = RRect.fromRectAndRadius(outerRect, Radius.circular(radius));

    // create inner rectangle smaller by strokeWidth
    Rect innerRect = Rect.fromLTWH(strokeWidth, strokeWidth, size.width - strokeWidth * 2, size.height - strokeWidth * 2);
    var innerRRect = RRect.fromRectAndRadius(innerRect, Radius.circular(radius - strokeWidth));

    // apply gradient shader
    _paint.shader = gradient.createShader(outerRect);

    // create difference between outer and inner paths and draw it
    Path path1 = Path()..addRRect(outerRRect);
    Path path2 = Path()..addRRect(innerRRect);
    var path = Path.combine(PathOperation.difference, path1, path2);
    canvas.drawPath(path, _paint);
  }


  @override
  bool shouldRepaint(CustomPainter oldDelegate) => oldDelegate != this;
}


// ---------------------- code for gradient border -------------

class GradientRoundedRectangleBorder extends RoundedRectangleBorder with GradientBorderMixin {
  
  GradientRoundedRectangleBorder({
    required LinearGradient gradient,
    required double width,
    required BorderRadiusGeometry radius,
  }):   side = BorderSide(width: width,style: BorderStyle.solid,),
       borderRadius = radius 
    {
    this.gradient = gradient;
    this.width = width;
  }

  @override
  final BorderSide side;

  @override
  final BorderRadiusGeometry borderRadius;

  @override
  Path getInnerPath(Rect rect, { TextDirection? textDirection }) {
    
    return Path()..addRRect(borderRadius.resolve(textDirection!).toRRect(rect).deflate(side.width));
  }
  

  @override
  Path getOuterPath(Rect rect, { TextDirection? textDirection }) {
    
    return Path()..addRRect(borderRadius.resolve(textDirection!).toRRect(rect));
  }

  @override
  ShapeBorder scale(double t) {
    
    return GradientRoundedRectangleBorder(
      gradient: gradient,
      width: width * t,
      
      radius: borderRadius,
      
      
    );
  }

 
}


