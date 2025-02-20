import 'package:ensemble/framework/studio/studio_debugger.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/layout/form.dart';
import 'package:ensemble/widget/helpers/form_helper.dart';
import 'package:flutter/material.dart';
import 'package:ensemble/layout/form.dart' as ensemble;

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
    Widget rtn = buildTextWidget(context, isFloatLabel);

    if (StudioDebugger().debugMode) {
      // we'd like to use LayoutBuilder to detect layout anomaly, but certain
      // containers don't like LayoutBuilder, since it doesn't support returning
      // intrinsic Width/Height
      RequiresChildWithIntrinsicDimension? requiresChildWithIntrinsicDimension =
          context.dependOnInheritedWidgetOfExactType<
              RequiresChildWithIntrinsicDimension>();
      if (requiresChildWithIntrinsicDimension == null) {
        // InputWidget takes the parent width, so if the parent is a Row
        // it'll caused an error. Assert against this in Studio's debugMode
        rtn = StudioDebugger().assertHasBoundedWidth(rtn, type);
      }
    }

    if (controller.maxWidth != null) {
      rtn = ConstrainedBox(
          constraints:
              BoxConstraints(maxWidth: controller.maxWidth!.toDouble()),
          child: rtn);
    }

    return rtn;
  }

  Widget buildTextWidget(context, bool isFloatLabel) {
    TextStyle? formLabelStyle;

    // we need to look up to the form to know whether we should show
    // the label here, as the Form may have already showed them (side by side)
    bool shouldShowLabel = true;
    ensemble.FormState? formState = EnsembleForm.of(context);
    if (formState != null) {
      shouldShowLabel = formState.widget.shouldFormFieldShowLabel;

      // also see if the parent Form defined a labelStyle we can fall back to
      formLabelStyle = formState.widget.labelStyle;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (shouldShowLabel && controller.label != null && !isFloatLabel)
          Container(
            margin: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              controller.label!,
              // use our labelStyle and fallback to the parent Form's labelStyle
              style: controller.labelStyle ??
                  formLabelStyle ??
                  Theme.of(context).inputDecorationTheme.labelStyle,
            ),
          ),
        // semantics for whatever text input comes through
        MergeSemantics(
          child: Semantics(
              label: controller.label,
              child: widget,
            ),
        ),

        if (shouldShowLabel && controller.description != null)
          Container(
            margin: const EdgeInsets.only(top: 12.0),
            child: Text(controller.description!),
          ),
      ],
    );
  }
}
