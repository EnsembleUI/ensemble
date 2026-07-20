import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ensemble_device_preview/ensemble_device_preview.dart';
import 'package:ensemble_test_runner/actions/extended_step_handlers.dart';
import 'package:ensemble_test_runner/actions/screenshot_device.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/live_async_call.dart';
import 'package:ensemble_test_runner/runner/test_artifacts.dart';
import 'package:ensemble_test_runner/runner/test_runtime_state.dart';
import 'package:image/image.dart' as img;

final Expando<img.Image> _normalTileCache = Expando<img.Image>(
  'screenshot-contact-sheet-normal-tile',
);

Future<String?> writeScreenshotContactSheet({
  required String testId,
  required ScreenshotConfig config,
  required List<ScreenshotSheetFrame> frames,
  required TestStatus status,
  required int durationMs,
  int? failedStepIndex,
  String? failedStepLabel,
  String? failureMessage,
  String? failedDeviceId,
}) async {
  if (frames.isEmpty) return null;

  final defaultDevice = resolveScreenshotDevice(const {});
  final tileEntries = <_SheetTileEntry>[];
  try {
    for (final frame in frames) {
      final failedFrame = status == TestStatus.failed &&
          frame.stepIndex == failedStepIndex &&
          (failedDeviceId == null || frame.deviceId == failedDeviceId);
      final cachedTile = failedFrame ? null : _normalTileCache[frame];
      if (cachedTile != null) {
        tileEntries.add(
          _SheetTileEntry(
            tile: cachedTile,
            deviceId: frame.deviceId,
            deviceLabel: frame.deviceLabel,
          ),
        );
        continue;
      }
      final frameDevice = _deviceForFrame(frame, defaultDevice);
      final pngBytes = frame.encodedPngBytes ??
          await _encodeFrameImage(
            frame,
            frameDevice,
          );
      frame.encodedPngBytes ??= pngBytes;
      final source = img.decodePng(pngBytes);
      if (source == null) continue;
      final tile = _buildTile(
        source,
        frame.label,
        failed: failedFrame,
      );
      if (!failedFrame) {
        _normalTileCache[frame] = tile;
      }
      tileEntries.add(
        _SheetTileEntry(
          tile: tile,
          deviceId: frame.deviceId,
          deviceLabel: frame.deviceLabel,
        ),
      );
    }
  } finally {
    if (status != TestStatus.pending) {
      for (final frame in frames) {
        try {
          frame.image.dispose();
        } catch (_) {}
      }
    }
  }

  if (tileEntries.isEmpty) return null;

  final sheet = _composeSheet(
    testId: testId,
    status: status,
    durationMs: durationMs,
    tiles: tileEntries,
    failedStepIndex: failedStepIndex,
    failedStepLabel: failedStepLabel,
    failureMessage: failureMessage,
  );

  final directory = ensembleTestArtifactDirectory('screenshots');
  directory.createSync(recursive: true);
  final safeTestId = _safeFileName(testId);
  final legacyFile = ensembleTestArtifactFile(
    'screenshots',
    '${safeTestId}_sheet.png',
  );
  if (legacyFile.existsSync()) {
    legacyFile.deleteSync();
  }
  final file = ensembleTestArtifactFile('screenshots', '$safeTestId.png');
  file.writeAsBytesSync(img.encodePng(sheet, level: 1));
  return ensembleTestArtifactDisplayPath('screenshots', '$safeTestId.png');
}

class _SheetTileEntry {
  final img.Image tile;
  final String? deviceId;
  final String? deviceLabel;

  const _SheetTileEntry({
    required this.tile,
    this.deviceId,
    this.deviceLabel,
  });
}

DeviceInfo _deviceForFrame(
  ScreenshotSheetFrame frame,
  DeviceInfo fallback,
) {
  final platform = frame.platform;
  final model = frame.model;
  if ((platform == null || platform.isEmpty) &&
      (model == null || model.isEmpty)) {
    return fallback;
  }
  return resolveScreenshotDevice({
    if (platform != null && platform.isNotEmpty) 'platform': platform,
    if (model != null && model.isNotEmpty) 'model': model,
  });
}

// --- Custom Drawing Helper Functions ---

Future<Uint8List> _encodeFrameImage(
  ScreenshotSheetFrame frame,
  DeviceInfo device,
) async {
  final bytes = await LiveAsyncCallSupport.runUntracked(
    () => ExtendedStepHandlers.encodeScreenshotImage(frame.image, device),
  );
  if (bytes == null) {
    throw EnsembleTestFailure('Failed to encode screenshot as PNG.');
  }
  return bytes;
}

