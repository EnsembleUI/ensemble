import 'package:flutter/services.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

class InputFormatter {
  static List<TextInputFormatter> getFormatter(
      String? inputType, String? mask) {
    switch (inputType) {
      case 'number':
        return [
          FilteringTextInputFormatter.digitsOnly,
          if (mask != null)
            MaskTextInputFormatter(
                mask: mask, type: MaskAutoCompletionType.eager)
        ];
      default:
        return [
          if (mask != null)
            MaskTextInputFormatter(
                mask: mask, type: MaskAutoCompletionType.eager)
        ];
    }
  }
}
