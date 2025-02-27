import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/widget/has_children.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/model/item_template.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/util/layout_utils.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/button.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/helpers/form_helper.dart';
import 'package:ensemble/widget/widget_util.dart' as util;
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart' as flutter;
import 'package:flutter/material.dart';

class EnsembleForm extends StatefulWidget
    with
        UpdatableContainer,
        Invokable,
        HasController<FormController, FormState> {
  static const type = 'Form';

  EnsembleForm({Key? key}) : super(key: key);
  final GlobalKey<flutter.FormState> _formKey = GlobalKey<flutter.FormState>();

  final FormController _controller = FormController();

  @override
  FormController get controller => _controller;

  @override
  State<StatefulWidget> createState() => FormState();

  @override
  Map<String, Function> getters() {
    return {};
  }

  @override
  void initChildren({List<WidgetModel>? children, Map? itemTemplate}) {
    _controller.children = children;
  }

  @override
  Map<String, Function> methods() {
    return {
      'submit': () {
        if (_formKey.currentContext != null) {
          FormHelper.submitForm(_formKey.currentContext!);
        }
      },
      'validate': () {
        return _formKey.currentState?.validate() ?? false;
      }
    };
  }

  @override
  Map<String, Function> setters() {
    return {
      'onSubmit': (funcDefinition) => _controller.onSubmit =
          EnsembleAction.from(funcDefinition, initiator: this),
      'labelPosition': (value) =>
          handleLabelPosition(Utils.optionalString(value)),
      'labelOverflow': (value) =>
          _controller.labelOverflow = Utils.optionalString(value),
      'labelStyle': (value) =>
          _controller.labelStyle = Utils.getTextStyle(value),
      'enabled': (value) => _controller.enabled = Utils.optionalBool(value),
      'readOnly': (value) => _controller.readOnly = Utils.optionalBool(value),
      'dismissibleKeyboard': (value) => _controller.dismissibleKeyboard = Utils.getBool(value, fallback: _controller.dismissibleKeyboard),
      'width': (value) => _controller.width = Utils.optionalInt(value),
      'height': (value) => _controller.height = Utils.optionalInt(value),
      'gap': (value) => _controller.gap =
          Utils.getInt(value, fallback: FormController._defaultGap),
      'maxWidth': (value) => _controller.maxWidth = Utils.optionalInt(value),
      'labelMaxWidth': (value) =>
          _controller.labelMaxWidth = Utils.optionalInt(value),
    };
  }

  void handleLabelPosition(String? position) {
    if (position == 'none') {
      _controller.labelPosition = LabelPosition.none;
    } else if (position == 'start') {
      _controller.labelPosition = LabelPosition.start;
    } else {
      _controller.labelPosition = LabelPosition.top;
    }
  }

  static FormState? of(BuildContext context) {
    EnsembleFormScope? scope =
        context.dependOnInheritedWidgetOfExactType<EnsembleFormScope>();
    return scope?.formState;
  }

  // whether a child Form field should show or hide its label
  bool get shouldFormFieldShowLabel =>
      _controller.labelPosition == LabelPosition.top;

  TextStyle? get labelStyle => _controller.labelStyle;
}

class FormController extends WidgetController {
  static const _defaultGap = 10;

  EnsembleAction? onSubmit;
  List<WidgetModel>? children;
  LabelPosition labelPosition = LabelPosition.top;
  String? labelOverflow;
  bool? enabled;
  bool? readOnly;
  bool dismissibleKeyboard = true;

  // labelMaxWidth applicable only to labelPosition=start
  int? labelMaxWidth;
  int? maxWidth;
  flutter.TextStyle? labelStyle;

  int? width;
  int? height;
  int gap = _defaultGap;

  // Add notifier just for form
  final ValueNotifier<int> formStateNotifier = ValueNotifier(0);

  void notifyFormChanged() {
    formStateNotifier.value++;
  }
}

