/// This class contains common widgets for use with Ensemble widgets.

import 'package:ensemble/layout/layout_helper.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:flutter/cupertino.dart';

/// wraps around the widget and gives it common container attributes
class BoxWrapper extends StatelessWidget {
  const BoxWrapper({
    super.key,
    required this.widget,
    required this.boxController
  });
  final Widget widget;
  final BoxController boxController;


  @override
  Widget build(BuildContext context) {
    var decoration = BoxDecoration(
      color: boxController.backgroundColor,
      image: boxController.backgroundImage?.image,
      gradient: boxController.backgroundGradient,



    );
    return Container(
      width: boxController.width?.toDouble(),
      height: boxController.height?.toDouble(),
      margin: boxController.margin,
      decoration: decoration,
      padding: boxController.padding,
      child: widget,
    );
  }

}