
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/widget/icon.dart' as ensembleLib;
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/framework/theme/theme_manager.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:flutter/material.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';

class EnsembleIcon extends StatefulWidget with Invokable, HasController<IconController, IconState> {
  static const type = 'Icon';
  EnsembleIcon({Key? key}) : super(key: key);

  final IconController _controller = IconController();
  @override
  IconController get controller => _controller;

  @override
  State<StatefulWidget> createState() => IconState();

  @override
  Map<String, Function> getters() {
    return {};
  }
  @override
  Map<String, Function> setters() {
    return {
      'icon': (value) => _controller.icon = value,
      'library': (value) => _controller.library = Utils.optionalString(value),
      'size': (value) => _controller.size = Utils.optionalInt(value),
      'color': (value) => _controller.color = Utils.getColor(value),
      'splashColor': (value) => _controller.splashColor = Utils.getColor(value),
      'onTap': (funcDefinition) => _controller.onTap = Utils.getAction(funcDefinition, initiator: this),
    };
  }
  @override
  Map<String, Function> methods() {
    return {};
  }

}
class IconController extends BoxController {
  dynamic icon;
  String? library;
  int? size;
  Color? color;
  Color? splashColor;
  EnsembleAction? onTap;
}

class IconState extends WidgetState<EnsembleIcon> {

  @override
  Widget buildWidget(BuildContext context) {
    bool tapEnabled = widget._controller.onTap != null;

    Widget icon = BoxWrapper(
        widget: ensembleLib.Icon(
            widget._controller.icon,
            library: widget._controller.library,
            size: widget._controller.size,
            color: widget._controller.color
        ),
        boxController: widget._controller,
        ignoresDimension: true,   // width/height is not applicable
        ignoresMargin: tapEnabled       // click area has to be inside the margin
    );

    if (tapEnabled) {
      icon = InkWell(
          child: icon,
          splashColor: widget._controller.splashColor ?? ThemeManager.getSplashColor(context),
          borderRadius: widget._controller.borderRadius?.getValue(),
          onTap: () =>
              ScreenController().executeAction(
                  context,
                  widget._controller.onTap!,
                  event: EnsembleEvent(widget))
      );
      if (widget._controller.margin != null) {
        icon = Padding(
            padding: widget._controller.margin!,
            child: icon);
      }
    }
    return icon;
  }



}