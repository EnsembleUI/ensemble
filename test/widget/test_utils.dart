import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class TestUtils {

  /// wraps the test widget in MaterialApp and Scaffold
  static Widget wrapTestWidget(Widget widget) =>
      MaterialApp(home: Scaffold(body: widget));
}