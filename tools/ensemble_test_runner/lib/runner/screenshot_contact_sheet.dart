import 'dart:io';
import 'dart:math' as math;

import 'package:ensemble_test_runner/actions/extended_step_handlers.dart';
import 'package:ensemble_test_runner/actions/screenshot_device.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/test_runtime_state.dart';
import 'package:image/image.dart' as img;

Future<String?> writeScreenshotContactSheet({
  required String testId,
  required ScreenshotConfig config,
  required List<ScreenshotSheetFrame> frames,
}) async {
  if (frames.isEmpty) return null;

  final tiles = <img.Image>[];
  final device = resolveScreenshotDevice(config.toScreenshotArgs());
  try {
    for (final frame in frames) {
      final pngBytes = await ExtendedStepHandlers.encodeScreenshotImage(
        frame.image,
        device,
      );
      final source = img.decodePng(pngBytes);
      if (source == null) continue;
      tiles.add(_buildTile(source, frame.label));
    }
  } finally {
    for (final frame in frames) {
      frame.image.dispose();
    }
  }

  if (tiles.isEmpty) return null;

  final sheet = _composeSheet(tiles);

  final directory = Directory('build/ensemble_test_runner/screenshots');
  directory.createSync(recursive: true);
  final file = File('${directory.path}/${_safeFileName(testId)}_sheet.png');
  file.writeAsBytesSync(img.encodePng(sheet, level: 1));
  return file.path;
}

img.Image _composeSheet(List<img.Image> tiles) {
  const columns = 5;
  const gap = 16;
  final rows = (tiles.length / columns).ceil();
  final tileWidth = tiles.map((tile) => tile.width).reduce(math.max);
  final tileHeight = tiles.map((tile) => tile.height).reduce(math.max);
  final sheet = img.Image(
    width: columns * tileWidth + (columns + 1) * gap,
    height: rows * tileHeight + (rows + 1) * gap,
  )..clear(img.ColorRgb8(240, 240, 240));

  for (var i = 0; i < tiles.length; i++) {
    final tile = tiles[i];
    final row = i ~/ columns;
    final column = i % columns;
    final remainingTiles = tiles.length - row * columns;
    final rowTiles = math.min(columns, remainingTiles);
    final rowWidth = rowTiles * tileWidth + (rowTiles - 1) * gap;
    final rowStartX = ((sheet.width - rowWidth) / 2).round();
    final x = rowStartX + column * (tileWidth + gap);
    final y = gap + row * (tileHeight + gap);
    img.compositeImage(sheet, tile, dstX: x, dstY: y);
  }

  return sheet;
}

img.Image _buildTile(img.Image source, String label) {
  const width = 420;
  const labelHeight = 72;
  final thumbnail = img.copyResize(
    source,
    width: width,
    interpolation: img.Interpolation.linear,
  );
  final tile = img.Image(width: width, height: thumbnail.height + labelHeight)
    ..clear(img.ColorRgb8(255, 255, 255));
  img.fillRect(
    tile,
    x1: 0,
    y1: 0,
    x2: width - 1,
    y2: labelHeight - 1,
    color: img.ColorRgb8(255, 255, 255),
  );
  img.drawLine(
    tile,
    x1: 0,
    y1: labelHeight - 1,
    x2: width - 1,
    y2: labelHeight - 1,
    color: img.ColorRgb8(224, 229, 236),
  );
  img.compositeImage(tile, thumbnail, dstX: 0, dstY: labelHeight);
  _drawLabel(tile, label, width: width, height: labelHeight);
  return tile;
}

void _drawLabel(
  img.Image image,
  String label, {
  required int width,
  required int height,
}) {
  const horizontalPadding = 12;
  final availableWidth = width - horizontalPadding * 2;
  final lines = _fitLabelLines(label, img.arial24, availableWidth);
  final lineHeight = img.arial24.lineHeight;
  final contentHeight = lines.length * lineHeight;
  final startY = ((height - contentHeight) / 2).round();

  for (var i = 0; i < lines.length; i++) {
    final x = ((width - _textWidth(lines[i], img.arial24)) / 2).round();
    img.drawString(
      image,
      lines[i],
      font: img.arial24,
      x: math.max(horizontalPadding, x),
      y: startY + i * lineHeight,
      color: img.ColorRgb8(20, 26, 36),
    );
  }
}

List<String> _fitLabelLines(String label, img.BitmapFont font, int maxWidth) {
  if (_textWidth(label, font) <= maxWidth) {
    return [label];
  }

  final breakIndex = _bestBreakIndex(label, font, maxWidth);
  if (breakIndex != null) {
    final first = label.substring(0, breakIndex).trimRight();
    final second = label.substring(breakIndex).trimLeft();
    if (_textWidth(second, font) <= maxWidth) {
      return [first, second];
    }
    return [first, _ellipsis(second, font, maxWidth)];
  }

  return [_ellipsis(label, font, maxWidth)];
}

int? _bestBreakIndex(String label, img.BitmapFont font, int maxWidth) {
  final candidates = <int>[];
  for (var i = 1; i < label.length; i++) {
    final previous = label[i - 1];
    final current = label[i];
    if (previous == ' ' ||
        previous == '_' ||
        previous == '(' ||
        current == ')' ||
        current == '_' ||
        current == '(') {
      candidates.add(i);
    }
  }

  int? best;
  var bestScore = double.infinity;
  for (final index in candidates) {
    final first = label.substring(0, index).trimRight();
    final second = label.substring(index).trimLeft();
    if (first.isEmpty || second.isEmpty) continue;
    if (_textWidth(first, font) > maxWidth) continue;

    final overflow = math.max(0, _textWidth(second, font) - maxWidth);
    final balance = (first.length - second.length).abs();
    final score = overflow * 100 + balance;
    if (score < bestScore) {
      bestScore = score.toDouble();
      best = index;
    }
  }
  return best;
}

String _ellipsis(String text, img.BitmapFont font, int maxWidth) {
  const suffix = '...';
  if (_textWidth(text, font) <= maxWidth) return text;
  if (_textWidth(suffix, font) > maxWidth) return '';

  var end = text.length;
  while (end > 0) {
    final candidate = '${text.substring(0, end).trimRight()}$suffix';
    if (_textWidth(candidate, font) <= maxWidth) {
      return candidate;
    }
    end--;
  }
  return suffix;
}

int _textWidth(String text, img.BitmapFont font) {
  var width = 0;
  for (final codeUnit in text.codeUnits) {
    final character = font.characters[codeUnit];
    width += character?.xAdvance ?? font.base ~/ 2;
  }
  return width;
}

String _safeFileName(String value) =>
    value.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
