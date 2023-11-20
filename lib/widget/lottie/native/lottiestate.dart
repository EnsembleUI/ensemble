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
    widget.controller
      ..lottieController = AnimationController(vsync: this)
      ..addStatusListener(context, widget);
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
          onTap: () => ScreenController().executeAction(
              context, widget.controller.onTap!,
              event: EnsembleEvent(widget)));
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
        return Lottie.network(widget.controller.source,
            controller: widget.controller.lottieController,
            onLoaded: (composition) {
              widget.controller.initializeLottieController(composition);
            },
            width: widget.controller.width?.toDouble(),
            height: widget.controller.height?.toDouble(),
            repeat: widget.controller.repeat,
            fit: fit,
            errorBuilder: (context, error, stacktrace) => placeholderImage());
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
