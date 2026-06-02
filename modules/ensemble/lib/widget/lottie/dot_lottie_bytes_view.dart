import 'package:ensemble/widget/lottie/ensemble_dot_lottie_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// [DotLottieView] with `sourceType: 'asset'` converts `.lottie` bytes to
/// `sourceType: 'data'` before creating the platform view. Android's native
/// player does not accept `data:` URLs via `sourceType: 'url'` (iOS does).
///
/// This widget passes bundle-loaded bytes the same way the package does for assets.
class DotLottieBytesView extends StatefulWidget {
  final Uint8List bytes;
  final bool? autoplay;
  final bool? loop;
  final BoxFit? fit;
  final int? width;
  final int? height;
  final Function(EnsembleDotLottieController)? onViewCreated;
  final VoidCallback? onComplete;
  final VoidCallback? onLoad;
  final VoidCallback? onLoadError;
  final VoidCallback? onPlay;
  final VoidCallback? onStop;

  const DotLottieBytesView({
    super.key,
    required this.bytes,
    this.autoplay,
    this.loop,
    this.fit,
    this.width,
    this.height,
    this.onViewCreated,
    this.onComplete,
    this.onLoad,
    this.onLoadError,
    this.onPlay,
    this.onStop,
  });

  @override
  State<DotLottieBytesView> createState() => _DotLottieBytesViewState();
}

class _DotLottieBytesViewState extends State<DotLottieBytesView> {
  MethodChannel? _methodChannel;
  int _platformViewGeneration = 0;

  @override
  void didUpdateWidget(DotLottieBytesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.bytes, widget.bytes)) {
      setState(() => _platformViewGeneration++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final params = _creationParams();
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidView(
        key: ValueKey(_platformViewGeneration),
        viewType: 'dotlottie_view',
        creationParams: params,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
        gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return UiKitView(
        key: ValueKey(_platformViewGeneration),
        viewType: 'dotlottie_view',
        creationParams: params,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
        gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
      );
    }
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      return AppKitView(
        key: ValueKey(_platformViewGeneration),
        viewType: 'dotlottie_view',
        creationParams: params,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
        gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
      );
    }
    return const SizedBox.shrink();
  }

  Map<String, dynamic> _creationParams() {
    return {
      'autoplay': widget.autoplay,
      'loop': widget.loop,
      'speed': 1.0,
      'mode': 'forward',
      'useFrameInterpolation': false,
      if (widget.fit != null) 'fit': _boxFitToString(widget.fit),
      if (widget.width != null) 'width': widget.width,
      if (widget.height != null) 'height': widget.height,
      'sourceType': 'data',
      'source': widget.bytes,
    };
  }

  static String? _boxFitToString(BoxFit? fit) {
    switch (fit) {
      case BoxFit.contain:
        return 'contain';
      case BoxFit.cover:
        return 'cover';
      case BoxFit.fill:
        return 'fill';
      case BoxFit.fitWidth:
        return 'fitWidth';
      case BoxFit.fitHeight:
        return 'fitHeight';
      case BoxFit.none:
        return 'none';
      case BoxFit.scaleDown:
        return 'contain';
      case null:
        return null;
    }
  }

  void _onPlatformViewCreated(int viewId) {
    _methodChannel?.setMethodCallHandler(null);

    _methodChannel = MethodChannel('dotlottie_view_$viewId');
    _methodChannel!.setMethodCallHandler(_handleMethodCall);
    widget.onViewCreated?.call(EnsembleDotLottieController.fromViewId(viewId));
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (!mounted) return;
    switch (call.method) {
      case 'onComplete':
        widget.onComplete?.call();
      case 'onLoad':
        widget.onLoad?.call();
      case 'onLoadError':
        widget.onLoadError?.call();
      case 'onPlay':
        widget.onPlay?.call();
      case 'onStop':
        widget.onStop?.call();
    }
  }

  @override
  void dispose() {
    _methodChannel?.setMethodCallHandler(null);
    super.dispose();
  }
}