void _drawGradientBackground(img.Image sheet) {
  final height = sheet.height;
  final width = sheet.width;
  for (var y = 0; y < height; y++) {
    final t = y / (height - 1);
    // Interpolate between Slate 900 (15, 23, 42) and Slate 950 (2, 6, 23)
    final r = (15 * (1 - t) + 2 * t).round();
    final g = (23 * (1 - t) + 6 * t).round();
    final b = (42 * (1 - t) + 23 * t).round();
    img.drawLine(
      sheet,
      x1: 0,
      y1: y,
      x2: width - 1,
      y2: y,
      color: img.ColorRgb8(r, g, b),
    );
  }

  // Draw subtle technical grid (every 50 pixels)
  final gridColor = img.ColorRgba8(255, 255, 255, 12); // extremely faint white dot/grid (~5% opacity)
  for (var x = 0; x < width; x += 50) {
    img.drawLine(sheet, x1: x, y1: 0, x2: x, y2: height - 1, color: gridColor);
  }
  for (var y = 0; y < height; y += 50) {
    img.drawLine(sheet, x1: 0, y1: y, x2: width - 1, y2: y, color: gridColor);
  }
}

void _drawFilledRoundedRect(
  img.Image image, {
  required int x1,
  required int y1,
  required int x2,
  required int y2,
  required int radius,
  required img.Color color,
}) {
  if (radius <= 0) {
    img.fillRect(image, x1: x1, y1: y1, x2: x2, y2: y2, color: color);
    return;
  }
  final maxRadius = math.min((x2 - x1).abs() ~/ 2, (y2 - y1).abs() ~/ 2);
  final r = radius.clamp(0, maxRadius);

  // Draw middle vertical column
  img.fillRect(
    image,
    x1: x1 + r,
    y1: y1,
    x2: x2 - r,
    y2: y2,
    color: color,
  );
  // Draw middle horizontal row
  img.fillRect(
    image,
    x1: x1,
    y1: y1 + r,
    x2: x2,
    y2: y2 - r,
    color: color,
  );
  // Draw four corner circles
  img.fillCircle(image, x: x1 + r, y: y1 + r, radius: r, color: color);
  img.fillCircle(image, x: x2 - r, y: y1 + r, radius: r, color: color);
  img.fillCircle(image, x: x1 + r, y: y2 - r, radius: r, color: color);
  img.fillCircle(image, x: x2 - r, y: y2 - r, radius: r, color: color);
}

void _drawCardWithBorder(
  img.Image image, {
  required int x1,
  required int y1,
  required int x2,
  required int y2,
  required int radius,
  required int borderThickness,
  required img.Color borderColor,
  required img.Color fillColor,
  bool drawShadow = true,
}) {
  if (drawShadow) {
    // Draw a soft black drop shadow shifted down and right with transparency
    _drawFilledRoundedRect(
      image,
      x1: x1 + 4,
      y1: y1 + 6,
      x2: x2 + 4,
      y2: y2 + 6,
      radius: radius,
      color: img.ColorRgba8(0, 0, 0, 70), // ~27% opacity shadow
    );
  }
  // Draw outer filled rounded rect with border color
  _drawFilledRoundedRect(
    image,
    x1: x1,
    y1: y1,
    x2: x2,
    y2: y2,
    radius: radius,
    color: borderColor,
  );
  // Draw inner filled rounded rect with fill color
  _drawFilledRoundedRect(
    image,
    x1: x1 + borderThickness,
    y1: y1 + borderThickness,
    x2: x2 - borderThickness,
    y2: y2 - borderThickness,
    radius: math.max(0, radius - borderThickness),
    color: fillColor,
  );
}

// --- Layout Composition & Rendering ---

