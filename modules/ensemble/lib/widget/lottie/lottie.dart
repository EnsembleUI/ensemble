import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/lottie/ensemble_dot_lottie_controller.dart';
import 'package:ensemble/widget/lottie/lottiestate.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class EnsembleLottie extends StatefulWidget
    with Invokable, HasController<LottieController, LottieState> {
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
    return {
      // Method to start animation in forward direction
      'forward': () => _controller.playForward(),
      // Method to run animation in reverse direction
      'reverse': () => _controller.playReverse(),
      // Method to reset animation to initial position
      'reset': () => _controller.resetAnimation(),
      // Method to stop animation at current position
      'stop': () => _controller.stopAnimation(),
    };
  }

  @override
  Map<String, Function> setters() {
    return {
      'source': (value) =>
          _controller.source = Utils.getString(value, fallback: ''),
      'fit': (value) => _controller.fit = Utils.optionalString(value),
      'repeat': (value) => _controller.repeat = Utils.getBool(
            value,
            fallback: true,
          ),
      'onTap': (funcDefinition) => _controller.onTap =
          EnsembleAction.from(funcDefinition, initiator: this),
      'onTapHaptic': (value) =>
          _controller.onTapHaptic = Utils.optionalString(value),
      // It defines whether animation would start at the time of rendering or not
      'autoPlay': (value) => _controller.autoPlay = Utils.getBool(
            value,
            fallback: true,
          ),
      // Callback method for onForward
      'onForward': (definition) => _controller.onForward =
          EnsembleAction.from(definition, initiator: this),
      // Callback method for onReverse
      'onReverse': (definition) => _controller.onReverse =
          EnsembleAction.from(definition, initiator: this),
      // Callback method for onComplete
      'onComplete': (definition) => _controller.onComplete =
          EnsembleAction.from(definition, initiator: this),
      // Callback method for onStop
      'onStop': (definition) =>
          _controller.onStop = EnsembleAction.from(definition, initiator: this),
    };
  }
}

mixin LottieAction on EWidgetState<EnsembleLottie> {
  void forward();
  void reverse();
  void reset();
  void stop();
}

class LottieController extends BoxController {
  LottieController() {
    clipContent = true;
  }

  String source = '';
  String? fit;
  EnsembleAction? onTap;
  String? onTapHaptic;
  bool repeat = true;
  bool autoPlay = true;

  // Drives playback after the dotlottie platform view is created.
  EnsembleDotLottieController? lottieController;
  LottieAction? lottieAction;
  // Tracks play direction so [fireOnPlay] can invoke onForward vs onReverse.
  bool _playbackReverse = false;

  EnsembleAction? onForward;
  EnsembleAction? onReverse;
  EnsembleAction? onComplete;
  EnsembleAction? onStop;

  void playForward() {
    final player = lottieController;
    if (player == null) return;
    _playbackReverse = false;
    player.setMode('forward');
    player.setLoop(repeat);
    player.play();
  }

  void playReverse() {
    final player = lottieController;
    if (player == null) return;
    _playbackReverse = true;
    player.setMode('reverse');
    player.setLoop(repeat);
    player.play();
  }

  void resetAnimation() {
    final player = lottieController;
    if (player == null) return;
    player.stop();
    player.setProgress(0);
  }

  void stopAnimation() => lottieController?.stop();

  // Wired from DotLottieView onPlay / onComplete / onStop (replaces AnimationController status listeners).
  void fireOnPlay(BuildContext context, EnsembleLottie widget) {
    final action = _playbackReverse ? onReverse : onForward;
    if (action == null) return;
    ScreenController().executeAction(
      context,
      action,
      event: EnsembleEvent(widget),
    );
  }

  void fireOnComplete(BuildContext context, EnsembleLottie widget) {
    if (onComplete == null) return;
    ScreenController().executeAction(
      context,
      onComplete!,
      event: EnsembleEvent(widget),
    );
  }

  void fireOnStop(BuildContext context, EnsembleLottie widget) {
    if (onStop == null) return;
    ScreenController().executeAction(
      context,
      onStop!,
      event: EnsembleEvent(widget),
    );
  }
}

