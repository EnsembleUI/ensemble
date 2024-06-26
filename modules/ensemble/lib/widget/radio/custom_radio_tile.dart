import 'package:ensemble/model/widget_models.dart';
import 'package:ensemble/widget/radio_group.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// For each radio button
class CustomRadioTile extends StatelessWidget {
  final Widget title;
  final dynamic value;
  final dynamic groupValue;
  final RadioGroupController controller;

  final Function(dynamic)? onChanged;

  CustomRadioTile({
    required this.title,
    required this.value,
    required this.groupValue,
    required this.controller,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    var controlPosition = controller.controlPosition;
    if (controlPosition == null ||
        controlPosition == WidgetControlPosition.platform) {
      controlPosition = defaultTargetPlatform == TargetPlatform.iOS
          ? WidgetControlPosition.trailing
          : WidgetControlPosition.leading;
    }

    // set our inactiveColor
    var fillColorStates;
    if (controller.inactiveColor != null) {
      fillColorStates = MaterialStateProperty.resolveWith<Color?>((states) {
        if (states.contains(MaterialState.selected) &&
            states.contains(MaterialState.disabled) &&
            states.contains(MaterialState.error)) {
          // we don't override these states
          return null;
        }
        return controller.inactiveColor;
      });
    }

    // when laying out radios vertically, we want the label to stretch
    // so the radios will line up
    var isVertical = controller.direction == null ||
        controller.direction == RadioGroupDirection.vertical;

    var parts = [
      Radio(
          value: value,
          groupValue: groupValue,
          onChanged: onChanged,
          activeColor: controller.activeColor,
          fillColor: fillColorStates,
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
      isVertical ? Expanded(child: title) : title
    ];
    if (controller.itemGap != null) {
      parts.insert(
          1,
          SizedBox(
              width: controller.itemGap!.toDouble(),
              height: controller.itemGap!.toDouble()));
    }
    if (controlPosition == WidgetControlPosition.trailing) {
      parts = parts.reversed.toList();
    }

    return InkWell(
        onTap: onChanged != null ? () => onChanged!(value) : null,
        child: Row(
            mainAxisSize: isVertical ? MainAxisSize.max : MainAxisSize.min,
            children: parts));
  }
}