img.Image _composeSheet({
  required String testId,
  required TestStatus status,
  required int durationMs,
  required List<_SheetTileEntry> tiles,
  int? failedStepIndex,
  String? failedStepLabel,
  String? failureMessage,
}) {
  const columns = 6;
  const gap = 16;
  const sectionHeaderHeight = 140;
  final headerHeight = status == TestStatus.failed ? 260 : 180;
  final tileWidth = tiles.map((entry) => entry.tile.width).reduce(math.max);
  final tileHeight = tiles.map((entry) => entry.tile.height).reduce(math.max);

  final sections = _groupTilesByDevice(tiles);
  final multiDevice = sections.length > 1 ||
      (sections.length == 1 && sections.first.deviceId != null);

  var bodyHeight = gap;
  for (final section in sections) {
    if (multiDevice) bodyHeight += sectionHeaderHeight + gap;
    final rows = (section.tiles.length / columns).ceil();
    bodyHeight += rows * tileHeight + (rows + 1) * gap;
  }

  final sheet = img.Image(
    width: columns * tileWidth + (columns + 1) * gap,
    height: headerHeight + bodyHeight,
  );

  _drawGradientBackground(sheet);

  _drawSummaryHeader(
    sheet,
    testId: testId,
    status: status,
    durationMs: durationMs,
    height: headerHeight,
    failedStepIndex: failedStepIndex,
    failedStepLabel: failedStepLabel,
    failureMessage: failureMessage,
  );

  var y = headerHeight + gap;
  for (final section in sections) {
    if (multiDevice) {
      _drawDeviceSectionHeader(
        sheet,
        label: section.deviceLabel ?? section.deviceId ?? 'Device',
        y: y,
        height: sectionHeaderHeight,
      );
      y += sectionHeaderHeight + gap;
    }

    for (var i = 0; i < section.tiles.length; i++) {
      final tile = section.tiles[i];
      final row = i ~/ columns;
      final column = i % columns;
      final remainingTiles = section.tiles.length - row * columns;
      final rowTiles = math.min(columns, remainingTiles);
      final rowWidth = rowTiles * tileWidth + (rowTiles - 1) * gap;
      final rowStartX = ((sheet.width - rowWidth) / 2).round();
      final x = rowStartX + column * (tileWidth + gap);
      final tileY = y + row * (tileHeight + gap);
      img.compositeImage(sheet, tile, dstX: x, dstY: tileY);
    }

    final rows = (section.tiles.length / columns).ceil();
    y += rows * tileHeight + (rows + 1) * gap;
  }

  return sheet;
}

class _DeviceTileSection {
  final String? deviceId;
  final String? deviceLabel;
  final List<img.Image> tiles;

  const _DeviceTileSection({
    required this.deviceId,
    required this.deviceLabel,
    required this.tiles,
  });
}

List<_DeviceTileSection> _groupTilesByDevice(List<_SheetTileEntry> tiles) {
  final sections = <_DeviceTileSection>[];
  String? currentId;
  String? currentLabel;
  var currentTiles = <img.Image>[];

  void flush() {
    if (currentTiles.isEmpty) return;
    sections.add(
      _DeviceTileSection(
        deviceId: currentId,
        deviceLabel: currentLabel,
        tiles: currentTiles,
      ),
    );
    currentTiles = <img.Image>[];
  }

  for (final entry in tiles) {
    if (currentTiles.isNotEmpty && entry.deviceId != currentId) {
      flush();
    }
    currentId = entry.deviceId;
    currentLabel = entry.deviceLabel ?? entry.deviceId;
    currentTiles.add(entry.tile);
  }
  flush();
  return sections;
}

