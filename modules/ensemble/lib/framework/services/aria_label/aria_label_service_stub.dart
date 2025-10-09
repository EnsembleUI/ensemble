import 'package:flutter/foundation.dart';

abstract class AriaLabelService {
  static void applyLabels(Map<String, String> explicitLabels) {
    if (!kIsWeb) return; // no-op on non-web
  }
}
