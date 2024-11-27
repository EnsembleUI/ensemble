import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:ensemble/action/haptic_action.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/widget/colored_box_placeholder.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/box_wrapper.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_svg/svg.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:http/http.dart' as http;

class EnsembleImage extends StatefulWidget
    with Invokable, HasController<ImageController, ImageState> {
  static const type = 'Image';

  EnsembleImage({Key? key}) : super(key: key);

  final ImageController _controller = ImageController();

  @override
  get controller => _controller;

  @override
  State<StatefulWidget> createState() => ImageState();

  @override
  Map<String, Function> getters() {
    return {
      'source': () => _controller.source,
      'fit': () => _controller.fit,
      'resizedWidth': () => _controller.resizedWidth,
      'resizedHeight': () => _controller.resizedHeight,
      'placeholderColor': () => _controller.placeholderColor,
    };
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {
      'cache': (value) =>
          _controller.cache = Utils.getBool(value, fallback: true),
      'source': (value) => _controller.source = value,
      'fit': (value) => _controller.fit = Utils.getBoxFit(value),
      'resizedWidth': (width) => _controller.resizedWidth =
          Utils.optionalInt(width, min: 0, max: 2000),
      'resizedHeight': (height) => _controller.resizedHeight =
          Utils.optionalInt(height, min: 0, max: 2000),
      'placeholderColor': (value) =>
          _controller.placeholderColor = Utils.getColor(value),
      'fallback': (widget) => _controller.fallback = widget,
      'onTap': (funcDefinition) => _controller.onTap =
          EnsembleAction.from(funcDefinition, initiator: this),
      'onTapHaptic': (value) =>
          _controller.onTapHaptic = Utils.optionalString(value),
      'pinchToZoom': (value) =>
          _controller.pinchToZoom = Utils.optionalBool(value),
    };
  }
}

class ImageController extends BoxController {
  ImageController() {
    /// Image's Box need to apply an additional ClipRRect or
    /// the image will bleed through the borderRadius
    clipContent = true;
  }

  DateTime? lastModifiedCache;
  dynamic source;
  BoxFit? fit;
  Color? placeholderColor;
  EnsembleAction? onTap;
  String? onTapHaptic;

  // whether we should resize the image to this. Note that we should set either
  // resizedWidth or resizedHeight but not both so the aspect ratio is maintained
  int? resizedWidth;
  int? resizedHeight;
  dynamic fallback;
  bool cache = true;
  bool? pinchToZoom;
}

class ImageState extends EWidgetState<EnsembleImage> {
  @override
  Widget buildWidget(BuildContext context) {
    Widget image;
    // Memory Image
    if (widget._controller.source is List<dynamic>) {
      final imageBytes = Uint8List.fromList(widget._controller.source);
      image = buildMemoryImage(imageBytes);
    } else {
      String source =
          Utils.getString(widget._controller.source?.trim(), fallback: '');
      // use the placeholder for the initial state before binding kicks in
      if (source.isEmpty) {
        return const ColoredBoxPlaceholder();
      }

      if (isSvg()) {
        image = buildSvgImage(source, widget._controller.fit);
      } else {
        image = buildNonSvgImage(source, widget._controller.fit);
      }
    }

    Widget rtn = BoxWrapper(
      widget: image,
      boxController: widget._controller,
      ignoresMargin: true, // make sure the gesture don't include the margin
      ignoresDimension: true, // we apply width/height in the image already
    );
    if (widget._controller.onTap != null) {
      rtn = GestureDetector(
        child: rtn,
        onTap: () {
          if (widget._controller.onTapHaptic != null) {
            ScreenController().executeAction(
              context,
              HapticAction(
                type: widget._controller.onTapHaptic!,
                onComplete: null,
              ),
            );
          }

          ScreenController().executeAction(context, widget._controller.onTap!,
              event: EnsembleEvent(widget));
        },
      );
    }
    if (widget._controller.margin != null) {
      rtn = Padding(padding: widget._controller.margin!, child: rtn);
    }
    if (widget._controller.pinchToZoom == true) {
      rtn = PinchToZoom(child: rtn);
    }
    return rtn;
  }

