import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

/// Loads application fonts used by widget tests and provides the same asset
/// lookup rules for tests that inspect the bootstrap behavior.
///
/// Font registration is process-wide in Flutter. Keeping the loaded flag here
/// makes that lifecycle explicit and prevents each harness instance from
/// re-reading the manifest and registering the same families.
class TestFontLoader {
  static bool _loaded = false;

  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;

    var loadedRoboto = false;
    try {
      final rawManifest = await rootBundle.loadString('FontManifest.json');
      final manifest = jsonDecode(rawManifest) as List<dynamic>;
      for (final familyEntry in manifest.whereType<Map>()) {
        final family = familyEntry['family']?.toString();
        final fonts = familyEntry['fonts'];
        if (family == null || fonts is! List) continue;
        var familyLoaded = false;
        for (final alias in familyAliases(family)) {
          familyLoaded = await _loadFontFamily(alias, fonts) || familyLoaded;
        }
        if (familyLoaded && family.toLowerCase().contains('roboto')) {
          loadedRoboto = true;
        }
      }
    } catch (_) {
      // App may not ship a FontManifest; fall through to SDK Roboto.
    }

    await _loadSdkRoboto(includeRoboto: !loadedRoboto);
  }

  static List<String> familyAliases(String family) {
    final aliases = <String>{family, family.toLowerCase()};
    const packagePrefix = 'packages/';
    if (family.startsWith(packagePrefix)) {
      final slashIndex = family.lastIndexOf('/');
      if (slashIndex != -1 && slashIndex < family.length - 1) {
        final unqualifiedFamily = family.substring(slashIndex + 1);
        aliases.add(unqualifiedFamily);
        aliases.add(unqualifiedFamily.toLowerCase());
      }
    }
    return aliases.toList(growable: false);
  }

  static List<String> assetCandidates(String asset) {
    final candidates = <String>{asset};
    if (asset.contains('%')) {
      try {
        candidates.add(Uri.decodeFull(asset));
      } catch (_) {
        // Keep the manifest-provided asset key if decoding is invalid.
      }
    }
    return candidates.toList(growable: false);
  }

  static String? _flutterSdkRoot() {
    final env = Platform.environment['FLUTTER_ROOT'];
    if (env != null &&
        env.isNotEmpty &&
        Directory('$env/bin/cache/artifacts/material_fonts').existsSync()) {
      return env;
    }
    var dir = File(Platform.resolvedExecutable).absolute.parent;
    for (var i = 0; i < 8; i++) {
      if (Directory('${dir.path}/bin/cache/artifacts/material_fonts')
          .existsSync()) {
        return dir.path;
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    return null;
  }

  static const _sdkRobotoFiles = [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
  ];

  static const _sdkFallbackFamilies = [
    'Roboto',
    'roboto',
    'Inter',
    'inter',
    'Inter_regular',
    'Inter_500',
    'Inter_600',
    'Inter_700',
    '.SF Pro Text',
    '.SF Pro Display',
    '.SF UI Text',
    '.SF UI Display',
  ];

  static Future<void> _loadSdkRoboto({required bool includeRoboto}) async {
    final root = _flutterSdkRoot();
    if (root == null) return;
    final fontsDir = '$root/bin/cache/artifacts/material_fonts';
    final payloads = <ByteData>[];
    for (final name in _sdkRobotoFiles) {
      final file = File('$fontsDir/$name');
      if (!file.existsSync()) continue;
      payloads.add(ByteData.sublistView(file.readAsBytesSync()));
    }
    if (payloads.isEmpty) return;
    for (final family in _sdkFallbackFamilies) {
      if (!includeRoboto && (family == 'Roboto' || family == 'roboto')) {
        continue;
      }
      final loader = FontLoader(family);
      for (final data in payloads) {
        loader.addFont(Future.value(data));
      }
      await loader.load();
    }
  }

  static Future<bool> _loadFontFamily(
    String family,
    List<dynamic> fontEntries,
  ) async {
    final loader = FontLoader(family);
    var hasFonts = false;
    for (final fontEntry in fontEntries.whereType<Map>()) {
      final asset = fontEntry['asset']?.toString();
      if (asset == null || asset.isEmpty) continue;
      for (final assetKey in assetCandidates(asset)) {
        try {
          final fontData = await rootBundle.load(assetKey);
          loader.addFont(Future.value(fontData));
          hasFonts = true;
          break;
        } catch (_) {
          // Missing optional font assets must not fail behavioral tests.
        }
      }
    }
    if (hasFonts) await loader.load();
    return hasFonts;
  }
}
