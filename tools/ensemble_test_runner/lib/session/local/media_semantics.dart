import 'package:ensemble/widget/image.dart';
import 'package:ensemble/widget/lottie/lottie.dart';
import 'package:flutter/widgets.dart';

/// Classifies visual media into the stable types exposed by the observer.
///
/// This stays independent from locator traversal so direct widget inspection
/// and subtree walks use exactly the same classification rules.
String? mediaWidgetType(Widget widget) {
  if (widget is EnsembleImage) {
    return _mediaTypeForSource(widget.controller.source, fallback: 'image');
  }
  if (widget is EnsembleLottie) return 'lottie';
  if (widget is Image || widget is RawImage) {
    return _mediaTypeForImageProvider(
      widget is Image ? widget.image : null,
      fallback: 'image',
    );
  }
  final base = widget.runtimeType.toString().split('<').first;
  switch (base) {
    case 'SvgPicture':
      return 'svg';
    case 'CachedNetworkImage':
    case 'FadeInImage':
      return 'image';
    case 'Lottie':
    case 'LottieBuilder':
      return 'lottie';
    default:
      return null;
  }
}

/// Returns the source basename suitable for an observation title.
String? mediaSourceLabel(Object? source) {
  if (source == null) return null;
  if (source is List) return 'memory';
  var raw = source.toString().trim();
  if (raw.isEmpty) return null;
  // ImageProvider debug strings — keep the report compact and stable.
  final assetMatch = RegExp(r'AssetImage\(name:\s*"([^"]+)"\)').firstMatch(raw);
  if (assetMatch != null) raw = assetMatch.group(1)!;
  final networkMatch = RegExp(r'NetworkImage\("([^"]+)"').firstMatch(raw);
  if (networkMatch != null) raw = networkMatch.group(1)!;
  final uri = Uri.tryParse(raw);
  final path = (uri != null && uri.path.isNotEmpty) ? uri.path : raw;
  final segments = path.split('/');
  final base = segments.isNotEmpty ? segments.last : path;
  final cleaned = base.split('?').first.trim();
  return cleaned.isEmpty ? null : cleaned;
}

/// Returns the source label for a media host, when one is available.
String? readMediaDescription(Element element) {
  final widget = element.widget;
  if (widget is EnsembleImage) {
    return mediaSourceLabel(widget.controller.source);
  }
  if (widget is EnsembleLottie) {
    return mediaSourceLabel(widget.controller.source);
  }
  if (widget is Image) {
    return mediaSourceLabel(widget.image);
  }
  return null;
}

String _mediaTypeForSource(Object? source, {required String fallback}) {
  final raw = source?.toString().trim().toLowerCase() ?? '';
  if (raw.endsWith('.svg') || raw.contains('.svg?')) return 'svg';
  if (raw.endsWith('.gif') ||
      raw.contains('.gif?') ||
      raw.contains('image/gif')) {
    return 'gif';
  }
  if (raw.endsWith('.json') ||
      raw.contains('.json?') ||
      raw.contains('lottie')) {
    return 'lottie';
  }
  return fallback;
}

String _mediaTypeForImageProvider(
  ImageProvider? provider, {
  required String fallback,
}) {
  if (provider == null) return fallback;
  final desc = provider.toString().toLowerCase();
  if (desc.contains('.gif') || desc.contains('image/gif')) return 'gif';
  if (desc.contains('.svg')) return 'svg';
  return fallback;
}
