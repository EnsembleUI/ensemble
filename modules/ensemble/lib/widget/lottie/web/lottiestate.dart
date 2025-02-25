import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui_web' as ui;
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/box_wrapper.dart';
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

class LottieState extends EWidgetState<EnsembleLottie>
    with SingleTickerProviderStateMixin, LottieAction {
  String id = 'lottie_${Random().nextInt(900000) + 100000}';
  final isCanvasKit = js.context['flutterCanvasKit'] != null;
  late String divId;
  int lastEventId = -1;
  @override
  void initState() {
    super.initState();
    divId = widget.controller.id ?? id;
    if (isCanvasKit) {
      widget.controller
        ..lottieController = AnimationController(vsync: this)
        ..addStatusListener(context, widget);
    }
  }

  // Binding LottieActions which are used specifically for html renderer as it is rendered using JS
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
  void dispose() {
    html.window.close(); // To prevent memory leaks
    widget.controller.lottieController?.dispose();
    super.dispose();
  }

  @override
  Widget buildWidget(BuildContext context) {
    BoxFit? fit = Utils.getBoxFit(widget.controller.fit);

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

  // Render this when the runtime is flutter web with html renderer
  Widget buildLottieHtml(BoxFit? fit) {
    String source = widget.controller.source.trim();
    double width = widget.controller.width?.toDouble() ?? 250;
    double height = widget.controller.height?.toDouble() ?? 250;
    bool repeat = widget.controller.repeat;
    bool autoPlay = widget.controller.autoPlay;
    if (widget.controller.width == null || widget.controller.height == null) {
      print(
          'Lottie widget must have explicit width and height for html renderer in the browser (this includes the preview in the editor). You do not need to specify width or height for native apps or for canvaskit renderer. Defaulting to $width for width and $height for height');
    }

    if (source.isNotEmpty) {
      // image binding is tricky. When the URL has not been resolved
      // the image will throw exception. We have to use a permanent placeholder
      // until the binding engages
      // HTML & JS code for the web html renderer
      final htmlString = '''
<html>
  <body>
    <!--Importing lottie-player-->
    <script src="https://unpkg.com/@lottiefiles/lottie-player@latest/dist/lottie-player.js"></script>
    <!--Rendering lottie-player-->
    <lottie-player id="$divId" ${autoPlay ? 'autoplay' : ''} ${repeat ? 'loop' : ''} mode="normal" style="width: ${width}px; height: ${height}px">
    </lottie-player>
    <!--Script to handle all the actions and callbacks for the animation-->
    <script type="text/javascript">
      let direction = 1; // Variable to define the direction ie to run animation forward or backward
      let player_$divId = document.getElementById("$divId");
      // A counter variable which increments upon each event and thus making each event unique and allowing to segregate from old events
      let counter = 0;
      player_$divId.load("$source");
      if ($autoPlay) player_$divId.play();
      window.parent.addEventListener("message", handleMessage, false); // Hooking the event listener
      
      // Function to handle all the messages that are received from dart to js
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
          window.parent.postMessage('{"data": "onStop", "id": ' + counter + ', "tag": "$divId"}', "*");
          counter++;
        }
        if (data == "reset_$divId") {
          player_$divId.stop();
        }
      }
      // Event Listener for specific actions for animation like onComplete, onStart, onLoad and so on
      player_$divId.addEventListener("play", () => {
        if (direction == 1) window.parent.postMessage('{"data": "onForward", "id": ' + counter + ', "tag": "$divId"}', "*");
        else window.parent.postMessage('{"data": "onReverse", "id": ' + counter + ', "tag": "$divId"}', "*");
        counter++;
      });
      player_$divId.addEventListener("complete", () => {
        window.parent.postMessage('{"data": "onComplete", "id": ' + counter + ', "tag": "$divId"}', "*");
        counter++;
      });
      player_$divId.addEventListener("pause", () => {
        window.parent.postMessage('{"data": "onStop", "id": ' + counter + ', "tag": "$divId"}', "*");
        counter++;
      });
      player_$divId.addEventListener("stop", () => {
        window.parent.postMessage('{"data": "onStop", "id": ' + counter + ', "tag": "$divId"}', "*");
        counter++;
      });
    </script>
  </body>
</html>
''';
      // Defining the constraints and layout for the iframe in flutter side
      final html.IFrameElement iFrame = html.IFrameElement()
        ..width = '$width'
        ..height = '$height'
        ..srcdoc = htmlString
        ..style.border = 'none'
        ..onLoad;
      // Event listener for the messages that are sent from JS to Dart
      html.window.onMessage.listen(
        (event) async {
          final String data = event.data;
          // Need to check if the data is in json format as there are also other events from JS
          if (data.contains('{')) {
            final json = jsonDecode(data);
            // Segregating the latest event from old events using then html tag and the id which is just a counter which increments by 1 for each event
            if (lastEventId != json['id'] && divId == json['tag']) {
              lastEventId = json['id'];
              // Mapping the events to their respective callbacks
              if (json['data'] == "onForward" &&
                  widget.controller.onForward != null) {
                ScreenController().executeAction(
                  context,
                  widget.controller.onForward!,
                  event: EnsembleEvent(widget),
                );
              }
              if (json['data'] == "onComplete" &&
                  widget.controller.onComplete != null) {
                ScreenController().executeAction(
                  context,
                  widget.controller.onComplete!,
                  event: EnsembleEvent(widget),
                );
              }
              if (json['data'] == "onStop" &&
                  widget.controller.onStop != null) {
                ScreenController().executeAction(
                  context,
                  widget.controller.onStop!,
                  event: EnsembleEvent(widget),
                );
              }
              if (json['data'] == "onReverse" &&
                  widget.controller.onReverse != null) {
                ScreenController().executeAction(
                  context,
                  widget.controller.onReverse!,
                  event: EnsembleEvent(widget),
                );
              }
            }
          }
        },
      );

      iFrame.style.pointerEvents = "none";

      // Registering the iframe in the flutter widget tree
      ui.platformViewRegistry.registerViewFactory(
        divId,
        (int viewId) => iFrame,
      );
      // 24 and 16 somehow are the minimum numbers to remove the slider. Without adding them, there would be scroll sliders even when the width of iframe is exactly same as that of widget.
      return SizedBox(
        width: width + 24,
        height: height + 16,
        child: AbsorbPointer(
          child: HtmlElementView(viewType: divId),
        ), // Rendering the iframe
      );
    }
    return blankPlaceholder();
  }

  // Render this when the runtime is flutter web with canvas-kit renderer
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
      // else attempt local asset
      final localSource = Utils.getLocalAssetFullPath(widget.controller.source);
      if (Utils.isUrl(localSource)) {
        return Lottie.network(
          localSource,
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
      return Lottie.asset(Utils.getLocalAssetFullPath(widget.controller.source),
          controller: widget.controller.lottieController,
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
