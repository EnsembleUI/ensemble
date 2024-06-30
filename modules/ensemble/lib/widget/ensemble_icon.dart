import 'package:ensemble/action/haptic_action.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/config.dart';
import 'package:ensemble/framework/error_handling.dart';
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

class EnsembleIcon extends StatefulWidget
    with Invokable, HasController<IconController, IconState> {
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
      'name': (value) => _controller.name = value,
      'library': (value) => _controller.library = Utils.optionalString(value),
      'size': (value) => _controller.size = Utils.optionalInt(value),
      'color': (value) => _controller.color = Utils.getColor(value),
      'splashColor': (value) => _controller.splashColor = Utils.getColor(value),
      'onTap': (funcDefinition) => _controller.onTap =
          EnsembleAction.from(funcDefinition, initiator: this),
      'onTapHaptic': (value) =>
          _controller.onTapHaptic = Utils.optionalString(value),
    };
  }

  @override
  Map<String, Function> methods() {
    return {};
  }
}

class IconController extends BoxController {
  // use name (icon is legacy fallback)
  dynamic name;
  dynamic icon;

  String? library;
  int? size;
  Color? color;
  Color? splashColor;
  EnsembleAction? onTap;
  String? onTapHaptic;
}

class IconState extends WidgetState<EnsembleIcon> {
  @override
  Widget buildWidget(BuildContext context) {
    if (widget._controller.name == null && widget._controller.icon == null) {
      throw LanguageError("Icon requires an icon name");
    }
    bool tapEnabled = widget._controller.onTap != null;
    Widget rtn = BoxWrapper(
        widget: ensembleLib.Icon(
            widget._controller.name ?? widget._controller.icon,
            library: widget._controller.library,
            size: widget._controller.size,
            color: widget._controller.color),
        boxController: widget._controller,
        ignoresDimension: true, // width/height is not applicable
        ignoresMargin: tapEnabled // click area has to be inside the margin
        );

    if (tapEnabled) {
      rtn = InkWell(
          splashColor: widget._controller.splashColor ??
              ThemeManager().getSplashColor(context),
          borderRadius: widget._controller.borderRadius?.getValue(),
          onTap: () {
            if (widget._controller.onTapHaptic != null) {
              ScreenController().executeAction(
                context,
                HapticAction(
                  type: widget._controller.onTapHaptic!,
                  onComplete: null,
                ),
              );
            }
            ScreenController().executeAction(context, widget._controller.onTap!,
                event: EnsembleEvent(widget));
          },
          child: rtn);
      if (widget._controller.margin != null) {
        rtn = Padding(padding: widget._controller.margin!, child: rtn);
      }
    }
    final isTestMode = EnvConfig().isTestMode;
    String id = widget._controller.testId ?? widget._controller.id ?? '';
    if (isTestMode && id.isNotEmpty) {
      rtn = Semantics(
        label: id,
        identifier: id,
        child: rtn,
      );
    }
    return rtn;
  }
}
