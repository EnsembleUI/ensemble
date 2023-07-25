import 'package:flutter/services.dart';

class InputFormatter {
  static List<TextInputFormatter> getFormatter(String? inputType) {
    if (inputType == null) return [];

    switch (inputType) {
      case 'number':
        return [FilteringTextInputFormatter.digitsOnly];
      default:
        return [];
    }
  }
}
