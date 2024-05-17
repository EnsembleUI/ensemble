import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/form_helper.dart';
import 'package:flutter/material.dart';

// for form field that have text placeholder (e.g. TextInput)
mixin HasTextPlaceholder on FormFieldController {
  String? placeholder;
  TextStyle? placeholderStyle;

  @Deprecated("use placeholder")
  String? hintText;
  @Deprecated("use placeholderStyle")
  TextStyle? hintStyle;

  Map<String, Function> get textPlaceholderSetters => {
        'placeholder': (value) => placeholder = Utils.optionalString(value),
        'placeholderStyle': (style) =>
            placeholderStyle = Utils.getTextStyle(style),
        // deprecated. Use placeholder & placeholderStyle
        'hintText': (value) => hintText = Utils.optionalString(value),
        'hintStyle': (style) => hintStyle = Utils.getTextStyle(style),
      };

  Map<String, Function> get textPlaceholderGetters => {
        'placeholder': () => placeholder,
        'placeholderStyle': () => placeholderStyle,
      };
}
