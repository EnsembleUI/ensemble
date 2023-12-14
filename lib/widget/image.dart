import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:ensemble/action/haptic_action.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/widget/colored_box_placeholder.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_svg/svg.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:http/http.dart' as http;
import 'package:yaml/yaml.dart';

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
      'source': (value) =>
          _controller.source = Utils.getString(value, fallback: ''),
      'fit': (value) => _controller.fit = Utils.getBoxFit(value),
      'resizedWidth': (width) => _controller.resizedWidth =
          Utils.optionalInt(width, min: 0, max: 2000),
      'resizedHeight': (height) => _controller.resizedHeight =
          Utils.optionalInt(height, min: 0, max: 2000),
      'placeholderColor': (value) =>
          _controller.placeholderColor = Utils.getColor(value),
      'fallback': (widget) => _controller.fallback = widget,
      'onTap': (funcDefinition) => _controller.onTap =
          EnsembleAction.fromYaml(funcDefinition, initiator: this),
      'onTapHaptic': (value) =>
          _controller.onTapHaptic = Utils.optionalString(value)
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
}

class ImageState extends WidgetState<EnsembleImage> {
  @override
  Widget buildWidget(BuildContext context) {
    Widget image;
    // Memory Image
    if (widget._controller.source is YamlList) {
      final List<int> data = Utils.getList(widget._controller.source) ?? [];
      final imageBytes = Uint8List.fromList(data);
      image = buildMemoryImage(imageBytes);
    } else {
      String source =
          Utils.getString(widget._controller.source.trim(), fallback: '');
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
    final mimeType = lookupMimeType(widget._controller.source);
    return mimeType?.contains('svg') == true;
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
