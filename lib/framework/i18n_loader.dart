import 'package:flutter_i18n/loaders/file_content.dart';
import 'package:flutter_i18n/loaders/translation_loader.dart';

/// extension of flutter_i18n package. This will load the translations
/// from memory (cache from Firestore)
class DataTranslationLoader extends TranslationLoader {
  DataTranslationLoader({this.defaultLocaleMap, this.fallbackLocaleMap});
  Map? defaultLocaleMap;
  Map? fallbackLocaleMap;

  /// Note that we don't have yet the mechanism to support reloading locale
  /// so changes to translation will need to kill the app first.
  @override
  Future<Map> load() {
    Map result = {};
    if (defaultLocaleMap != null) {
      result.addAll(defaultLocaleMap!);
    }
    if (fallbackLocaleMap != null) {
      result = _deepMergeMaps(fallbackLocaleMap!, result);
    }
    return Future.value(result);
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
