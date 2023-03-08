

import 'package:flutter/services.dart';

class CopyToClipboard{


  static Future<void> copyText(String text) async {
    if (text.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: text));
      return;
    } else {
      throw ('Please enter a string');
    }
  }

}