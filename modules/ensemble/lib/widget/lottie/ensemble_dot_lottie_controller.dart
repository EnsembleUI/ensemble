import 'package:dotlottie_flutter/dotlottie_flutter.dart';
import 'package:flutter/services.dart';

/// Playback handle for dotlottie platform views (JSON/URL via [DotLottieView],
/// bundle `.lottie` bytes via [DotLottieBytesView]).
class EnsembleDotLottieController {
  EnsembleDotLottieController._(this._delegate, this._viewId);

  factory EnsembleDotLottieController.wrap(DotLottieViewController delegate) {
    return EnsembleDotLottieController._(delegate, null);
  }

  factory EnsembleDotLottieController.fromViewId(int viewId) {
    return EnsembleDotLottieController._(null, viewId);
  }

  final DotLottieViewController? _delegate;
  final int? _viewId;

  MethodChannel get _channel => MethodChannel('dotlottie_view_$_viewId');

  Future<bool?> play() async {
    final delegate = _delegate;
    if (delegate != null) return delegate.play();
    return _channel.invokeMethod<bool>('play');
  }

  Future<bool?> stop() async {
    final delegate = _delegate;
    if (delegate != null) return delegate.stop();
    return _channel.invokeMethod<bool>('stop');
  }

  Future<bool?> setProgress(double progress) async {
    final delegate = _delegate;
    if (delegate != null) return delegate.setProgress(progress);
    return _channel.invokeMethod<bool>('setProgress', {'progress': progress});
  }

  Future<void> setMode(String mode) async {
    final delegate = _delegate;
    if (delegate != null) {
      await delegate.setMode(mode);
      return;
    }
    await _channel.invokeMethod('setMode', {'mode': mode});
  }

  Future<void> setLoop(bool loop) async {
    final delegate = _delegate;
    if (delegate != null) {
      await delegate.setLoop(loop);
      return;
    }
    await _channel.invokeMethod('setLoop', {'loop': loop});
  }

  Future<Map<String, dynamic>?> manifest() async {
    final delegate = _delegate;
    if (delegate != null) return delegate.manifest();
    final result = await _channel.invokeMethod('manifest');
    if (result is Map) {
      return result.cast<String, dynamic>();
    }
    return null;
  }
}