/// Resolved source for [DotLottieView] / [DotLottieBytesView].
///
/// - JSON / URL → [stringSource] with matching [sourceType].
/// - `.lottie` bundle / non-web remote URL → [byteSource] for the native player.
typedef ResolvedDotLottieSource = ({
  String sourceType,
  String? stringSource,
  Uint8List? byteSource,
});

/// Base64 data URL for platforms that load `.lottie` via `sourceType: 'url'`.
String dotLottieDataUrl(Uint8List bytes) =>
    'data:application/octet-stream;base64,${base64Encode(bytes)}';

/// Resolves YAML [raw] source to [DotLottieView] `sourceType` + payload.
///
/// Local paths come from [Utils.getLocalAssetFullPath] (pubspec keys like
/// `ensemble/apps/.../assets/foo.json`). We load via [rootBundle] because
/// DotLottieView's built-in `asset` mode expects `assets/<path>`, which does
/// not match Ensemble's asset layout.
Future<ResolvedDotLottieSource> resolveDotLottieSource(
  String raw,
) async {
  final source = raw.trim();
  if (source.isEmpty) {
    return (sourceType: '', stringSource: '', byteSource: null);
  }

  if (source.startsWith('https://') || source.startsWith('http://')) {
    final assetName = Utils.getAssetName(source);
    if (Utils.isAssetAvailableLocally(assetName)) {
      return _loadDotLottieBundle(Utils.getLocalAssetFullPath(assetName));
    }
    if (!kIsWeb && _isDotLottieSource(source)) {
      return _loadRemoteDotLottie(source);
    }
    if (_needsInlineJsonUrl(source)) {
      return _loadRemoteLottieJson(source);
    }
    return (sourceType: 'url', stringSource: source, byteSource: null);
  }

  return _loadDotLottieBundle(Utils.getLocalAssetFullPath(source));
}

/// Reads a bundle asset and returns a form dotlottie accepts.
/// `.json` → inline JSON string; `.lottie` → raw bytes for the native player.
Future<ResolvedDotLottieSource> _loadDotLottieBundle(
  String bundleKey,
) async {
  final data = await rootBundle.load(bundleKey);
  final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  if (bundleKey.toLowerCase().endsWith('.json')) {
    return (
      sourceType: 'json',
      stringSource: utf8.decode(bytes),
      byteSource: null,
    );
  }
  return (
    sourceType: 'data',
    stringSource: null,
    byteSource: bytes,
  );
}

Future<ResolvedDotLottieSource> _loadRemoteDotLottie(String source) async {
  final response = await http.get(Uri.parse(source));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception(
      'Failed to load dotLottie source ($source): ${response.statusCode}',
    );
  }
  return (
    sourceType: 'data',
    stringSource: null,
    byteSource: response.bodyBytes,
  );
}

Future<ResolvedDotLottieSource> _loadRemoteLottieJson(String source) async {
  final response = await http.get(Uri.parse(source));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception(
      'Failed to load Lottie JSON source ($source): ${response.statusCode}',
    );
  }
  return (
    sourceType: 'json',
    stringSource: utf8.decode(response.bodyBytes),
    byteSource: null,
  );
}

bool _isDotLottieSource(String source) {
  final uri = Uri.tryParse(source);
  return (uri?.path ?? source).toLowerCase().endsWith('.lottie');
}

bool _isJsonSource(String source) {
  final uri = Uri.tryParse(source);
  return (uri?.path ?? source).toLowerCase().endsWith('.json');
}

bool _needsInlineJsonUrl(String source) {
  return !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) &&
      _isJsonSource(source);
}

/// Animation aspect ratio (width / height) from top-level Lottie JSON `w` and `h`.
double? lottieAspectRatioFromJson(String jsonSource) {
  try {
    final map = jsonDecode(jsonSource);
    final w = map['w'];
    final h = map['h'];
    if (w is num && h is num && h > 0) {
      return w / h;
    }
  } catch (_) {}
  return null;
}
