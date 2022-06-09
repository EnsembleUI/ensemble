import 'package:ensemble/page_model.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:flutter/cupertino.dart';

/// represent a Custom View declared in a yaml screen
class CustomView extends StatelessWidget {
  const CustomView({Key? key, required this.childWidget, required this.viewBehavior}) : super(key: key);
  final Widget childWidget;
  final ViewBehavior viewBehavior;



  @override
  Widget build(BuildContext context) {
    // execute onLoad if applicable
    if (viewBehavior.onLoad != null) {
      ScreenController().executeAction(context, viewBehavior.onLoad!);
    }
    return childWidget;
  }


}