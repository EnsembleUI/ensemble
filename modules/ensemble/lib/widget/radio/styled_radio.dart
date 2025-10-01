import 'package:flutter/material.dart';

class StyledRadio extends StatelessWidget {
  StyledRadio(
      {this.value,
      this.groupValue,
      this.onChanged,
      this.activeColor,
      this.inactiveColor});

  final dynamic value;
  final dynamic groupValue;
  final Function(dynamic)? onChanged;

  final Color? activeColor;
  final Color? inactiveColor;

  @override
  Widget build(BuildContext context) {
    return Radio(
        value: value,
        groupValue: groupValue,
        onChanged: onChanged,
        activeColor: activeColor,
        fillColor: inactiveColor != null
            ? WidgetStateProperty.resolveWith<Color?>((states) {
                if (states.contains(WidgetState.selected) ||
                    states.contains(WidgetState.disabled) ||
                    states.contains(WidgetState.error)) {
                  // we don't override these states
                  return null;
                }
                return inactiveColor;
              })
            : null,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap);
  }
}
