import 'package:dotlottie_flutter/dotlottie_flutter.dart';
import 'package:ensemble/action/haptic_action.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/box_wrapper.dart';
import 'package:ensemble/widget/lottie/dot_lottie_bytes_view.dart';
import 'package:ensemble/widget/lottie/ensemble_dot_lottie_controller.dart';
import 'package:ensemble/widget/lottie/lottie.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class LottieState extends EWidgetState<EnsembleLottie> {
  bool _loadError = false;
  // Updated after onLoad from dotlottie manifest (.lottie / URL). JSON uses w/h upfront.
  double? _aspectRatio;

  @override
  void dispose() {
    widget.controller.lottieController = null;
    super.dispose();
  }

  @override
  Widget buildWidget(BuildContext context) {
    BoxFit? fit = Utils.getBoxFit(widget.controller.fit);

    Widget rtn = BoxWrapper(
        widget: buildLottie(context, fit),
        boxController: widget.controller,
        ignoresMargin: true,
        // Width/height from YAML styles live on the controller; this child sets its own layout size.
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

  Widget buildLottie(BuildContext context, BoxFit? fit) {
    String source = widget.controller.source.trim();
    // Parent constraints (Column, Row, etc.) drive defaults when YAML width/height are omitted.
    return LayoutBuilder(
      builder: (context, constraints) {
        if (source.isEmpty) {
          return placeholderImage(context, constraints);
        }
        if (kIsWeb &&
            widget.controller.width == null &&
            widget.controller.height == null) {
          final layoutSize = _layoutSize(context, constraints, 1.0);
          print(
              'Lottie widget must have explicit width and height for html renderer in the browser (this includes the preview in the editor). You do not need to specify width or height for native apps or for canvaskit renderer. Defaulting to ${layoutSize.width} for width and ${layoutSize.height} for height');
        }
        return FutureBuilder(
          future: resolveDotLottieSource(source),
          builder: (context, snapshot) {
            if (_loadError) {
              return placeholderImage(context, constraints);
            }
            if (snapshot.hasError) {
              print('Failed to load Lottie animation from source: $source');

              return placeholderImage(context, constraints);
            }
            if (!snapshot.hasData) {
              return placeholderImage(context, constraints);
            }
            final resolved = snapshot.data!;
            final hasString = resolved.stringSource != null &&
                resolved.stringSource!.isNotEmpty;
            final hasBytes = resolved.byteSource != null;
            if (!hasString && !hasBytes) {
              return placeholderImage(context, constraints);
            }

            final aspectRatio = _aspectRatio ??
                (resolved.sourceType == 'json' && hasString
                    ? lottieAspectRatioFromJson(resolved.stringSource!)
                    : null) ??
                1.0;

            final layoutSize = _layoutSize(context, constraints, aspectRatio);
            return _lottieBox(
              constraints,
              layoutSize,
              aspectRatio,
              _dotLottiePlayer(
                context,
                resolved,
                fit,
                layoutSize,
                source,
              ),
            );
          },
        );
      },
    );
  }

  Widget _dotLottiePlayer(
    BuildContext context,
    ResolvedDotLottieSource resolved,
    BoxFit? fit,
    ({
      double? width,
      double? height,
      double? canvasWidth,
      double? canvasHeight,
    }) layoutSize,
    String yamlSource,
  ) {
    final callbacks = (
      onViewCreated: (EnsembleDotLottieController player) {
        widget.controller.lottieController = player;
      },
      onLoad: () => _onLottieLoad(resolved.sourceType),
      onPlay: () => widget.controller.fireOnPlay(context, widget),
      onComplete: () => widget.controller.fireOnComplete(context, widget),
      onStop: () => widget.controller.fireOnStop(context, widget),
      onLoadError: () {
        print('Failed to load Lottie animation from source: $yamlSource');
        if (mounted) setState(() => _loadError = true);
      },
    );

    final width = layoutSize.canvasWidth?.toInt();
    final height = layoutSize.canvasHeight?.toInt();
    final autoplay = widget.controller.autoPlay;
    final loop = widget.controller.repeat;

    // Native players accept sourceType 'data' + bytes and expose HTTP failures in Dart.
    if (!kIsWeb && resolved.byteSource != null) {
      return DotLottieBytesView(
        bytes: resolved.byteSource!,
        autoplay: autoplay,
        loop: loop,
        fit: fit,
        width: width,
        height: height,
        onViewCreated: callbacks.onViewCreated,
        onLoad: callbacks.onLoad,
        onPlay: callbacks.onPlay,
        onComplete: callbacks.onComplete,
        onStop: callbacks.onStop,
        onLoadError: callbacks.onLoadError,
      );
    }

    final sourceType =
        resolved.byteSource != null ? 'url' : resolved.sourceType;
    final source = resolved.byteSource != null
        ? dotLottieDataUrl(resolved.byteSource!)
        : resolved.stringSource!;

    return DotLottieView(
      sourceType: sourceType,
      source: source,
      autoplay: autoplay,
      loop: loop,
      fit: fit,
      width: width,
      height: height,
      onViewCreated: (controller) =>
          callbacks.onViewCreated(EnsembleDotLottieController.wrap(controller)),
      onLoad: callbacks.onLoad,
      onPlay: callbacks.onPlay,
      onComplete: callbacks.onComplete,
      onStop: callbacks.onStop,
      onLoadError: callbacks.onLoadError,
    );
  }

  Future<void> _onLottieLoad(String sourceType) async {
    // JSON aspect ratio is parsed before build; manifest is for .lottie and remote URL sources.
    if (_aspectRatio != null || sourceType == 'json') return;
    final manifest = await widget.controller.lottieController?.manifest();
    final ratio = _aspectRatioFromManifest(manifest);
    if (ratio != null && mounted) {
      setState(() => _aspectRatio = ratio);
    }
  }

  double? _aspectRatioFromManifest(Map<String, dynamic>? manifest) {
    if (manifest == null) return null;
    final animations = manifest['animations'];
    if (animations is! List || animations.isEmpty) return null;
    final first = animations.first;
    if (first is! Map) return null;
    final w = first['width'] ?? first['w'];
    final h = first['height'] ?? first['h'];
    if (w is num && h is num && h > 0) {
      return w / h;
    }
    return null;
  }

  /// Computes layout and canvas sizes from YAML styles + parent [constraints].
  ///
  /// - `width` / `height`: Flutter widget box (SizedBox / AspectRatio).
  /// - `canvasWidth` / `canvasHeight`: passed to [DotLottieView] for the native player surface.
  ///   When YAML height is omitted, canvas height is derived from width and [aspectRatio].
  ({
    double? width,
    double? height,
    double? canvasWidth,
    double? canvasHeight,
  }) _layoutSize(
    BuildContext context,
    BoxConstraints constraints,
    double aspectRatio,
  ) {
    final styleWidth = widget.controller.width?.toDouble();
    final styleHeight = widget.controller.height?.toDouble();

    if (kIsWeb) {
      // Web defaults when YAML styles omit dimensions (see warning print in buildLottie).
      final width = styleWidth ?? 250;
      final height = styleHeight ?? 250;
      return (
        width: width,
        height: height,
        canvasWidth: width,
        canvasHeight: height,
      );
    }

    double? width = styleWidth;
    final height = styleHeight;

    // YAML height only: derive width from the animation so the visual box, clip,
    // and rounded corners match the rendered content instead of the full parent.
    if (height != null && width == null) {
      final derivedWidth = height * aspectRatio;
      width =
          constraints.maxWidth.isFinite && derivedWidth > constraints.maxWidth
              ? constraints.maxWidth
              : derivedWidth;
    }

    // Use parent max width when both YAML dimensions are omitted (e.g. Column). Do
    // not use screen width when maxWidth is infinite (e.g. Row) — that caused overflow.
    if (height == null && width == null && constraints.maxWidth.isFinite) {
      width = constraints.maxWidth;
    }

    return (
      width: width,
      height: height,
      canvasWidth: width,
      canvasHeight: height ?? (width != null ? width / aspectRatio : null),
    );
  }

  /// Wraps [child] in a bounded Flutter box. DotLottieView is a platform view and cannot
  /// layout with unbounded constraints (unlike the old Lottie composition widget).
  Widget _lottieBox(
    BoxConstraints constraints,
    ({
      double? width,
      double? height,
      double? canvasWidth,
      double? canvasHeight,
    }) layoutSize,
    double aspectRatio,
    Widget child,
  ) {
    final width = layoutSize.width;
    final height = layoutSize.height;

    if (width != null && height != null) {
      return SizedBox(width: width, height: height, child: child);
    }

    if (height != null) {
      final boxWidth = width ?? height * aspectRatio;
      return SizedBox(width: boxWidth, height: height, child: child);
    }

    if (width != null) {
      // YAML height omitted: bounded parent height fills vertically; else AspectRatio.
      if (constraints.hasBoundedHeight) {
        return SizedBox(width: width, child: child);
      }
      return SizedBox(
        width: width,
        child: AspectRatio(aspectRatio: aspectRatio, child: child),
      );
    }

    if (constraints.maxWidth.isFinite) {
      final w = constraints.maxWidth;
      if (constraints.hasBoundedHeight) {
        return SizedBox(width: w, child: child);
      }
      return SizedBox(
        width: w,
        child: AspectRatio(aspectRatio: aspectRatio, child: child),
      );
    }

    // Both YAML dimensions omitted and parent width is unbounded (e.g. bare Row child).
    return SizedBox(
      width: 200,
      height: 200,
      child: child,
    );
  }

  Widget placeholderImage(BuildContext context, BoxConstraints constraints) {
    final layoutSize = _layoutSize(context, constraints, _aspectRatio ?? 1.0);
    return _lottieBox(
      constraints,
      layoutSize,
      _aspectRatio ?? 1.0,
      Image.asset(
        'assets/images/img_placeholder.png',
        package: 'ensemble',
      ),
    );
  }
}
