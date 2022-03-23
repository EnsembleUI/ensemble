import 'package:ensemble/widget/widget_builder.dart' as ensemble;
import 'package:flutter/material.dart';

class TestUtils {

  /// get the Wrapper App for our test widget builder
  static Widget getAppWrapper(ensemble.WidgetBuilder widgetBuilder) {
    return Builder(builder: (BuildContext context) {
      return MaterialApp(
          home: Scaffold(
              body: widgetBuilder.buildWidget(context: context)
          )
      );
    });
  }
}