import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class RoleFlags {
  final bool button;
  final bool header;
  final bool image;
  final bool textField;
  final bool? checked;
  final bool? toggled;
  final bool? enabled;
  final bool? readOnly;
  final bool? obscured;
  final bool? multiline;
  final bool? selected;
  final bool? inMutuallyExclusiveGroup;

  const RoleFlags({
    required this.button,
    required this.header,
    required this.image,
    required this.textField,
    this.checked,
    this.toggled,
    this.enabled,
    this.readOnly,
    this.obscured,
    this.multiline,
    this.selected,
    this.inMutuallyExclusiveGroup,
  });
}

RoleFlags computeRoleFlags(Widget widget, String? explicitRole) {
  final String? role = explicitRole?.toLowerCase();

  bool inferIsButton() =>
      widget is ElevatedButton ||
      widget is TextButton ||
      widget is OutlinedButton ||
      widget is IconButton ||
      widget is FilledButton ||
      widget is FloatingActionButton ||
      widget is MaterialButton ||
      widget is RawMaterialButton ||
      widget is BackButton ||
      widget is CloseButton ||
      widget is DropdownButton ||
      widget is PopupMenuButton ||
      widget is SegmentedButton ||
      widget is CupertinoButton ||
      widget is InkResponse ||
      widget is InkWell ||
      widget is GestureDetector;

  bool inferIsTextField() =>
      widget is TextField ||
      widget is TextFormField ||
      widget is EditableText ||
      widget is CupertinoTextField;

  bool inferIsImage() =>
      widget is Image ||
      widget is FadeInImage ||
      widget is CircleAvatar ||
      widget is RawImage;

  bool? inferChecked() {
    if (widget is Checkbox) return (widget).value == true;
    if (widget is CheckboxListTile) return (widget).value == true;
    if (widget is Radio) return (widget).groupValue == (widget).value;
    if (widget is RadioListTile) return (widget).selected == true;
    return null;
  }

  bool? inferToggled() {
    if (widget is Switch) return (widget).value == true;
    if (widget is SwitchListTile) return (widget).value == true;
    return null;
  }

  bool? inferEnabled() {
    if (widget is ElevatedButton) return (widget).onPressed != null;
    if (widget is TextButton) return (widget).onPressed != null;
    if (widget is OutlinedButton) return (widget).onPressed != null;
    if (widget is IconButton) return (widget).onPressed != null;
    if (widget is FilledButton) return (widget).onPressed != null;
    if (widget is FloatingActionButton) return (widget).onPressed != null;
    if (widget is MaterialButton) return (widget).onPressed != null;
    if (widget is RawMaterialButton) return (widget).onPressed != null;
    if (widget is Checkbox) return (widget).onChanged != null;
    if (widget is CheckboxListTile) return (widget).onChanged != null;
    if (widget is Radio) return (widget).onChanged != null;
    if (widget is RadioListTile) return (widget).onChanged != null;
    if (widget is Switch) return (widget).onChanged != null;
    if (widget is SwitchListTile) return (widget).onChanged != null;
    if (widget is TextField) return (widget).enabled;
    if (widget is TextFormField) return (widget).enabled;
    if (widget is CupertinoTextField)
      return !(widget).enabled == false ? true : (widget).enabled;
    return null;
  }

  bool? inferReadOnly() {
    if (widget is TextField) return (widget).readOnly;
    if (widget is CupertinoTextField) return (widget).readOnly;
    return null;
  }

  bool? inferObscured() {
    if (widget is TextField) return (widget).obscureText;
    return null;
  }

  bool? inferMultiline() {
    if (widget is TextField)
      return (widget).maxLines == null || (widget).maxLines! > 1;
    return null;
  }

  bool? inferSelected() {
    if (widget is RadioListTile) return (widget).selected;
    return null;
  }

  bool? inferInMutuallyExclusiveGroup() {
    if (widget is Radio || widget is RadioListTile) return true;
    return null;
  }

  final bool isButton = (role == 'button') || (role == null && inferIsButton());
  final bool isHeader = role == 'header';
  final bool isImage = (role == 'image') || (role == null && inferIsImage());
  final bool isTextField =
      (role == 'text-field') || (role == null && inferIsTextField());

  bool? checked;
  bool? toggled;
  bool? enabled;
  bool? readOnly;
  bool? obscured;
  bool? multiline;
  bool? selected;
  bool? inMutuallyExclusiveGroup;
  if (role == 'checkbox') {
    checked = inferChecked() ?? false;
  } else if (role == 'switch') {
    toggled = inferToggled() ?? false;
  } else if (role == null) {
    checked = inferChecked();
    toggled = inferToggled();
  }
  enabled = inferEnabled();
  readOnly = inferReadOnly();
  obscured = inferObscured();
  multiline = inferMultiline();
  selected = inferSelected();
  inMutuallyExclusiveGroup = inferInMutuallyExclusiveGroup();

  return RoleFlags(
    button: isButton,
    header: isHeader,
    image: isImage,
    textField: isTextField,
    checked: checked,
    toggled: toggled,
    enabled: enabled,
    readOnly: readOnly,
    obscured: obscured,
    multiline: multiline,
    selected: selected,
    inMutuallyExclusiveGroup: inMutuallyExclusiveGroup,
  );
}