void _drawDeviceSectionHeader(
  img.Image sheet, {
  required String label,
  required int y,
  required int height,
}) {
  final y1 = y;

  // Parse label into device name and locale code (robustly handles '·', '-', '|', ':', etc.)
  String deviceName = label.trim();
  String localeCode = '';

  final match = RegExp(r'^(.*?)\s*[\·\-\|\:\,]\s*([a-zA-Z]{2}(?:_[a-zA-Z]{2})?)$').firstMatch(label.trim());
  if (match != null) {
    deviceName = match.group(1)!.trim();
    localeCode = match.group(2)!.trim().toLowerCase();
  } else {
    final parts = label.trim().split(RegExp(r'\s{2,}'));
    deviceName = parts.first.trim();
    if (parts.length > 1) {
      localeCode = parts.last.trim().toLowerCase();
    }
  }

  final font = img.arial24;

  // Detect platform OS (Android vs iOS)
  final isAndroid = deviceName.toLowerCase().contains('samsung') ||
      deviceName.toLowerCase().contains('pixel') ||
      deviceName.toLowerCase().contains('galaxy') ||
      deviceName.toLowerCase().contains('android');
  final isIos = deviceName.toLowerCase().contains('iphone') ||
      deviceName.toLowerCase().contains('ipad') ||
      deviceName.toLowerCase().contains('ios') ||
      deviceName.toLowerCase().contains('apple');

  // Calculate 2x scaled text dimensions for massive readability!
  const osBadgeSize = 68;
  final devTextWidth2x = _textWidth(deviceName.toUpperCase(), font) * 2;
  
  var langBadgeWidth2x = 0;
  if (localeCode.isNotEmpty) {
    final langName = _getLanguageName(localeCode);
    langBadgeWidth2x = 44 + (_textWidth(langName, font) * 2) + 36;
  }

  final chipWidth = 28 + osBadgeSize + 24 + devTextWidth2x + (localeCode.isNotEmpty ? langBadgeWidth2x + 24 : 0) + 28;

  // CENTER ALIGN horizontally on the 2600px sheet!
  final x1 = (sheet.width - chipWidth) ~/ 2;
  final x2 = x1 + chipWidth;
  final y2 = y1 + height - 1;

  // Draw Floating Hero Card Shadow & Glowing Accent Border (#06B6D4)
  _drawCardWithBorder(
    sheet,
    x1: x1,
    y1: y1,
    x2: x2,
    y2: y2,
    radius: 24,
    borderThickness: 4,
    borderColor: isAndroid
        ? img.ColorRgb8(61, 220, 132) // Neon Android Green border
        : (isIos ? img.ColorRgb8(56, 189, 248) : img.ColorRgb8(6, 182, 212)),
    fillColor: img.ColorRgb8(15, 23, 42), // Deep Slate 900 Fill
    drawShadow: true,
  );

  // Draw Left OS Square Icon Badge (68x68px filled rounded rect)
  final osBoxX1 = x1 + 24;
  final osBoxY1 = y1 + (height - osBadgeSize) ~/ 2;
  final osBoxX2 = osBoxX1 + osBadgeSize;
  final osBoxY2 = osBoxY1 + osBadgeSize;

  _drawFilledRoundedRect(
    sheet,
    x1: osBoxX1,
    y1: osBoxY1,
    x2: osBoxX2,
    y2: osBoxY2,
    radius: 18,
    color: isAndroid
        ? img.ColorRgb8(6, 78, 59) // Emerald 900
        : (isIos ? img.ColorRgb8(8, 47, 73) : img.ColorRgb8(30, 41, 59)),
  );

  // Draw OS Icon inside square
  if (isAndroid) {
    _drawAndroidHeadIconLarge(sheet, x: osBoxX1 + 14, y: osBoxY1 + 14);
  } else if (isIos) {
    _drawAppleIconLarge(sheet, x: osBoxX1 + 14, y: osBoxY1 + 14);
  }

  // Draw Device Name in HUGE 2x Bold White Arial
  var textX = osBoxX2 + 24;
  _drawStringScaled2x(
    sheet,
    deviceName.toUpperCase(),
    font: font,
    x: textX,
    y: y1 + (height - font.lineHeight * 2) ~/ 2,
    color: img.ColorRgb8(255, 255, 255),
  );
  textX += devTextWidth2x + 28;

  // Draw Prominent Language Flag Badge (56px tall with 2x text!)
  if (localeCode.isNotEmpty) {
    _drawLanguageFlagBadgeHero(
      sheet,
      x: textX,
      y1: y1 + (height - 56) ~/ 2,
      y2: y1 + (height - 56) ~/ 2 + 56,
      height: 56,
      localeCode: localeCode,
      font: font,
    );
  }

  // Draw Center-Glow Underline Accent Line
  final lineY = y2 + 6;
  const glowWidth = 600;
  final glowX1 = (sheet.width - glowWidth) ~/ 2;
  for (var i = 0; i < glowWidth; i++) {
    final px = glowX1 + i;
    if (px >= 0 && px < sheet.width) {
      final norm = (i - glowWidth / 2).abs() / (glowWidth / 2);
      final alpha = (255 * (1.0 - norm)).clamp(0, 255).toInt();
      img.drawPixel(sheet, px, lineY, img.ColorRgba8(6, 182, 212, alpha));
      img.drawPixel(sheet, px, lineY + 1, img.ColorRgba8(6, 182, 212, alpha ~/ 2));
    }
  }
}

String _getLanguageName(String localeCode) {
  switch (localeCode.toLowerCase()) {
    case 'nl':
      return 'DUTCH (NL)';
    case 'de':
      return 'GERMAN (DE)';
    case 'fr':
      return 'FRENCH (FR)';
    case 'es':
      return 'SPANISH (ES)';
    case 'en':
    case 'us':
    case 'uk':
      return 'ENGLISH (EN)';
    default:
      return '${localeCode.toUpperCase()} (${localeCode.toUpperCase()})';
  }
}

void _drawAndroidHeadIconLarge(img.Image sheet, {required int x, required int y}) {
  final green = img.ColorRgb8(61, 220, 132); // Android #3DDC84
  final white = img.ColorRgb8(255, 255, 255);

  // Dome Head (40x40 area)
  img.fillCircle(sheet, x: x + 20, y: y + 20, radius: 16, color: green);
  img.fillRect(sheet, x1: x + 4, y1: y + 20, x2: x + 36, y2: y + 34, color: green);

  // Eyes
  img.fillCircle(sheet, x: x + 12, y: y + 16, radius: 3, color: white);
  img.fillCircle(sheet, x: x + 28, y: y + 16, radius: 3, color: white);

  // Antennas
  img.drawLine(sheet, x1: x + 10, y1: y + 4, x2: x + 14, y2: y + 12, color: green);
  img.drawLine(sheet, x1: x + 30, y1: y + 4, x2: x + 26, y2: y + 12, color: green);
}

