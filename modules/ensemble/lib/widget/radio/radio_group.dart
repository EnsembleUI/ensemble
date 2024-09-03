import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/layout/box/box_utils.dart';
import 'package:ensemble/layout/templated.dart';
import 'package:ensemble/model/item_template.dart';
import 'package:ensemble/model/widget_models.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/widget/helpers/input_wrapper.dart';
import 'package:ensemble/widget/radio/custom_radio_tile.dart';
import 'package:flutter/material.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:ensemble/widget/helpers/form_helper.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:logger/logger.dart';

class RadioGroup extends StatefulWidget
    with
        Invokable,
        HasItemTemplate,
        HasController<RadioGroupController, RadioGroupState> {
  static const type = 'RadioGroup';

  RadioGroup({Key? key}) : super(key: key);

  final RadioGroupController _controller = RadioGroupController();

  @override
  RadioGroupController get controller => _controller;

  @override
  State<StatefulWidget> createState() => RadioGroupState();

  @override
  Map<String, Function> getters() {
    return {'selectedValue': () => _controller.selectedValue};
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {
      'selectedValue': (value) => _controller.selectedValue = value,
      'items': (values) => _controller.items = Utils.getList(values),
      'onChange': (definition) => _controller.onChange =
          EnsembleAction.from(definition, initiator: this),
      'direction': (value) =>
          _controller.direction = RadioGroupDirection.values.from(value),
      'controlPosition': (value) => _controller.controlPosition =
          WidgetControlPosition.values.from(value),
      'gap': (value) => _controller.gap = Utils.optionalInt(value, min: 0),
      'lineGap': (value) =>
          _controller.lineGap = Utils.optionalInt(value, min: 0),
      'itemGap': (value) =>
          _controller.itemGap = Utils.optionalInt(value, min: 0),
      'size': (value) => _controller.size = Utils.optionalInt(value, min: 0),
      'activeColor': (color) => _controller.activeColor = Utils.getColor(color),
      'inactiveColor': (color) =>
          _controller.inactiveColor = Utils.getColor(color),
    };
  }

  @override
  setItemTemplate(Map maybeTemplate) {
    _controller.itemTemplate = LabelValueItemTemplate.from(maybeTemplate);
  }
}

class RadioGroupController extends FormFieldController {
  dynamic selectedValue;

  // list of string for items
  List? items;

  // use item template for complex data structure & flexible UI
  LabelValueItemTemplate? itemTemplate;

  // gap between the Radio items
  int? gap;
  int? lineGap;

  // gap between the control and the label within a Radio item
  int? itemGap;

  RadioGroupDirection? direction;
  WidgetControlPosition? controlPosition;

  Color? activeColor;
  Color? inactiveColor;

  int? size;

  EnsembleAction? onChange;
}

class RadioGroupState extends FormFieldWidgetState<RadioGroup>
    with TemplatedWidgetState {
  List? itemTemplateData;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (widget._controller.itemTemplate != null) {
      registerItemTemplate(context, widget._controller.itemTemplate!,
          onDataChanged: (data) {
        setState(() => itemTemplateData = data);
      });
    }
  }

  @override
  Widget buildWidget(BuildContext context) {
    // build the children and gap if applicable
    var children = buildChildren();
    if (widget._controller.gap != null &&
        widget._controller.direction != RadioGroupDirection.wrap) {
      children = BoxUtils.buildChildrenAndGap(widget._controller.gap,
          children: children);
    }

    // wrap in different container based on direction
    Widget rtn;
    switch (widget._controller.direction) {
      case RadioGroupDirection.horizontal:
        rtn = Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: children,
        );
      case RadioGroupDirection.wrap:
        rtn = Wrap(
          spacing: widget._controller.gap?.toDouble() ?? 0,
          runSpacing: widget._controller.lineGap?.toDouble() ?? 0,
          children: children,
        );
      default:
        rtn = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
    }

    return InputWrapper(
      type: RadioGroup.type,
      controller: widget._controller,
      widget: FormField<String>(
        key: validatorKey,
        validator: (value) {
          if (widget._controller.required &&
              widget._controller.selectedValue == null) {
            return Utils.translateWithFallback(
                'ensemble.input.required', 'This field is required');
          }
          return null;
        },
        builder: (FormFieldState<String> field) {
          return InputDecorator(
              decoration: inputDecoration.copyWith(
                  contentPadding: EdgeInsets.zero,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorText: field.errorText),
              child: rtn);
        },
      ),
    );
  }

  /// combine items and item-template
  List<Widget> buildChildren() {
    var enabled = isEnabled();
    List<Widget> children = [];

    TextStyle? baseLabelStyle = Theme.of(context).textTheme.titleMedium;

    // add the children
    if (widget._controller.items != null) {
      children.addAll(widget._controller.items!.map((item) {
        var label, value;
        if (item is String) {
          label = value = item;
        } else if (item is Map) {
          if (item["label"] != null && item["value"] != null) {
            label = item["label"];
            value = item["value"];
          } else {
            label = value = item.toString();
          }
        }

        return CustomRadioTile(
          title: Text(label, style: baseLabelStyle),
          value: value,
          groupValue: widget._controller.selectedValue,
          controller: widget._controller,
          onChanged: enabled ? _onSelect : null,
        );
      }));
    }

    // add itemTemplate
    if (itemTemplateData != null &&
        widget._controller.itemTemplate != null &&
        scopeManager != null) {
      var itemTemplate = widget._controller.itemTemplate!;
      children.addAll(itemTemplateData!.map((itemData) {
        var templatedScope = scopeManager!.createChildScope();
        templatedScope.dataContext
            .addDataContextById(itemTemplate.name, itemData);

        Widget? title;
        dynamic value = templatedScope.dataContext.eval(itemTemplate.value);
        if (itemTemplate.label != null) {
          title = Text(templatedScope.dataContext.eval(itemTemplate.label),
              style: baseLabelStyle);
        } else if (itemTemplate.labelWidget != null) {
          title = DataScopeWidget(
              scopeManager: templatedScope,
              child: templatedScope
                  .buildWidgetFromDefinition(itemTemplate.labelWidget));
        }

        return CustomRadioTile(
            title: title ?? Text(""),
            value: value,
            groupValue: widget._controller.selectedValue,
            controller: widget._controller,
            onChanged: enabled ? _onSelect : null);
      }));
    }

    return children;
  }

  void _onSelect(dynamic value) {
    if (value == widget._controller.selectedValue) return;

    setState(() {
      widget._controller.selectedValue = value;
    });
    if (widget._controller.onChange != null) {
      ScreenController().executeAction(context, widget._controller.onChange!,
          event: EnsembleEvent(widget,
              data: {'selectedValue': widget._controller.selectedValue}));
    }
  }
}

enum RadioGroupDirection { vertical, horizontal, wrap }
