import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/lottie/lottiestate.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
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
    if (kIsWeb) {
      // A little hacky way to check if html renderer is used as only html render would have the lottieController null.
      // lottieController is null only for the html renderer.
      // Cannot use js.context['flutterCanvasKit'] != null to check the html renderer as it requires importing dart:js which will break app in mobile runtime as dart:js is a web only package
      final bool isNotHtml = _controller.lottieController != null;

      print(isNotHtml);

      return {
        // Method to start animation in forward direction
        'forward': () {
          if (isNotHtml) {
            if (_controller.repeat) {
              _controller.lottieController?.repeat();
            } else {
              _controller.lottieController?.forward();
            }
          } else {
            _controller.lottieAction?.forward();
          }
        },
        // Method to run animation in reverse direction
        'reverse': () {
          if (isNotHtml) {
            _controller.lottieController?.reverse();
          } else {
            _controller.lottieAction?.reverse();
          }
        },
        // Method to reset animation to initial position
        'reset': () {
          if (isNotHtml) {
            _controller.lottieController?.reset();
          } else {
            _controller.lottieAction?.reset();
          }
        },
        // Method to stop animation at current position
        'stop': () {
          if (isNotHtml) {
            _controller.lottieController?.stop();
          } else {
            _controller.lottieAction?.stop();
          }
        },
      };
    }

    return {
      // Method to start animation in forward direction
      'forward': () {
        if (_controller.repeat) {
          _controller.lottieController?.repeat();
        } else {
          _controller.lottieController?.forward();
        }
      },
      // Method to run animation in reverse direction
      'reverse': () => _controller.lottieController?.reverse(),
      // Method to reset animation to initial position
      'reset': () => _controller.lottieController?.reset(),
      // Method to stop animation at current position
      'stop': () => _controller.lottieController?.stop(),
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
          EnsembleAction.from(funcDefinition, initiator: this),
      'onTapHaptic': (value) =>
          _controller.onTapHaptic = Utils.optionalString(value),
      // It defines whether animation would start at the time of rendering or not
      'autoPlay': (value) => _controller.autoPlay = Utils.getBool(
            value,
            fallback: true,
          ),
      // Callback method for onForward
      'onForward': (definition) => _controller.onForward =
          EnsembleAction.from(definition, initiator: this),
      // Callback method for onReverse
      'onReverse': (definition) => _controller.onReverse =
          EnsembleAction.from(definition, initiator: this),
      // Callback method for onComplete
      'onComplete': (definition) => _controller.onComplete =
          EnsembleAction.from(definition, initiator: this),
      // Callback method for onStop
      'onStop': (definition) =>
          _controller.onStop = EnsembleAction.from(definition, initiator: this),
    };
  }
}

mixin LottieAction on EWidgetState<EnsembleLottie> {
  void forward();
  void reverse();
  void reset();
  void stop();
}

class LottieController extends BoxController {
  String source = '';
  String? fit;
  EnsembleAction? onTap;
  String? onTapHaptic;
  bool repeat = true;
  bool autoPlay = true;

  // lottieController and lottieAction are different things.
  // lottieController is a AnimationController which is used to control animation and hook callbacks for all the platforms except web html renderer
  // lottieAction is a mixin that is used to define all the methods for the html renderer. Cannot use normal AnimationController as html is rendered using iframe and doesn't use Lottie widget
  AnimationController? lottieController;
  LottieAction? lottieAction;

  EnsembleAction? onForward;
  EnsembleAction? onReverse;
  EnsembleAction? onComplete;
  EnsembleAction? onStop;

  // method to initialize the AnimationController lottieController
  void initializeLottieController(LottieComposition composition) {
    // Setting the duration of the animation once the lottie is loaded
    lottieController?.duration = composition.duration;

    if (autoPlay) {
      if (repeat) {
        lottieController!.repeat();
      } else {
        lottieController!.forward();
      }
    }
  }

  // Method to link statusListener with their respective events.
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