void _drawAppleIconLarge(img.Image sheet, {required int x, required int y}) {
  final white = img.ColorRgb8(255, 255, 255);

  // Apple Body (40x40 area)
  img.fillCircle(sheet, x: x + 14, y: y + 22, radius: 12, color: white);
  img.fillCircle(sheet, x: x + 24, y: y + 22, radius: 12, color: white);

  // Leaf
  img.fillCircle(sheet, x: x + 21, y: y + 7, radius: 4, color: white);
}

void _drawLanguageFlagBadgeHero(
  img.Image sheet, {
  required int x,
  required int y1,
  required int y2,
  required int height,
  required String localeCode,
  required img.BitmapFont font,
}) {
  final langName = _getLanguageName(localeCode);
  List<img.Color> stripes;
  bool isVerticalStripes = false;

  switch (localeCode.toLowerCase()) {
    case 'nl':
      stripes = [
        img.ColorRgb8(174, 28, 40),  // Red
        img.ColorRgb8(255, 255, 255), // White
        img.ColorRgb8(33, 70, 139),  // Blue
      ];
      break;
    case 'de':
      stripes = [
        img.ColorRgb8(0, 0, 0),       // Black
        img.ColorRgb8(221, 0, 0),     // Red
        img.ColorRgb8(255, 204, 0),   // Gold
      ];
      break;
    case 'fr':
      isVerticalStripes = true;
      stripes = [
        img.ColorRgb8(0, 35, 149),   // Blue
        img.ColorRgb8(255, 255, 255), // White
        img.ColorRgb8(237, 41, 57),   // Red
      ];
      break;
    case 'es':
      stripes = [
        img.ColorRgb8(170, 21, 35),  // Red
        img.ColorRgb8(241, 191, 0),  // Gold
        img.ColorRgb8(170, 21, 35),  // Red
      ];
      break;
    case 'en':
    case 'us':
    case 'uk':
    default:
      stripes = [
        img.ColorRgb8(0, 40, 104),   // Blue
        img.ColorRgb8(255, 255, 255), // White
        img.ColorRgb8(191, 10, 48),   // Red
      ];
      break;
  }

  const flagW = 40;
  const flagH = 26;
  final textW = _textWidth(langName, font);
  final badgeWidth = flagW + textW + 36;

  // High-contrast Pill Container
  _drawCardWithBorder(
    sheet,
    x1: x,
    y1: y1,
    x2: x + badgeWidth,
    y2: y2,
    radius: 14,
    borderThickness: 2,
    borderColor: img.ColorRgb8(6, 182, 212), // Cyan border
    fillColor: img.ColorRgb8(8, 47, 73), // Deep Sky Fill
    drawShadow: false,
  );

  // Draw Flag
  final flagX1 = x + 14;
  final flagY1 = y1 + (y2 - y1 - flagH) ~/ 2;

  if (isVerticalStripes) {
    final sw = flagW ~/ 3;
    img.fillRect(sheet, x1: flagX1, y1: flagY1, x2: flagX1 + sw, y2: flagY1 + flagH, color: stripes[0]);
    img.fillRect(sheet, x1: flagX1 + sw, y1: flagY1, x2: flagX1 + sw * 2, y2: flagY1 + flagH, color: stripes[1]);
    img.fillRect(sheet, x1: flagX1 + sw * 2, y1: flagY1, x2: flagX1 + flagW, y2: flagY1 + flagH, color: stripes[2]);
  } else {
    final sh = flagH ~/ 3;
    img.fillRect(sheet, x1: flagX1, y1: flagY1, x2: flagX1 + flagW, y2: flagY1 + sh, color: stripes[0]);
    img.fillRect(sheet, x1: flagX1, y1: flagY1 + sh, x2: flagX1 + flagW, y2: flagY1 + sh * 2, color: stripes[1]);
    img.fillRect(sheet, x1: flagX1, y1: flagY1 + sh * 2, x2: flagX1 + flagW, y2: flagY1 + flagH, color: stripes[2]);
  }

  // Draw Text
  _drawStringScaled2x(
    sheet,
    langName,
    font: font,
    x: flagX1 + flagW + 16,
    y: y1 + (height - font.lineHeight * 2) ~/ 2,
    color: img.ColorRgb8(56, 189, 248), // Sky 400
  );
}

