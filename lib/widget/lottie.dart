
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/layout/layout_helper.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/widget_util.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

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
      'onTap': (funcDefinition) => _controller.onTap = Utils.getAction(funcDefinition, initiator: this),
    };
  }

}

class LottieController extends BoxController {
  String source = '';
  int? width;
  int? height;
  String? fit;
  EnsembleAction? onTap;
}

class LottieState extends WidgetState<EnsembleLottie> {

  @override
  Widget buildWidget(BuildContext context) {

    BoxFit? fit = WidgetUtils.getBoxFit(widget._controller.fit);

    Widget rtn = WidgetUtils.wrapInBox(buildLottie(fit), widget._controller);
    if (widget._controller.onTap != null) {
      rtn = GestureDetector(
        child: rtn,
        onTap: () => ScreenController().executeAction(context, widget._controller.onTap!)
      );
    }
    return rtn;
  }

  Widget buildLottie(BoxFit? fit) {
    String source = widget._controller.source.trim();
    if (source.isNotEmpty) {
      // if is URL
      if (source.startsWith('https://') || source.startsWith('http://')) {
        // image binding is tricky. When the URL has not been resolved
        // the image will throw exception. We have to use a permanent placeholder
        // until the binding engages
        return Lottie.network(
            widget._controller.source,
            width: widget._controller.width?.toDouble(),
            height: widget._controller.height?.toDouble(),
            fit: fit,
            errorBuilder: (context, error, stacktrace) => placeholderImage(),
        );
      }
      // else attempt local asset
      else {
        return Lottie.asset(
          'assets/images/${widget._controller.source}',
          width: widget._controller.width?.toDouble(),
          height: widget._controller.height?.toDouble(),
          fit: fit,
          errorBuilder: (context, error, stacktrace) => placeholderImage()
        );
      }
    }
    return placeholderImage();
  }

  Widget placeholderImage() {
    return SizedBox(
      width: widget._controller.width?.toDouble(),
      height: widget._controller.height?.toDouble(),
      child: Image.asset('assets/images/img_placeholder.png', package: 'ensemble')
    );
  }




}