class FormState extends EWidgetState<EnsembleForm>
    with HasChildren<EnsembleForm> {
  bool validate() {
    return widget?._formKey.currentState!.validate() ?? false;
  }

  @override
  Widget buildWidget(BuildContext context) {
    if (widget._controller.children == null ||
        widget._controller.children!.isEmpty) {
      return const SizedBox.shrink();
    }

    Widget? body;
    // use grid if labels are side by side
    if (widget._controller.labelPosition == LabelPosition.start) {
      body = buildGrid(buildChildren(widget._controller.children!));
    } else {
      body = buildColumn(buildChildren(widget._controller.children!));
    }
    Widget rtn = SizedBox(
        width: widget._controller.width?.toDouble(),
        height: widget._controller.height?.toDouble(),
        child: EnsembleFormScope(
            formState: this, child: Form(key: widget._formKey, child: body)));

    if (widget._controller.maxWidth != null) {
      return ConstrainedBox(
          constraints:
              BoxConstraints(maxWidth: widget._controller.maxWidth!.toDouble()),
          child: rtn);
    }
    return rtn;
  }

  Widget buildColumn(List<Widget> formItems) {
    List<Widget> items = [];
    for (Widget formItem in formItems) {
      if (formItem is HasController &&
          formItem.controller is FormFieldController) {
        items.add(formItem);
      } else if (formItem is HasController &&
          formItem.controller is WidgetController &&
          !inExcludedList(formItem.controller as WidgetController) &&
          (formItem.controller as WidgetController).label != null) {
        // if widget is not a FormField but has a label, wrap it in a FormField
        items.add(FormField(builder: (FormFieldState field) {
          return InputDecorator(
              decoration: InputDecoration(
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  labelStyle: widget._controller.labelStyle,
                  labelText: widget.shouldFormFieldShowLabel
                      ? (formItem.controller as WidgetController).label
                      : null),
              child: formItem);
        }));
      } else {
        items.add(formItem);
      }
    }
    return Column(
        crossAxisAlignment: flutter.CrossAxisAlignment.start,
        children: LayoutUtils.withGap(items, widget._controller.gap));
  }

  Widget buildGrid(List<Widget> formItems) {
    return ValueListenableBuilder(
        valueListenable: widget._controller.formStateNotifier,
        builder: (context, _, __) {
            bool hasAtLeastOneLabel = false;
            List<Widget> rows = [];
            for (int i = 0; i < formItems.length; i++) {
              Widget child = formItems[i];

              // build the label
              Widget label;
              if (child is HasController &&
                  child.controller is WidgetController &&
                  (child.controller as WidgetController).visible != false &&
                  (child.controller as WidgetController).label != null &&
                  !inExcludedList(child.controller as WidgetController)) {
                label = buildLabel(
                    (child.controller as WidgetController).label!,
                    (child.controller is FormFieldController
                        ? (child.controller as FormFieldController).labelStyle
                        : null),
                    child.controller is FormFieldController
                        ? (child.controller as FormFieldController).labelHint
                        : null);
                hasAtLeastOneLabel = true;
              } else {
                // empty label needs special treatment to line up with other labels
                label = widget._controller.labelMaxWidth == null
                    ? const SizedBox.shrink()
                    : SizedBox(
                        width: widget._controller.labelMaxWidth!.toDouble());
              }

              // add the input field and its label
              rows.add(
                  Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                // make the label takes 1/3 of the available space, subjected to its labelMaxWidth
                widget._controller.labelMaxWidth == null
                    ? Expanded(flex: 1, child: label)
                    : Flexible(
                        flex: 1,
                        child: ConstrainedBox(
                            constraints: BoxConstraints(
                                // constraint the label to the labelMaxWidth
                                minWidth:
                                    widget._controller.labelMaxWidth!.toDouble(),
                                maxWidth:
                                    widget._controller.labelMaxWidth!.toDouble()),
                            child: label)),
                // small gap after the label
                const SizedBox(width: 5),
                // make the widget takes 2/3 of the available space
                Expanded(flex: 2, child: child)
              ]));

              // add gap
              if (widget._controller.gap > 0 && i != formItems.length - 1) {
                rows.add(SizedBox(
                    width: widget._controller.gap.toDouble(),
                    height: widget._controller.gap.toDouble()));
              }
            }

            return hasAtLeastOneLabel
                ? Column(children: rows)
                : buildColumn(formItems);
          });
  }

  /// Note that this is only for side-by-side. Label display on top will have
  /// its label at the widget level
  Widget buildLabel(String label, TextStyle? labelStyle, String? labelHint) {
    util.TextOverflow textOverflow =
        util.TextOverflow.from(widget._controller.labelOverflow);

    Widget labelWidget = Text(
      Utils.translate(label, context),
      style: labelStyle ?? widget.controller.labelStyle,
      overflow: textOverflow.overflow,
      maxLines: textOverflow.maxLine,
      softWrap: textOverflow.softWrap,
    );
    if (labelHint == null) {
      return labelWidget;
    }
    return Stack(children: [
      Padding(padding: const EdgeInsets.only(right: 20), child: labelWidget),
      flutter.Positioned(
          right: 0,
          // align vertically
          top: 0,
          bottom: 0,
          child: Tooltip(
            triggerMode: TooltipTriggerMode.tap,
            message: labelHint,
            preferBelow: true,
            child: const Icon(Icons.info_outline, size: 18),
            showDuration: const Duration(seconds: 5),
          ))
    ]);
  }

  /// some widgets like Button have `label` attribute that is not meant for Form. Exclude them
  bool inExcludedList(WidgetController widgetController) {
    return widgetController is ButtonController;
  }
}

/// FormScope widget so all Form Fields can traverse to this
class EnsembleFormScope extends InheritedWidget {
  const EnsembleFormScope(
      {Key? key, required this.formState, required Widget child})
      : super(key: key, child: child);

  final FormState formState;

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) {
    return false;
  }
}

enum LabelPosition {
  none,
  start, // side by side label
  top // label on top of field
}