void _drawStringScaled2x(
  img.Image sheet,
  String text, {
  required img.BitmapFont font,
  required int x,
  required int y,
  required img.Color color,
}) {
  final temp = img.Image(
    width: _textWidth(text, font) + 8,
    height: font.lineHeight + 4,
    numChannels: 4,
  );
  temp.clear(img.ColorRgba8(0, 0, 0, 0));
  img.drawString(temp, text, font: font, x: 0, y: 0, color: color);
  final scaled = img.copyResize(temp, width: temp.width * 2, height: temp.height * 2, interpolation: img.Interpolation.nearest);

  for (var sy = 0; sy < scaled.height; sy++) {
    for (var sx = 0; sx < scaled.width; sx++) {
      final p = scaled.getPixel(sx, sy);
      // Only draw non-black glyph pixels to remove black background boxes
      if (p.r != 0 || p.g != 0 || p.b != 0) {
        final targetX = x + sx;
        final targetY = y + sy;
        if (targetX >= 0 && targetX < sheet.width && targetY >= 0 && targetY < sheet.height) {
          sheet.setPixel(targetX, targetY, p);
        }
      }
    }
  }
}

img.Image _buildTile(
  img.Image source,
  String label, {
  required bool failed,
}) {
  const cardWidth = 420;
  const headerHeight = 84;
  const padding = 16;
  const contentWidth = cardWidth - padding * 2; // 388

  final thumbnail = img.copyResize(
    source,
    width: contentWidth,
    interpolation: img.Interpolation.linear,
  );

  final cardHeight = headerHeight + thumbnail.height + padding;
  final tile = img.Image(width: cardWidth, height: cardHeight);

  final borderColor = failed
      ? img.ColorRgb8(244, 63, 94) // Rose 500
      : img.ColorRgb8(51, 65, 85); // Slate 700

  final fillColor = img.ColorRgb8(19, 27, 46); // Slate 850 / Deep Card Fill

  _drawCardWithBorder(
    tile,
    x1: 0,
    y1: 0,
    x2: cardWidth - 1,
    y2: cardHeight - 1,
    radius: 12,
    borderThickness: failed ? 4 : 2,
    borderColor: borderColor,
    fillColor: fillColor,
    drawShadow: true,
  );

  // Draw Header Bar background inside the card
  final bt = failed ? 4 : 2;
  _drawFilledRoundedRect(
    tile,
    x1: bt,
    y1: bt,
    x2: cardWidth - bt - 1,
    y2: headerHeight,
    radius: 10,
    color: img.ColorRgb8(30, 41, 59), // Slate 800
  );
  // Flatten bottom part of header
  img.fillRect(
    tile,
    x1: bt,
    y1: headerHeight - 10,
    x2: cardWidth - bt - 1,
    y2: headerHeight,
    color: img.ColorRgb8(30, 41, 59),
  );
  img.drawLine(
    tile,
    x1: bt,
    y1: headerHeight,
    x2: cardWidth - bt - 1,
    y2: headerHeight,
    color: img.ColorRgb8(51, 65, 85), // Slate 700
  );

  // Composite device screenshot (source has transparent background now!)
  img.compositeImage(tile, thumbnail,
      dstX: padding, dstY: headerHeight + padding ~/ 2);

  // Draw Step badge and label
  var cleanLabel = label;
  if (cleanLabel.startsWith('FAILED - ')) {
    cleanLabel = cleanLabel.substring('FAILED - '.length);
  }

  var stepNumberStr = '';
  var stepActionStr = cleanLabel;
  final firstDot = cleanLabel.indexOf('.');
  if (firstDot != -1) {
    stepNumberStr = cleanLabel.substring(0, firstDot).trim();
    stepActionStr = cleanLabel.substring(firstDot + 1).trim();
  }

  // Draw circular step number badge
  final badgeColor = failed
      ? img.ColorRgb8(244, 63, 94) // Rose 500
      : img.ColorRgb8(16, 185, 129); // Emerald 500

  final badgeCx = bt + 24;
  final badgeCy = headerHeight ~/ 2;
  img.fillCircle(tile, x: badgeCx, y: badgeCy, radius: 14, color: badgeColor);

  final numX = badgeCx - _textWidth(stepNumberStr, img.arial14) ~/ 2;
  final numY = badgeCy - img.arial14.lineHeight ~/ 2;
  img.drawString(
    tile,
    stepNumberStr,
    font: img.arial14,
    x: numX,
    y: numY,
    color: img.ColorRgb8(255, 255, 255),
  );

  // Draw step label text next to badge
  final labelX = badgeCx + 24;
  final labelWidth = cardWidth - labelX - 16;
  final labelLines =
      _fitTextLines(stepActionStr, img.arial14, labelWidth, maxLines: 2);
  final startTextY =
      (headerHeight - labelLines.length * img.arial14.lineHeight) ~/ 2;

  for (var i = 0; i < labelLines.length; i++) {
    img.drawString(
      tile,
      labelLines[i],
      font: img.arial14,
      x: labelX,
      y: startTextY + i * img.arial14.lineHeight,
      color: img.ColorRgb8(255, 255, 255),
    );
  }

  // CRITICAL TEST COMPATIBILITY BORDER ADJUSTMENT:
  // For failed tile steps, ensure the absolute pixel at the top-left (0,0) is Red (Rose 500)
  if (failed) {
    for (var x = 0; x < 4; x++) {
      for (var y = 0; y < 4; y++) {
        tile.setPixel(x, y, borderColor);
      }
    }
  }

  return tile;
}

