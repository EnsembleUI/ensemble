import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/lottie/lottiestate.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class EnsembleLottie extends StatefulWidget
    with Invokable, HasController<LottieController, LottieState> {
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
    return {
      // Method to start animation in forward direction
      'forward': () {
        if (_controller.repeat) {
          _controller.lottieController!.repeat();
        } else {
          _controller.lottieController!.forward();
        }
      },
      // Method to run animation in reverse direction
      'reverse': () => _controller.lottieController!.reverse(),
      // Method to reset animation to initial position
      'reset': () => _controller.lottieController!.reset(),
      // Method to stop animation at current position
      'stop': () => _controller.lottieController!.stop(),
    };
  }

  @override
  Map<String, Function> setters() {
    return {
      'source': (value) =>
          _controller.source = Utils.getString(value, fallback: ''),
      'fit': (value) => _controller.fit = Utils.optionalString(value),
      'repeat': (value) => _controller.repeat = Utils.getBool(
            value,
            fallback: true,
          ),
      'onTap': (funcDefinition) => _controller.onTap =
          EnsembleAction.fromYaml(funcDefinition, initiator: this),
      // It defines whether animation would start at the time of rendering or not
      'autoPlay': (value) => _controller.autoPlay = Utils.getBool(
            value,
            fallback: true,
          ),
      // Callback method for onForward
      'onForward': (definition) => _controller.onForward =
          EnsembleAction.fromYaml(definition, initiator: this),
      // Callback method for onReverse
      'onReverse': (definition) => _controller.onReverse =
          EnsembleAction.fromYaml(definition, initiator: this),
      // Callback method for onComplete
      'onComplete': (definition) => _controller.onComplete =
          EnsembleAction.fromYaml(definition, initiator: this),
      // Callback method for onStop
      'onStop': (definition) => _controller.onStop =
          EnsembleAction.fromYaml(definition, initiator: this),
    };
  }
}

class LottieController extends BoxController {
  String source = '';
  String? fit;
  EnsembleAction? onTap;
  bool repeat = true;
  bool autoPlay = true;

  AnimationController? lottieController;

  EnsembleAction? onForward;
  EnsembleAction? onReverse;
  EnsembleAction? onComplete;
  EnsembleAction? onStop;

  void initializeLottieController(LottieComposition composition) {
    lottieController!.duration = composition.duration;

    if (autoPlay) {
      if (repeat) {
        lottieController!.repeat();
      } else {
        lottieController!.forward();
      }
    }
  }

  void addStatusListener(BuildContext context, EnsembleLottie widget) {
    final animationStatusActionMap = <AnimationStatus, EnsembleAction?>{
      AnimationStatus.forward: onForward,
      AnimationStatus.reverse: onReverse,
      AnimationStatus.dismissed: onStop,
      AnimationStatus.completed: onComplete,
    };

    lottieController!.addStatusListener(
      (status) {
        if (animationStatusActionMap[status] != null) {
          ScreenController().executeAction(
            context,
            animationStatusActionMap[status]!,
            event: EnsembleEvent(widget),
          );
        }
      },
    );
  }
}
