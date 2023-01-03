import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/lottie/lottie.dart';
import 'package:ensemble/widget/widget_util.dart';
import 'package:flutter/widgets.dart';
import 'package:lottie/lottie.dart';

class LottieState extends WidgetState<EnsembleLottie> {

  @override
  Widget buildWidget(BuildContext context) {

    BoxFit? fit = WidgetUtils.getBoxFit(widget.controller.fit);

    Widget rtn = WidgetUtils.wrapInBox(buildLottie(fit), widget.controller);
    if (widget.controller.onTap != null) {
      rtn = GestureDetector(
          child: rtn,
          onTap: () => ScreenController().executeAction(context, widget.controller.onTap!)
      );
    }
    return rtn;
  }

  Widget buildLottie(BoxFit? fit) {
    String source = widget.controller.source.trim();
    if (source.isNotEmpty) {
      // if is URL
      if (source.startsWith('https://') || source.startsWith('http://')) {
        return Lottie.network(
          widget.controller.source,
          width: widget.controller.width?.toDouble(),
          height: widget.controller.height?.toDouble(),
          repeat: widget.controller.repeat ?? true,
          fit: fit,
          errorBuilder: (context, error, stacktrace) => placeholderImage(),
        );
      }
      // else attempt local asset
      else {
        return Lottie.asset(
            Utils.getLocalAssetFullPath(widget.controller.source),
            width: widget.controller.width?.toDouble(),
            height: widget.controller.height?.toDouble(),
            repeat: widget.controller.repeat ?? true,
            fit: fit,
            errorBuilder: (context, error, stacktrace) => placeholderImage()
        );
      }
    }
    return placeholderImage();
  }

  Widget placeholderImage() {
    return SizedBox(
        width: widget.controller.width?.toDouble(),
        height: widget.controller.height?.toDouble(),
        child: Image.asset('assets/images/img_placeholder.png', package: 'ensemble')
    );
  }




}