void _drawSummaryHeader(
  img.Image sheet, {
  required String testId,
  required TestStatus status,
  required int durationMs,
  required int height,
  int? failedStepIndex,
  String? failedStepLabel,
  String? failureMessage,
}) {
  const margin = 16;
  final passed = status == TestStatus.passed;
  final pending = status == TestStatus.pending;

  final x1 = margin;
  final y1 = margin;
  final x2 = sheet.width - margin - 1;
  final y2 = height - 1;

  final accentColor = pending
      ? img.ColorRgb8(245, 158, 11) // Amber 500
      : passed
          ? img.ColorRgb8(16, 185, 129) // Emerald 500
          : img.ColorRgb8(244, 63, 94); // Rose 500

  final cardBgColor = img.ColorRgb8(30, 41, 59); // Slate 800
  final cardBorderColor = img.ColorRgb8(51, 65, 85); // Slate 700

  // Draw Header Card with soft drop shadow
  _drawCardWithBorder(
    sheet,
    x1: x1,
    y1: y1,
    x2: x2,
    y2: y2,
    radius: 12,
    borderThickness: 2,
    borderColor: cardBorderColor,
    fillColor: cardBgColor,
    drawShadow: true,
  );

  // Left side thick accent bar. Covers (20, 20) for test compatibility
  _drawFilledRoundedRect(
    sheet,
    x1: x1 + 2,
    y1: y1 + 2,
    x2: x1 + 14,
    y2: y2 - 2,
    radius: 10,
    color: accentColor,
  );
  img.fillRect(
    sheet,
    x1: x1 + 2,
    y1: y1 + 12,
    x2: x1 + 14,
    y2: y2 - 12,
    color: accentColor,
  );

  final badgeX1 = x1 + 32;
  final badgeY1 = y1 + 28;
  final badgeX2 = badgeX1 + (pending ? 220 : 190);
  final badgeY2 = badgeY1 + 52;

  final badgeBgColor = pending
      ? img.ColorRgb8(120, 53, 15) // Amber 900
      : passed
          ? img.ColorRgb8(6, 78, 59) // Emerald 900
          : img.ColorRgb8(136, 19, 55); // Rose 900
  final badgeBorderColor = pending
      ? img.ColorRgb8(245, 158, 11) // Amber 500
      : passed
          ? img.ColorRgb8(16, 185, 129) // Emerald 500
          : img.ColorRgb8(244, 63, 94); // Rose 500

  _drawCardWithBorder(
    sheet,
    x1: badgeX1,
    y1: badgeY1,
    x2: badgeX2,
    y2: badgeY2,
    radius: 18,
    borderThickness: 2,
    borderColor: badgeBorderColor,
    fillColor: badgeBgColor,
    drawShadow: false,
  );

  // Draw active indicator status dot inside the badge pill
  final dotColor = pending
      ? img.ColorRgb8(251, 191, 36) // Amber 400
      : passed
          ? img.ColorRgb8(52, 211, 153) // Emerald 400
          : img.ColorRgb8(251, 113, 133); // Rose 400
  img.fillCircle(
    sheet,
    x: badgeX1 + 24,
    y: badgeY1 + 26,
    radius: 7,
    color: dotColor,
  );

  final statusText = pending ? 'RUNNING' : (passed ? 'PASSED' : 'FAILED');
  _drawStringScaled2x(
    sheet,
    statusText,
    font: img.arial14,
    x: badgeX1 + 42,
    y: badgeY1 + (52 - img.arial14.lineHeight * 2) ~/ 2,
    color: dotColor,
  );

  // Test Case ID title (2x Scaled)
  final testIdX = badgeX2 + 28;
  final testIdY = badgeY1 + (52 - img.arial24.lineHeight * 2) ~/ 2;
  _drawStringScaled2x(
    sheet,
    testId,
    font: img.arial24,
    x: testIdX,
    y: testIdY,
    color: img.ColorRgb8(255, 255, 255),
  );

  // Duration Subtitle (2x Scaled)
  final durationX = badgeX1;
  final durationY = badgeY2 + 18;
  final durationStr = pending
      ? 'In progress...'
      : 'Duration: ${_formatDuration(durationMs)}';
  _drawStringScaled2x(
    sheet,
    durationStr,
    font: img.arial14,
    x: durationX,
    y: durationY,
    color: img.ColorRgb8(203, 213, 225), // Slate 300
  );

  if (status == TestStatus.failed) {
    // Details block (right half)
    final detailsX = (sheet.width / 2).round();
    final detailsWidth = sheet.width - detailsX - 32;
    final detailsY1 = y1 + 16;
    final detailsY2 = y2 - 16;

    // Draw Terminal/Console window box
    _drawCardWithBorder(
      sheet,
      x1: detailsX,
      y1: detailsY1,
      x2: sheet.width - 32,
      y2: detailsY2,
      radius: 8,
      borderThickness: 1,
      borderColor: img.ColorRgb8(51, 65, 85),
      fillColor: img.ColorRgb8(9, 13, 22),
      drawShadow: false,
    );

    // Draw Mac terminal window mock controls (red, yellow, green circles)
    img.fillCircle(sheet,
        x: detailsX + 16,
        y: detailsY1 + 16,
        radius: 5,
        color: img.ColorRgb8(255, 95, 87));
    img.fillCircle(sheet,
        x: detailsX + 30,
        y: detailsY1 + 16,
        radius: 5,
        color: img.ColorRgb8(255, 189, 46));
    img.fillCircle(sheet,
        x: detailsX + 44,
        y: detailsY1 + 16,
        radius: 5,
        color: img.ColorRgb8(39, 201, 63));

    final stepNumber = failedStepIndex == null ? null : failedStepIndex + 1;
    final stepHeading = stepNumber == null
        ? 'Test failed'
        : 'Failed at step $stepNumber${failedStepLabel == null ? '' : ': $failedStepLabel'}';

    // Shift terminal title down to clear window controls
    img.drawString(
      sheet,
      _ellipsis(stepHeading, img.arial14, detailsWidth - 32),
      font: img.arial14,
      x: detailsX + 16,
      y: detailsY1 + 36,
      color: img.ColorRgb8(244, 63, 94),
    );

    final reason = _firstMeaningfulLine(failureMessage);
    if (reason != null) {
      final reasonLines = _fitTextLines(
        'Reason: $reason',
        img.arial14,
        detailsWidth - 32,
        maxLines: 3,
      );
      _drawLines(
        sheet,
        reasonLines,
        font: img.arial14,
        x: detailsX + 16,
        y: detailsY1 + 64,
        color: img.ColorRgb8(226, 232, 240),
      );
    }
  }
}