  Future<String> fetch(String url) async {
    String str = (widget.controller.source.contains("?")) ? "&" : "?";
    final http.Response response = await http
        .get(Uri.parse("$url${str}timeStamp=${DateTime.now().toString()}"));
    DateTime lastModifiedDateTime =
        parseHttpDate("${response.headers['last-modified']}");
    if (widget._controller.lastModifiedCache == null ||
        lastModifiedDateTime.compareTo(widget._controller.lastModifiedCache!) ==
            1) {
      widget._controller.lastModifiedCache = lastModifiedDateTime;
      await EnsembleImageCacheManager.instance.emptyCache();
    }
    return "${widget.controller.source}${str}timeStamp=$lastModifiedDateTime";
  }

  Widget buildMemoryImage(Uint8List source) {
    if (isSvg()) {
      return SvgPicture.memory(
        source,
        width: widget._controller.width?.toDouble(),
        height: widget._controller.height?.toDouble(),
        fit: widget._controller.fit ?? BoxFit.contain,
      );
    }
    return Image.memory(
      source,
      width: widget._controller.width?.toDouble(),
      height: widget._controller.height?.toDouble(),
      fit: widget._controller.fit,
      errorBuilder: (context, error, stacktrace) => errorFallback(),
    );
  }

  Widget buildNonSvgImage(String source, BoxFit? fit) {
    if (source.startsWith('https://') || source.startsWith('http://')) {
      int? cachedWidth = widget._controller.resizedWidth;
      int? cachedHeight = widget._controller.resizedHeight;

      // if user doesn't override the cache dimension, we resize all images
      // to a reasonable 800 width so loading lots of gigantic images won't crash.
      // TODO: figure out the actual dimension once so we can do min(actualWidth, 800)
      if (cachedWidth == null && cachedHeight == null) {
        cachedWidth = 800;
      }

      Widget cacheImage(String url) {
        return CachedNetworkImage(
          imageUrl: url,
          width: widget._controller.width?.toDouble(),
          height: widget._controller.height?.toDouble(),
          fit: fit,
          // we auto resize and cap these values so loading lots of
          // gigantic images won't run out of memory
          memCacheWidth: cachedWidth,
          memCacheHeight: cachedHeight,
          cacheManager: EnsembleImageCacheManager.instance,
          errorWidget: (context, error, stacktrace) => errorFallback(),
          placeholder: (context, url) => ColoredBoxPlaceholder(
            color: widget._controller.placeholderColor,
            width: widget._controller.width?.toDouble(),
            height: widget._controller.height?.toDouble(),
          ),
        );
      }

      return (!widget.controller.cache)
          ? FutureBuilder(
              future: fetch(widget.controller.source),
              initialData: widget._controller.source,
              builder: (context, AsyncSnapshot snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  if (snapshot.hasData) {
                    return cacheImage(snapshot.data!);
                  } else {
                    return cacheImage(widget.controller.source);
                  }
                } else {
                  return ColoredBoxPlaceholder(
                    color: widget._controller.placeholderColor,
                    width: widget._controller.width?.toDouble(),
                    height: widget._controller.height?.toDouble(),
                  );
                }
              })
          : cacheImage(widget._controller.source);
    } else if (Utils.isMemoryPath(widget._controller.source)) {
      return kIsWeb
          ? Image.network(widget._controller.source,
              width: widget._controller.width?.toDouble(),
              height: widget._controller.height?.toDouble(),
              fit: fit,
              errorBuilder: (context, error, stacktrace) => errorFallback())
          : Image.file(File(widget._controller.source),
              width: widget._controller.width?.toDouble(),
              height: widget._controller.height?.toDouble(),
              fit: fit,
              errorBuilder: (context, error, stacktrace) => errorFallback());
    } else {
      // user might use env variables to switch between remote and local images.
      // Assets might have additional token e.g. my-image.png?x=2343
      // so we need to strip them out
      return Image.asset(Utils.getLocalAssetFullPath(widget._controller.source),
          width: widget._controller.width?.toDouble(),
          height: widget._controller.height?.toDouble(),
          fit: fit,
          errorBuilder: (context, error, stacktrace) => errorFallback());
    }
  }

  Widget buildSvgImage(String source, BoxFit? fit) {
    // If the source starts with '<svg', treat it as inline SVG content
    if (source.trim().toLowerCase().startsWith('<svg')) {
      return SvgPicture.string(
        source,
        width: widget._controller.width?.toDouble(),
        height: widget._controller.height?.toDouble(),
        fit: fit ?? BoxFit.contain,
      );
    }
    
    // if is URL
    if (source.startsWith('https://') || source.startsWith('http://')) {
      return SvgPicture.network(
        widget._controller.source,
        width: widget._controller.width?.toDouble(),
        height: widget._controller.height?.toDouble(),
        fit: fit ?? BoxFit.contain,
        placeholderBuilder: (_) => ColoredBoxPlaceholder(
          color: widget._controller.placeholderColor,
          width: widget._controller.width?.toDouble(),
          height: widget._controller.height?.toDouble(),
        ),
      );
    }
    // attempt local assets
    return SvgPicture.asset(
        Utils.getLocalAssetFullPath(widget._controller.source),
        width: widget._controller.width?.toDouble(),
        height: widget._controller.height?.toDouble(),
        fit: fit ?? BoxFit.contain);
  }

  bool isSvg() {
    // Bytes Image
    if (widget._controller.source is List<dynamic>) {
      final Uint8List imageBytes =
          Uint8List.fromList(widget._controller.source);

      return imageBytes.length >= 5 &&
          imageBytes[0] == 0x3C &&
          imageBytes[1] == 0x3F &&
          imageBytes[2] == 0x78 &&
          imageBytes[3] == 0x6D &&
          imageBytes[4] == 0x6C;
    } else if (widget._controller.source is String) {
      // Check for inline SVG content
      if (widget._controller.source.trim().toLowerCase().startsWith('<svg')) {
        return true;
      }
      // cheap check for extension
      Uri uri;
      try {
        uri = Uri.parse(widget._controller.source);
        if (uri.path.toLowerCase().endsWith("svg")) {
          return true;
        }
      } catch (e) {
        // ignore
      }

      // String path image
      final mimeType = lookupMimeType(widget._controller.source);
      return mimeType?.contains('svg') == true;
    }
    return false;
  }

  /// display if the image cannot be loaded
  Widget errorFallback() {
    Widget fallbackWidget;
    if (scopeManager != null && widget._controller.fallback != null) {
      fallbackWidget =
          scopeManager!.buildWidgetFromDefinition(widget._controller.fallback);
    } else {
      fallbackWidget = Image.asset('assets/images/img_placeholder.png',
          package: 'ensemble', fit: BoxFit.cover);
    }

    // image dimensions (if specified) don't apply to the fallback widget,
    // so we wrap it inside a SizeBox and center for better UX
    if (widget._controller.width != null || widget._controller.height != null) {
      fallbackWidget = SizedBox(
          width: widget._controller.width?.toDouble(),
          height: widget._controller.height?.toDouble(),
          child: Center(child: fallbackWidget));
    }
    return fallbackWidget;
  }
}

