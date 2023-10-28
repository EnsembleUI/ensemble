import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:ensemble/widget/lottie/lottie.dart';
import 'package:ensemble/widget/widget_util.dart';
import 'package:flutter/widgets.dart';
import 'package:lottie/lottie.dart';

class LottieState extends WidgetState<EnsembleLottie>
    with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();

    final controller = widget.controller;
    controller.lottieController = AnimationController(vsync: this);

    final animationStatusActionMap = <AnimationStatus, EnsembleAction?>{
      AnimationStatus.forward: controller.onForward,
      AnimationStatus.reverse: controller.onReverse,
      AnimationStatus.dismissed: controller.onStop,
      AnimationStatus.completed: controller.onComplete,
    };

    controller.lottieController!.addStatusListener(
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

  @override
  Widget buildWidget(BuildContext context) {
    final controller = widget.controller;

    BoxFit? fit = WidgetUtils.getBoxFit(widget.controller.fit);

    Widget rtn = BoxWrapper(
      widget: buildLottie(fit, controller),
      boxController: controller,
      ignoresMargin: true,
      ignoresDimension: true,
    );

    if (controller.onTap != null) {
      rtn = GestureDetector(
        child: rtn,
        onTap: () => ScreenController().executeAction(
          context,
          controller.onTap!,
          event: EnsembleEvent(widget),
        ),
      );
    }

    if (controller.margin != null) {
      rtn = Padding(padding: controller.margin!, child: rtn);
    }
    return rtn;
  }

  Widget buildLottie(BoxFit? fit, LottieController controller) {
    String source = controller.source.trim();

    if (source.isNotEmpty) {
      // if is URL
      if (source.startsWith('https://') || source.startsWith('http://')) {
        return Lottie.network(
          controller.source,
          controller: controller.lottieController!,
          onLoaded: (composition) {
            initializeLottieController(
              composition: composition,
              controller: controller,
            );
          },
          width: controller.width?.toDouble(),
          height: controller.height?.toDouble(),
          repeat: controller.repeat,
          fit: fit,
          errorBuilder: (context, error, stacktrace) {
            return placeholderImage(controller);
          },
        );
      }
      // else attempt local asset
      else {
        return Lottie.asset(
          Utils.getLocalAssetFullPath(controller.source),
          controller: controller.lottieController!,
          onLoaded: (composition) {
            initializeLottieController(
              composition: composition,
              controller: controller,
            );
          },
          width: controller.width?.toDouble(),
          height: controller.height?.toDouble(),
          repeat: controller.repeat,
          fit: fit,
          errorBuilder: (context, error, stacktrace) {
            return placeholderImage(controller);
          },
        );
      }
    }
    return SizedBox(
      width: controller.width?.toDouble(),
      height: controller.height?.toDouble(),
    );
  }

  Widget placeholderImage(LottieController controller) {
    return SizedBox(
      width: controller.width?.toDouble(),
      height: controller.height?.toDouble(),
      child: Image.asset(
        'assets/images/img_placeholder.png',
        package: 'ensemble',
      ),
    );
  }

  void initializeLottieController({
    required LottieComposition composition,
    required LottieController controller,
  }) {
    controller.lottieController!.duration = composition.duration;

    if (controller.autoPlay) {
      if (controller.repeat) {
        controller.lottieController!.repeat();
      } else {
        controller.lottieController!.forward();
      }
    }
  }
}
