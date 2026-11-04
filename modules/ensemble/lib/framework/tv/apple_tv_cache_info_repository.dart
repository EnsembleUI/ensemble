import 'package:ensemble/framework/tv/apple_tv.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Keeps a flutter_cache_manager database in Ensemble's Apple TV directory.
///
/// By default the database goes to Application Support, which a physical
/// Apple TV can't create, so every cached image fails there. The image files
/// themselves already go to tmp and need no change.
class AppleTVCacheInfoRepository implements CacheInfoRepository {
  AppleTVCacheInfoRepository(this.databaseName);

  final String databaseName;
  CacheObjectProvider? _provider;

  /// A repository for [databaseName] on Apple TV, or null elsewhere so the
  /// package keeps its per-platform default.
  static AppleTVCacheInfoRepository? forPlatform(String databaseName) =>
      isAppleTV ? AppleTVCacheInfoRepository(databaseName) : null;

  // CacheStore always awaits open() before any other call.
  CacheObjectProvider get _inner => _provider!;

  @override
  Future<bool> open() async {
    if (_provider == null) {
      final dir = await appleTVStorageDirectory();
      _provider = dir != null
          ? CacheObjectProvider(path: '${dir.path}/$databaseName.db')
          : CacheObjectProvider(databaseName: databaseName);
    }
    return _inner.open();
  }

  @override
  Future<bool> exists() async => _provider != null && await _inner.exists();

  @override
  Future<dynamic> updateOrInsert(CacheObject cacheObject) =>
      _inner.updateOrInsert(cacheObject);

  @override
  Future<CacheObject> insert(CacheObject cacheObject,
          {bool setTouchedToNow = true}) =>
      _inner.insert(cacheObject, setTouchedToNow: setTouchedToNow);

  @override
  Future<CacheObject?> get(String key) => _inner.get(key);

  @override
  Future<int> delete(int id) => _inner.delete(id);

  @override
  Future<int> deleteAll(Iterable<int> ids) => _inner.deleteAll(ids);

  @override
  Future<int> update(CacheObject cacheObject, {bool setTouchedToNow = true}) =>
      _inner.update(cacheObject, setTouchedToNow: setTouchedToNow);

  @override
  Future<List<CacheObject>> getAllObjects() => _inner.getAllObjects();

  @override
  Future<List<CacheObject>> getObjectsOverCapacity(int capacity) =>
      _inner.getObjectsOverCapacity(capacity);

  @override
  Future<List<CacheObject>> getOldObjects(Duration maxAge) =>
      _inner.getOldObjects(maxAge);

  @override
  Future<bool> close() => _provider?.close() ?? Future.value(true);

  @override
  Future<void> deleteDataFile() async => _provider?.deleteDataFile();
}