class EnsembleImageCacheManager {
  static const key = 'ensembleImageCacheKey';
  static CacheManager instance = CacheManager(Config(
    key,
    stalePeriod: const Duration(minutes: 15),
    maxNrOfCacheObjects: 50,
  ));
}

class PinchToZoom extends StatefulWidget {
  static const Duration defaultResetDuration = Duration(milliseconds: 200);

  const PinchToZoom({
    required this.child,
    this.resetDuration = defaultResetDuration,
    this.resetCurve = Curves.ease,
    this.boundaryMargin = EdgeInsets.zero,
    this.clipBehavior = Clip.none,
    this.minScale = 0.8,
    this.maxScale = 8,
    this.useOverlay = true,
    this.maxOverlayOpacity = 0.5,
    this.overlayColor = Colors.black,
    super.key,
  })  : assert(minScale > 0),
        assert(maxScale > 0),
        assert(maxScale >= minScale);

  final Widget child;
  final Clip clipBehavior;
  final double maxScale;
  final double minScale;
  final Duration resetDuration;
  final Curve resetCurve;
  final EdgeInsets boundaryMargin;
  final bool useOverlay;
  final double maxOverlayOpacity;
  final Color overlayColor;

  @override
  State<PinchToZoom> createState() => _PinchToZoomState();
}

