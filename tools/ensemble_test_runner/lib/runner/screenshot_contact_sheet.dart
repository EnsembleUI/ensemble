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

  final directory = Directory('build/ensemble_test_runner/screenshots');
  directory.createSync(recursive: true);
  final file = File('${directory.path}/${_safeFileName(testId)}_sheet.jpg');
  file.writeAsBytesSync(img.encodeJpg(sheet, quality: 88));
  return file.path;
}

img.Image _buildTile(img.Image source, String label) {
  const width = 240;
  const labelHeight = 44;
  final thumbnail = img.copyResize(
    source,
    width: width,
    interpolation: img.Interpolation.average,
  );
  final tile = img.Image(width: width, height: thumbnail.height + labelHeight)
    ..clear(img.ColorRgb8(255, 255, 255));
  img.compositeImage(tile, thumbnail, dstX: 0, dstY: labelHeight);
  img.drawString(
    tile,
    _shortLabel(label),
    font: img.arial14,
    x: 4,
    y: 4,
    color: img.ColorRgb8(0, 0, 0),
  );
  return tile;
}

String _shortLabel(String label) =>
    label.length <= 34 ? label : '${label.substring(0, 31)}...';

String _safeFileName(String value) =>
    value.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
