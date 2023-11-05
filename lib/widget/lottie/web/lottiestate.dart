import 'dart:async';
import 'dart:math';
import 'dart:ui_web' as ui;

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
import 'package:http/http.dart';
import 'package:js_widget/js_widget.dart';
import 'dart:js' as js;
import 'dart:html' as html;

import 'package:lottie/lottie.dart';

class LottieState extends WidgetState<EnsembleLottie>
    with SingleTickerProviderStateMixin, LottieAction {
  String id = 'lottie_${Random().nextInt(900000) + 100000}';

  late String divId;

  @override
  void initState() {
    super.initState();

    divId = widget.controller.id ?? id;

    widget.controller
      ..lottieController = AnimationController(vsync: this)
      ..addStatusListener(context, widget);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    widget.controller.lottieAction = this;
  }

  @override
  void didUpdateWidget(covariant EnsembleLottie oldWidget) {
    super.didUpdateWidget(oldWidget);

    widget.controller.lottieAction = this;
  }

  @override
  void forward() => html.window.postMessage('forward_$divId', "*");

  @override
  void reset() => html.window.postMessage('reset_$divId', "*");

  @override
  void reverse() => html.window.postMessage('reverse_$divId', "*");

  @override
  void stop() => html.window.postMessage('stop_$divId', "*");

  @override
  Widget buildWidget(BuildContext context) {
    final isCanvasKit = js.context['flutterCanvasKit'] != null;

    BoxFit? fit = WidgetUtils.getBoxFit(widget.controller.fit);
    Widget rtn = BoxWrapper(
        widget: isCanvasKit ? buildLottieCanvas(fit) : buildLottieHtml(fit),
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

  Widget buildLottieHtml(BoxFit? fit) {
    String source = widget.controller.source.trim();
    double width = widget.controller.width?.toDouble() ?? 250;
    double height = widget.controller.height?.toDouble() ?? 250;
    bool repeat = widget.controller.repeat;
    bool autoPlay = widget.controller.autoPlay;

    if (widget.controller.width == null || widget.controller.height == null) {
      throw LanguageError(
          'Lottie widget must have explicit width and height for html renderer in the browser (this includes the preview in the editor). You do not need to specify width or height for native apps or for canvaskit renderer. Defaulting to $width for width and $height for height');
    }

    if (source.isNotEmpty) {
      // image binding is tricky. When the URL has not been resolved
      // the image will throw exception. We have to use a permanent placeholder
      // until the binding engages

      final htmlString = '''
<html>
  <body>
    <script src="https://unpkg.com/@lottiefiles/lottie-player@latest/dist/lottie-player.js"></script>

    <lottie-player id="$divId" ${autoPlay ? 'autoplay' : ''} ${repeat ? 'loop' : ''} mode="normal" style="width: ${width}px; height: ${height}px">
    </lottie-player>

    <script type="text/javascript">
      let direction = 1;
      let player_$divId = document.getElementById("$divId");

      function getEpochTime() {
        var d = new Date();

        return Math.round(d.getTime() / 1000);
      }

      player_$divId.load("$source");
      if ($autoPlay) player_$divId.play();

      window.parent.addEventListener("message", handleMessage, false);
      
      function handleMessage(e) {
        var data = e.data;

        if (data == "forward_$divId") {
          direction = 1;
          player_$divId.stop();
          player_$divId.setDirection(direction);
          player_$divId.play();
        }

        if (data == "reverse_$divId") {
          direction = -1;
          player_$divId.setDirection(direction);
          player_$divId.play();
        }

        if (data == "stop_$divId") {
          player_$divId.pause();
          // window.parent.postMessage("onStop_\${getEpochTime()}", "*");
        }

        if (data == "reset_$divId") {
          player_$divId.stop();
        }
      }

      player_$divId.addEventListener("play", () => {
        if (direction == 1) window.parent.postMessage("onForward_" + getEpochTime(), "*");
        else window.parent.postMessage("onReverse_\${getEpochTime()}", "*");
      });

      player_$divId.addEventListener("complete", () => {
        window.parent.postMessage("onComplete_\${getEpochTime()}", "*");
      });

      player_$divId.addEventListener("pause", () => {
        window.parent.postMessage("onStop_\${getEpochTime()}", "*");
      });
      player_$divId.addEventListener("stop", () => {
        window.parent.postMessage("onStop_\${getEpochTime()}", "*");
      });
    </script>
  </body>
</html>
''';

      final html.IFrameElement iFrame = html.IFrameElement()
        ..width = '$width'
        ..height = '$height'
        ..srcdoc = htmlString
        ..style.border = 'none'
        ..onLoad;

      html.window.onMessage.listen((event) {
        final String data = event.data;

        if (data == "onForward" && widget.controller.onForward != null) {
          ScreenController().executeAction(
            context,
            widget.controller.onForward!,
            event: EnsembleEvent(widget),
          );
        }

        if (data == "onComplete" && widget.controller.onComplete != null) {
          ScreenController().executeAction(
            context,
            widget.controller.onComplete!,
            event: EnsembleEvent(widget),
          );
        }

        if (data == "onStop" && widget.controller.onStop != null) {
          ScreenController().executeAction(
            context,
            widget.controller.onStop!,
            event: EnsembleEvent(widget),
          );
        }

        if (data == "onReverse" && widget.controller.onReverse != null) {
          ScreenController().executeAction(
            context,
            widget.controller.onReverse!,
            event: EnsembleEvent(widget),
          );
        }
      });

      ui.platformViewRegistry.registerViewFactory(
        divId,
        (int viewId) => iFrame,
      );

      // 24 and 16 somehow are the minimum numbers to remove the slider. Without adding them, there would be scroll sliders even when the width of iframe is exactly same as that of widget.
      return SizedBox(
        width: width + 24,
        height: height + 16,
        child: HtmlElementView(viewType: divId),
      );

//       return JsWidget(
//         id: _id,
//         createHtmlTag: () => tag,
//         data: source,
//         listener: (String msg) {
//           if (msg == "Clicked") {
//             if (widget.controller.onTap != null) {
//               ScreenController().executeAction(
//                   context, widget.controller.onTap!,
//                   event: EnsembleEvent(widget));
//             }
//           }

//           if (msg == "Completed") {
//             if (widget.controller.onComplete != null) {
//               ScreenController().executeAction(
//                 context,
//                 widget.controller.onComplete!,
//                 event: EnsembleEvent(widget),
//               );
//             }
//           }

//           if (msg == "Forwarded") {
//             if (widget.controller.onForward != null) {
//               ScreenController().executeAction(
//                 context,
//                 widget.controller.onForward!,
//                 event: EnsembleEvent(widget),
//               );
//             }
//           }
//         },
//         scriptToInstantiate: (String c) {
//           String script = '''
// var animData = {
//   container: document.getElementById("$id"),
//   renderer: "svg",
//   loop: $repeat,
//   autoplay: ${widget.controller.autoPlay},
//   path: "$c"
// };

// var anim = bodymovin.loadAnimation(animData);

// anim.addEventListener(
//   'complete',
//   () => { handleMessage("$_id","Completed"); }
// );
// anim.addEventListener(
//   'DOMLoaded',
//   (e) => { if (${widget.controller.autoPlay}) handleMessage("$_id","Forwarded"); }
// );
// ''';

//           if (widget.controller.onTap != null) {
//             script +=
//                 'document.getElementById("$_id").addEventListener("click",() => handleMessage("$_id","Clicked"));';
//           }
//           return script;
//         },
//         size: Size(width, height),
//       );
    }
    return blankPlaceholder();
  }

  Widget buildLottieCanvas(BoxFit? fit) {
    String source = widget.controller.source.trim();
    if (source.isNotEmpty) {
      // if is URL
      if (source.startsWith('https://') || source.startsWith('http://')) {
        // image binding is tricky. When the URL has not been resolved
        // the image will throw exception. We have to use a permanent placeholder
        // until the binding engages
        return Lottie.network(
          widget.controller.source,
          controller: widget.controller.lottieController!,
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
      // else attempt local asset

      return Lottie.asset(Utils.getLocalAssetFullPath(widget.controller.source),
          controller: widget.controller.lottieController!,
          onLoaded: (LottieComposition composition) {
            widget.controller.initializeLottieController(composition);
          },
          width: widget.controller.width?.toDouble(),
          height: widget.controller.height?.toDouble(),
          repeat: widget.controller.repeat,
          fit: fit,
          errorBuilder: (context, error, stacktrace) => placeholderImage());
    }
    return blankPlaceholder();
  }

  Widget placeholderImage() {
    return SizedBox(
        width: widget.controller.width?.toDouble(),
        height: widget.controller.height?.toDouble(),
        child: Image.asset('assets/images/img_placeholder.png',
            package: 'ensemble'));
  }

  Widget blankPlaceholder() => SizedBox(
        width: widget.controller.width?.toDouble(),
        height: widget.controller.height?.toDouble(),
      );
}