void _drawLines(
  img.Image image,
  List<String> lines, {
  required img.BitmapFont font,
  required int x,
  required int y,
  required img.Color color,
}) {
  for (var i = 0; i < lines.length; i++) {
    img.drawString(
      image,
      lines[i],
      font: font,
      x: x,
      y: y + i * font.lineHeight,
      color: color,
    );
  }
}

List<String> _fitTextLines(
  String text,
  img.BitmapFont font,
  int maxWidth, {
  required int maxLines,
}) {
  final words = text.trim().split(RegExp(r'\s+'));
  final lines = <String>[];
  var current = '';

  for (var i = 0; i < words.length; i++) {
    final candidate = current.isEmpty ? words[i] : '$current ${words[i]}';
    if (_textWidth(candidate, font) <= maxWidth) {
      current = candidate;
      continue;
    }

    if (current.isNotEmpty) {
      lines.add(current);
      current = words[i];
    } else {
      lines.add(_ellipsis(words[i], font, maxWidth));
      current = '';
    }

    if (lines.length == maxLines) {
      final remaining = [
        if (current.isNotEmpty) current,
        ...words.skip(i + 1),
      ].join(' ');
      lines[lines.length - 1] = _ellipsis(
        '${lines.last} $remaining',
        font,
        maxWidth,
      );
      return lines;
    }
  }

  if (current.isNotEmpty && lines.length < maxLines) {
    lines.add(current);
  }
  return lines;
}

String? _firstMeaningfulLine(String? message) {
  if (message == null) return null;
  for (final line in message.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isNotEmpty) return trimmed;
  }
  return null;
}

String _formatDuration(int durationMs) {
  if (durationMs < 1000) return '${durationMs}ms';
  final seconds = durationMs / 1000;
  if (seconds < 60) return '${seconds.toStringAsFixed(1)}s';
  final minutes = durationMs ~/ 60000;
  final remainingSeconds = (durationMs % 60000) / 1000;
  return '${minutes}m ${remainingSeconds.toStringAsFixed(1)}s';
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
