
import 'package:ensemble/framework/icon.dart' as ensembleLib;
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/widget.dart';
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
      'icon': (value) => _controller.icon = Utils.getString(value, fallback: ''),
      'library': (value) => _controller.library = Utils.optionalString(value),
      'size': (value) => _controller.size = Utils.optionalInt(value),
      'color': (value) => _controller.color = Utils.optionalInt(value),
    };
  }
  @override
  Map<String, Function> methods() {
    return {};
  }

}
class IconController extends WidgetController {
  late String icon;
  String? library;
  int? size;
  int? color;
}

class IconState extends WidgetState<EnsembleIcon> {

  @override
  Widget build(BuildContext context) {
    return ensembleLib.Icon(
      widget._controller.icon,
      library: widget._controller.library,
      size: widget._controller.size,
      color: widget._controller.color != null ? Color(widget._controller.color!) : null
    );
  }



}