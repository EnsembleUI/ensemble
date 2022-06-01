import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/util/layout_utils.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/form_helper.dart';
import 'package:ensemble/widget/widget_util.dart' as util;
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart' as flutter;
import 'package:flutter/material.dart';
import 'package:flutter_layout_grid/flutter_layout_grid.dart';

class EnsembleForm extends StatefulWidget with UpdatableContainer, Invokable, HasController<FormController, FormState> {
  static const type = 'Form';
  EnsembleForm({Key? key}) : super(key: key);

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
  void initChildren({List<Widget>? children, ItemTemplate? itemTemplate}) {
    _controller.children = children;
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {
      'labelPosition': (value) => handleLabelPosition(Utils.optionalString(value)),
      'labelOverflow': (value) => _controller.labelOverflow = Utils.optionalString(value),
      'enabled': (value) => _controller.enabled = Utils.optionalBool(value),
      'width': (value) => _controller.width = Utils.optionalInt(value),
      'height': (value) => _controller.height = Utils.optionalInt(value),
      'gap': (value) => _controller.gap = Utils.getInt(value, fallback: FormController._defaultGap),
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
    EnsembleFormScope? scope = context.dependOnInheritedWidgetOfExactType<EnsembleFormScope>();
    return scope?.formState;
  }

  // whether a child Form field should show or hide its label
  bool get shouldFormFieldShowLabel => _controller.labelPosition == LabelPosition.top;

}

class FormController extends WidgetController {
  static const _defaultGap = 10;

  List<Widget>? children;
  LabelPosition labelPosition = LabelPosition.top;
  String? labelOverflow;
  bool? enabled;

  int? width;
  int? height;
  int gap = _defaultGap;
}

class FormState extends WidgetState<EnsembleForm> {

  final _formKey = GlobalKey<flutter.FormState>();
  bool validate() {
    return _formKey.currentState!.validate();
  }

  @override
  Widget build(BuildContext context) {
    if (widget._controller.children == null || widget._controller.children!.isEmpty) {
      return const SizedBox.shrink();
    }

    Widget? body;
    // use grid if labels are side by side
    if (widget._controller.labelPosition == LabelPosition.start) {
      body = buildGrid(widget._controller.children!);
    } else {
      body = buildColumn(widget._controller.children!);
    }
    return SizedBox(
      width: widget._controller.width?.toDouble(),
      height: widget._controller.height?.toDouble(),
      child: EnsembleFormScope(
        formState: this,
        child: Form(
          key: _formKey,
          child: body))
    );

  }

  Widget buildColumn(List<Widget> formItems) {
    return Column(
      crossAxisAlignment: flutter.CrossAxisAlignment.start,
      children: LayoutUtils.withGap(formItems, widget._controller.gap));
  }

  Widget buildGrid(List<Widget> formItems) {
    bool hasAtLeastOneLabel = false;
    List<Widget> children = [];
    for (Widget child in formItems) {
      // add the label
      if (child is HasController &&
          child.controller is FormFieldController &&
          (child.controller as FormFieldController).label != null) {
        children.add(GridPlacement(child:
          stretchAndVerticallyAlignLabel((child.controller as FormFieldController).label!)
        ));
        hasAtLeastOneLabel = true;
      } else {
        children.add(const GridPlacement(child: SizedBox.shrink()));
      }
      // add the widget
      children.add(GridPlacement(child: child));
    }

    // we only use the Grid if there exists at least 1 label
    if (hasAtLeastOneLabel) {
      return LayoutGrid(
        columnSizes: [1.fr, 2.fr], // ratio of form fields to its label
        rowSizes: List.filled(formItems.length, auto), // automatic row height
        children: children
      );
    }
    return buildColumn(formItems);

  }

  Widget stretchAndVerticallyAlignLabel(String label) {
    util.TextOverflow textOverflow = util.TextOverflow.from(widget._controller.labelOverflow);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            Utils.translate(label, context),
            overflow: textOverflow.overflow,
            maxLines: textOverflow.maxLine,
            softWrap: textOverflow.softWrap,
          )
        ))
      ]
    );
  }

}

/// FormScope widget so all Form Fields can traverse to this
class EnsembleFormScope extends InheritedWidget {
  const EnsembleFormScope({
    Key? key,
    required this.formState,
    required Widget child
  }) : super(key: key, child: child);

  final FormState formState;

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) {
    return false;
  }

}

enum LabelPosition {
  none,
  start,  // side by side label
  top     // label on top of field
}