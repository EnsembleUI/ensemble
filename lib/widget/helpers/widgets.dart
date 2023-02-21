/// This class contains common widgets for use with Ensemble widgets.

import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/helpers/theme_manager.dart';
import 'package:flutter/cupertino.dart';

/// wraps around a widget and gives it common box attributes
class BoxWrapper extends StatelessWidget {
  const BoxWrapper({
    super.key,
    required this.widget,
    required this.boxController,

    // sometimes our widget may register a gesture. Such gesture should not
    // include the margin. This allows it to handle the margin on its own.
    this.ignoresMargin = false,

    // width/height maybe applied at the child, or not applicable
    this.ignoresDimension = false
  });
  final Widget widget;
  final BoxController boxController;

  // child widget may want to control these themselves
  final bool ignoresMargin;
  final bool ignoresDimension;

  @override
  Widget build(BuildContext context) {
    if (!boxController.requiresBox(ignoresMargin, ignoresDimension)) {
      return widget;
    }
    return Container(
      width: ignoresDimension ? null : boxController.width?.toDouble(),
      height: ignoresDimension ? null : boxController.height?.toDouble(),
      margin: ignoresMargin ? null : boxController.margin,
      padding: boxController.padding,
      child: widget,
      decoration: !boxController.hasBoxDecoration()
          ? null
          : BoxDecoration(
              color: boxController.backgroundColor,
              image: boxController.backgroundImage?.image,
              gradient: boxController.backgroundGradient,
              border: !boxController.hasBorder()
                  ? null
                  : Border.all(
                      color: boxController.borderColor ??
                          ThemeManager.getBorderColor(context),
                      width: boxController.borderWidth?.toDouble() ??
                          ThemeManager.getBorderThickness(context)),
              borderRadius: boxController.borderRadius?.getValue(),
              boxShadow: !boxController.hasBoxShadow()
                  ? null
                  : <BoxShadow>[
                      BoxShadow(
                        color: boxController.shadowColor ??
                            ThemeManager.getShadowColor(context),
                        blurRadius:
                            boxController.shadowRadius?.toDouble() ??
                                ThemeManager.getShadowRadius(context),
                        offset: boxController.shadowOffset ??
                            ThemeManager.getShadowOffset(context),
                        blurStyle: boxController.shadowStyle ??
                            ThemeManager.getShadowStyle(context))
                    ]));
  }

}