
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/layout/layout_helper.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/lottie/lottiestate.dart';
import 'package:ensemble/widget/widget_util.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class EnsembleLottie extends StatefulWidget with Invokable, HasController<LottieController, LottieState> {
  static const type = 'Lottie';
  EnsembleLottie({Key? key}) : super(key: key);

  final LottieController _controller = LottieController();
  @override
  get controller => _controller;

  @override
  State<StatefulWidget> createState() => LottieState();

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
      'source': (value) => _controller.source = Utils.getString(value, fallback: ''),
      'width': (value) => _controller.width = Utils.optionalInt(value),
      'height': (value) => _controller.height = Utils.optionalInt(value),
      'fit': (value) => _controller.fit = Utils.optionalString(value),
      'repeat': (value) => _controller.repeat = Utils.optionalBool(value),
      'onTap': (funcDefinition) => _controller.onTap = Utils.getAction(funcDefinition, initiator: this),
    };
  }

}

class LottieController extends BoxController {
  String source = '';
  int? width;
  int? height;
  bool? repeat;
  String? fit;
  EnsembleAction? onTap;
}

