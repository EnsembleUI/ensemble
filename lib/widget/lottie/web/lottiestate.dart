// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:math';

import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:ensemble/widget/lottie/lottie.dart';
import 'package:ensemble/widget/widget_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:js_widget/js_widget.dart';
import 'dart:js' as js;

import 'package:lottie/lottie.dart';

class LottieState extends WidgetState<EnsembleLottie>
    with SingleTickerProviderStateMixin {
  String id = 'lottie_${Random().nextInt(900000) + 100000}';

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
    final isCanvasKit = js.context['flutterCanvasKit'] != null;
    final controller = widget.controller;

    BoxFit? fit = WidgetUtils.getBoxFit(controller.fit);
    Widget rtn = BoxWrapper(
      widget: isCanvasKit
          ? buildLottieCanvas(fit, controller)
          : buildLottieHtml(fit, controller),
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
          event: EnsembleEvent(
            widget,
          ),
        ),
      );
    }

    if (controller.margin != null) {
      rtn = Padding(padding: controller.margin!, child: rtn);
    }

    return rtn;
  }

  Widget buildLottieHtml(BoxFit? fit, LottieController controller) {
    String source = controller.source.trim();
    double width = controller.width?.toDouble() ?? 250;
    double height = controller.height?.toDouble() ?? 250;
    String id = controller.id ?? this.id;
    String repeat = controller.repeat.toString();
    String tag = '<div id="$id"></div>';

    if (controller.width == null || controller.height == null) {
      throw RuntimeError(
        'Lottie widget must have explicit width and height for html renderer in the browser (this includes the preview in the editor). You do not need to specify width or height for native apps or for canvaskit renderer. Defaulting to $width for width and $height for height',
      );
    }

    if (source.isNotEmpty) {
      // image binding is tricky. When the URL has not been resolved
      // the image will throw exception. We have to use a permanent placeholder
      // until the binding engages
      return JsWidget(
        id: id,
        createHtmlTag: () => tag,
        data: source,
        listener: (String msg) {
          if (controller.onTap != null) {
            ScreenController().executeAction(
              context,
              controller.onTap!,
              event: EnsembleEvent(widget),
            );
          }
        },
        scriptToInstantiate: (String c) {
          String script =
              'bodymovin.loadAnimation({container: document.getElementById("$id"),renderer: "svg",loop: $repeat,autoplay: true,path: "$c"});';

          if (controller.onTap != null) {
            script +=
                'document.getElementById("$id").addEventListener("click",() => handleMessage("$id",""));';
          }

          return script;
        },
        size: Size(width, height),
      );
    }

    return blankPlaceholder(controller);
  }

  Widget buildLottieCanvas(BoxFit? fit, LottieController controller) {
    String source = controller.source.trim();
    if (source.isNotEmpty) {
      // if is URL
      if (source.startsWith('https://') || source.startsWith('http://')) {
        // image binding is tricky. When the URL has not been resolved
        // the image will throw exception. We have to use a permanent placeholder
        // until the binding engages
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

      return Lottie.asset(
        Utils.getLocalAssetFullPath(controller.source),
        controller: controller.lottieController!,
        onLoaded: (LottieComposition composition) {
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

    return blankPlaceholder(controller);
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

  Widget blankPlaceholder(LottieController controller) {
    return SizedBox(
      width: controller.width?.toDouble(),
      height: controller.height?.toDouble(),
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
