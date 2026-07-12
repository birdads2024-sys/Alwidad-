import 'package:hive_ce_flutter/hive_ce_flutter.dart';

class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  Box? _cacheBox;

  Future<void> init() async {
    _cacheBox = await Hive.openBox('app_cache');
  }

  Future<void> cacheData(String key, dynamic value) async {
    if (_cacheBox == null) await init();
    await _cacheBox!.put(key, value);
  }

  dynamic getCachedData(String key) {
    if (_cacheBox == null) return null;
    return _cacheBox!.get(key);
  }

  Future<void> clearCache() async {
    if (_cacheBox == null) await init();
    await _cacheBox!.clear();
  }

  Future<void> remove(String key) async {
    if (_cacheBox == null) await init();
    await _cacheBox!.delete(key);
  }
}
