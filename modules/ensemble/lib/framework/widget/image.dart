import 'package:cached_network_image/cached_network_image.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/cupertino.dart' as flutter;
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// a basic Image that can loads from network or local asset
/// that can be used by other Ensemble widgets.
/// Note that only non-svg is supported. See EnsembleImage for
/// full-feature Image widget
class Image extends StatelessWidget {
  const Image(
      {super.key,
      required this.source,
      this.width,
      this.height,
      this.fit,
      this.errorBuilder,
      this.placeholderBuilder,
      this.colorFilter,
      this.networkCacheManager});

  final String source;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Color? colorFilter;

  final Widget Function(String)? errorBuilder;

  // applicable for network image only
  final Widget Function(BuildContext, String)? placeholderBuilder;

  // optional cache manager for network image
  final BaseCacheManager? networkCacheManager;

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;
    if (source.startsWith('https://') || source.startsWith('http://')) {
      // If the asset is available locally, then use local path
      String assetName = Utils.getAssetName(source);
      if (Utils.isAssetAvailableLocally(assetName)) {
        imageWidget = flutter.Image.asset(
          Utils.getLocalAssetFullPath(assetName),
          width: width,
          height: height,
          fit: fit,
          errorBuilder: errorBuilder != null
              ? (context, error, stackTrace) => errorBuilder!(error.toString())
              : null,
        );
      } else {
        imageWidget = CachedNetworkImage(
          imageUrl: source,
          width: width,
          height: height,
          fit: fit,

          // placeholder while the image is loading
          placeholder: placeholderBuilder,
          errorWidget: errorBuilder != null
              ? (context, url, error) => errorBuilder!(error.toString())
              : null,
          cacheManager: networkCacheManager,
        );
      }
    } else {
      imageWidget = flutter.Image.asset(
        Utils.getLocalAssetFullPath(source),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: errorBuilder != null
            ? (context, error, stackTrace) => errorBuilder!(error.toString())
            : null,
      );
    }
    if (colorFilter != null) {
      if (colorFilter == Colors.black) {
        imageWidget = ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            0.2126, 0.7152, 0.0722, 0, 0, // Red channel
            0.2126, 0.7152, 0.0722, 0, 0, // Green chan nel
            0.2126, 0.7152, 0.0722, 0, 0, // Blue channel
            0, 0, 0, 1, 0, // Alpha channel
          ]),
          child: imageWidget,
        );
      } else {
        imageWidget = ColorFiltered(
          colorFilter: ColorFilter.mode(
            colorFilter!,
            BlendMode.modulate,
          ),
          child: imageWidget,
        );
      }
    }
    return imageWidget;
  }
}
