import 'package:ensemble/action/haptic_action.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/model.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'package:ensemble/framework/widget/icon.dart' as framework;

class EnsembleIconButton extends StatefulWidget
    with Invokable, HasController<IconButtonController, IconButtonState> {
  static const type = 'IconButton';

  final IconButtonController _controller = IconButtonController();
  @override
  get controller => _controller;

  @override
  State<StatefulWidget> createState() => IconButtonState();

  @override
  Map<String, Function> getters() {
    return {};
  }

  @override
  Map<String, Function> methods() {
    // TODO: implement methods
    throw UnimplementedError();
  }

  @override
  Map<String, Function> setters() {
    return {
      'icon': (value) => _controller.icon = Utils.getIcon(value),
      'onTap': (funcDefinition) => _controller.onTap =
          EnsembleAction.fromYaml(funcDefinition, initiator: this),
      'onTapHaptic': (value) =>
          _controller.onTapHaptic = Utils.optionalString(value),
    };
  }
}

class IconButtonController extends WidgetController {
  int? size;
  IconModel? icon;
  EnsembleAction? onTap;
  String? onTapHaptic;
}

class IconButtonState extends WidgetState<EnsembleIconButton> {
  @override
  Widget buildWidget(BuildContext context) {
    return FrameworkIconButton(
        onTap: widget._controller.onTap != null
            ? () => onTap(context, widget._controller.onTap!)
            : null,
        child: widget._controller.icon != null
            ? framework.Icon.fromModel(widget._controller.icon!)
            : const SizedBox.shrink());
  }

  void onTap(BuildContext context, EnsembleAction onTap) {
    if (widget._controller.onTapHaptic != null) {
      ScreenController().executeAction(
        context,
        HapticAction(
          type: widget._controller.onTapHaptic!,
          onComplete: null,
        ),
      );
    }

    ScreenController()
        .executeAction(context, onTap, event: EnsembleEvent(widget));
  }
}

/// this is also used internally within our framework
class FrameworkIconButton extends StatelessWidget {
  const FrameworkIconButton(
      {super.key, required this.child, this.size, this.onTap});
  final defaultSize = 64.0;

  final Widget child;
  final int? size;
  final Function? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
        color: Colors.transparent,
        child: InkWell(
            onTap: onTap != null ? () => onTap!() : null,
            customBorder: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999)),
            child: Container(
              width: size?.toDouble() ?? defaultSize,
              height: size?.toDouble() ?? defaultSize,
              //padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
              ),
              child: child,
            )));
  }
}
