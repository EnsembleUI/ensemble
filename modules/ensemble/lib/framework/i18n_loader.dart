import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_i18n/loaders/translation_loader.dart';

/// extension of flutter_i18n package. This will load the translations
/// from memory (cache from Firestore)
class DataTranslationLoader extends TranslationLoader {
  DataTranslationLoader(
      {required this.getTranslationMap,
      required this.defaultLocale,
      forcedLocale}) {
    this.forcedLocale = forcedLocale;
  }

  final Map? Function(Locale) getTranslationMap;

  // fallback to this defaultLocale if the current locale doesn't have the translated string
  final Locale defaultLocale;

  /// Note that we don't have yet the mechanism to support reloading locale
  /// so changes to translation will need to kill the app first.
  @override
  Future<Map> load() async {
    this.locale = locale ?? await findDeviceLocale();
    Map translationMap = getTranslationMap(this.locale!) ?? {};

    // merge with the defaultLocale in case the current locale don't have all the strings
    if (defaultLocale != this.locale) {
      translationMap = _deepMergeMaps(
          getTranslationMap(defaultLocale) ?? {}, translationMap);
    }

    return translationMap;
  }

  /// copied from FileTranslationLoader
  Map<K, V> _deepMergeMaps<K, V>(
    Map<K, V> fallback,
    Map<K, V> original,
  ) {
    var result = Map<K, V>.of(fallback);

    original.forEach((key, mapValue) {
      var p1 = result[key] as V;
      var p2 = mapValue;

      V mapResult;
      if (result.containsKey(key)) {
        if (p1 is Map && p2 is Map) {
          Map map1 = p1;
          Map map2 = p2;
          mapResult = _deepMergeMaps(map1, map2) as V;
        } else {
          mapResult = p2;
        }
      } else {
        mapResult = mapValue;
      }

      result[key] = mapResult;
    });
    return result;
  }
}
