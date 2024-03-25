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
      this.forcedLocale});

  final Map? Function(Locale) getTranslationMap;

  // use this fallback locale if the user locale is not supported
  final Locale defaultLocale;

  // force to use this Locale regardless of user locale or default local
  final Locale? forcedLocale;

  /// Note that we don't have yet the mechanism to support reloading locale
  /// so changes to translation will need to kill the app first.
  @override
  Future<Map> load() async {
    locale = forcedLocale ?? await findDeviceLocale();
    return getTranslationMap(locale!) ?? getTranslationMap(defaultLocale) ?? {};

    // // use this for Preview purposes only
    // if (forcedLocale != null) {
    //   return getTranslationMap(forcedLocale!) ?? {};
    // }
    // return getTranslationMap(await findDeviceLocale()) ??
    //     getTranslationMap(defaultLocale) ??
    //     {};
  }

  /// copied from FileTranslationLoader
  Map<K, V> _deepMergeMaps<K, V>(
    Map<K, V> map1,
    Map<K, V> map2,
  ) {
    var result = Map<K, V>.of(map1);

    map2.forEach((key, mapValue) {
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
