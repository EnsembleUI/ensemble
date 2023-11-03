import 'package:ensemble/framework/ensemble_widget.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/framework/widget/image.dart' as framework;
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';

class Avatar extends EnsembleWidget<AvatarController> {
  static const type = 'Avatar';
  const Avatar._(super.controller, {super.key});

  factory Avatar.build(dynamic controller) {
    return Avatar._(
        controller is AvatarController ? controller : AvatarController());
  }

  @override
  State<StatefulWidget> createState() => AvatarState();
}

class AvatarController extends EnsembleController {
  int? width;
  int? height;

  // either source or name is required
  String? source;
  String? name;

  @override
  Map<String, Function> getters() {
    return {};
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {
      'width': (value) => width = Utils.optionalInt(value),
      'height': (value) => height = Utils.optionalInt(value),
      'source': (value) => source = Utils.optionalString(value),
      'name': (value) => name = Utils.optionalString(value),
    };
  }
}

class AvatarState extends EnsembleWidgetState<Avatar> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.controller.width?.toDouble(),
      height: widget.controller.height?.toDouble(),
      clipBehavior: Clip.hardEdge,
      decoration:
          BoxDecoration(borderRadius: BorderRadius.all(Radius.circular(10))),
      child: framework.Image(
          source: 'https://mui.com/static/images/avatar/1.jpg',
          width: widget.controller.width?.toDouble(),
          height: widget.controller.height?.toDouble()),
    );
  }
}
