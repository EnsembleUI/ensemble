import 'package:ensemble/action/haptic_action.dart';
import 'package:ensemble/framework/assets_service.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/box_wrapper.dart';
import 'package:ensemble/widget/lottie/lottie.dart';
import 'package:flutter/widgets.dart';
import 'package:lottie/lottie.dart';

class LottieState extends EWidgetState<EnsembleLottie>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this);
    widget.controller.lottieController = _animationController;
    widget.controller.addStatusListener(context, widget);
  }

  @override
  void dispose() {
    _animationController.stop();
    _animationController.dispose();

    if (widget.controller.lottieController == _animationController) {
      widget.controller.lottieController = null;
    }
    super.dispose();
  }

  @override
  Widget buildWidget(BuildContext context) {
    BoxFit? fit = Utils.getBoxFit(widget.controller.fit);

    Widget rtn = BoxWrapper(
        widget: buildLottie(fit),
        boxController: widget.controller,
        ignoresMargin: true,
        ignoresDimension: true);
    if (widget.controller.onTap != null) {
      rtn = GestureDetector(
          child: rtn,
          onTap: () {
            if (widget.controller.onTapHaptic != null) {
              ScreenController().executeAction(
                context,
                HapticAction(
                  type: widget.controller.onTapHaptic!,
                  onComplete: null,
                ),
              );
            }

            ScreenController().executeAction(context, widget.controller.onTap!,
                event: EnsembleEvent(widget));
          });
    }
    if (widget.controller.margin != null) {
      rtn = Padding(padding: widget.controller.margin!, child: rtn);
    }
    return rtn;
  }

  Widget buildLottie(BoxFit? fit) {
    String source = widget.controller.source.trim();
    if (source.isNotEmpty) {
      // if is URL
      if (source.startsWith('https://') || source.startsWith('http://')) {
        return FutureBuilder<AssetResolution>(
          future: AssetResolver.resolve(source),
          builder: (context, snapshot) {
            if (snapshot.hasError || !snapshot.hasData) {
              return placeholderImage();
            }
            final resolved = snapshot.data!;
            if (resolved.isAsset) {
              return Lottie.asset(
                resolved.path,
                controller: widget.controller.lottieController,
                onLoaded: (composition) {
                  widget.controller.initializeLottieController(composition);
                },
                width: widget.controller.width?.toDouble(),
                height: widget.controller.height?.toDouble(),
                repeat: widget.controller.repeat,
                fit: fit,
                errorBuilder: (context, error, stacktrace) =>
                    placeholderImage(),
              );
            }
            return Lottie.network(resolved.path,
                controller: widget.controller.lottieController,
                onLoaded: (composition) {
                  widget.controller.initializeLottieController(composition);
                },
                width: widget.controller.width?.toDouble(),
                height: widget.controller.height?.toDouble(),
                repeat: widget.controller.repeat,
                fit: fit,
                errorBuilder: (context, error, stacktrace) =>
                    placeholderImage());
          },
        );
      }
      // else attempt local asset
      else {
        return Lottie.asset(
          Utils.getLocalAssetFullPath(widget.controller.source),
          controller: widget.controller.lottieController,
          onLoaded: (composition) {
            widget.controller.initializeLottieController(composition);
          },
          width: widget.controller.width?.toDouble(),
          height: widget.controller.height?.toDouble(),
          repeat: widget.controller.repeat,
          fit: fit,
          errorBuilder: (context, error, stacktrace) => placeholderImage(),
        );
      }
    }
    return SizedBox(
      width: widget.controller.width?.toDouble(),
      height: widget.controller.height?.toDouble(),
    );
  }

  Widget placeholderImage() {
    return SizedBox(
        width: widget.controller.width?.toDouble(),
        height: widget.controller.height?.toDouble(),
        child: Image.asset('assets/images/img_placeholder.png',
            package: 'ensemble'));
  }
}
