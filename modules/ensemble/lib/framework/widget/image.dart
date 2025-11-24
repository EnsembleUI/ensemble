import 'package:cached_network_image/cached_network_image.dart';
import 'package:ensemble/framework/assets_service.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/ColorFilter_Composite.dart';
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
  final ColorFilterComposite? colorFilter;

  final Widget Function(String)? errorBuilder;

  // applicable for network image only
  final Widget Function(BuildContext, String)? placeholderBuilder;

  // optional cache manager for network image
  final BaseCacheManager? networkCacheManager;

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;
    if (source.startsWith('https://') || source.startsWith('http://')) {
      imageWidget = FutureBuilder<AssetResolution>(
        future: AssetResolver.resolve(source),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return errorBuilder != null
                ? errorBuilder!(snapshot.error.toString())
                : const SizedBox.shrink();
          }
          if (!snapshot.hasData) {
            return placeholderBuilder != null
                ? placeholderBuilder!(context, source)
                : const SizedBox.shrink();
          }
          final resolved = snapshot.data!;
          if (resolved.isAsset) {
            return flutter.Image.asset(
              resolved.path,
              width: width,
              height: height,
              fit: fit,
              errorBuilder: errorBuilder != null
                  ? (context, error, stackTrace) =>
                      errorBuilder!(error.toString())
                  : null,
            );
          }
          return CachedNetworkImage(
            imageUrl: resolved.path,
            width: width,
            height: height,
            fit: fit,
            placeholder: placeholderBuilder,
            errorWidget: errorBuilder != null
                ? (context, url, error) => errorBuilder!(error.toString())
                : null,
            cacheManager: networkCacheManager,
          );
        },
      );
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
    if (colorFilter?.color != null) {
        imageWidget = ColorFiltered(
          colorFilter: colorFilter!.getColorFilter()!,
          child: imageWidget,
        );
    }
    return imageWidget;
  }
}
