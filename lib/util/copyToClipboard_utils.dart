

import 'package:flutter/services.dart';

Future<void> copyText(String text) async {
Clipboard.setData(ClipboardData(text: text));
return;
}