class _PinchToZoomState extends State<PinchToZoom>
    with TickerProviderStateMixin {
  late TransformationController controller;
  late AnimationController animationController;
  Animation<Matrix4>? animation;
  OverlayEntry? entry;
  List<OverlayEntry> overlayEntries = [];
  double scale = 1;
  static const fingersRequiredToPinch = 2;

  @override
  void initState() {
    super.initState();

    controller = TransformationController();
    animationController = AnimationController(
      vsync: this,
      duration: widget.resetDuration,
    )
      ..addListener(
        () => controller.value = animation!.value,
      )
      ..addStatusListener(
        (status) {
          if (status == AnimationStatus.completed && widget.useOverlay) {
            Future.delayed(const Duration(milliseconds: 100), removeOverlay);
          }
        },
      );
  }

  @override
  void dispose() {
    controller.dispose();
    animationController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) => buildWidget(widget.child);

  void resetAnimation() {
    if (mounted) {
      animation = Matrix4Tween(begin: controller.value, end: Matrix4.identity())
          .animate(CurvedAnimation(
              parent: animationController, curve: widget.resetCurve));
      animationController.forward(from: 0);
    }
  }

  Widget buildWidget(Widget zoomableWidget) {
    return InteractiveViewer(
      clipBehavior: widget.clipBehavior,
      minScale: widget.minScale,
      maxScale: widget.maxScale,
      transformationController: controller,
      onInteractionStart: (details) {
        if (fingersRequiredToPinch > 0 &&
            details.pointerCount != fingersRequiredToPinch) {
          return;
        }
        if (widget.useOverlay) {
          showOverlay(context);
        }
      },
      onInteractionEnd: (details) {
        if (overlayEntries.isEmpty) {
          return;
        }
        resetAnimation();
      },
      onInteractionUpdate: (details) {
        if (entry == null) {
          return;
        }
        scale = details.scale;
        entry?.markNeedsBuild();
      },
      panEnabled: false,
      boundaryMargin: widget.boundaryMargin,
      child: zoomableWidget,
    );
  }

  void showOverlay(BuildContext context) {
    final OverlayState overlay = Overlay.of(context);
    final RenderBox renderBox = context.findRenderObject()! as RenderBox;
    final Offset offset = renderBox.localToGlobal(Offset.zero);

    entry = OverlayEntry(builder: (context) {
      final double opacity = ((scale - 1) / (widget.maxScale - 1))
          .clamp(0, widget.maxOverlayOpacity);

      return Material(
        color: Colors.green.withOpacity(0),
        child: Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: opacity,
                child: Container(color: widget.overlayColor),
              ),
            ),
            Positioned(
              left: offset.dx,
              top: offset.dy,
              child: SizedBox(
                width: renderBox.size.width,
                height: renderBox.size.height,
                child: buildWidget(widget.child),
              ),
            ),
          ],
        ),
      );
    });
    overlay.insert(entry!);
    overlayEntries.add(entry!);
  }

  void removeOverlay() {
    for (final OverlayEntry entry in overlayEntries) {
      entry.remove();
    }
    overlayEntries.clear();
    entry = null;
  }
}
