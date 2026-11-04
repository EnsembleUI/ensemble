import 'dart:io';

import 'package:ensemble/framework/storage_manager.dart';
import 'package:ensemble/framework/tv/apple_tv.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Apple TV keeps both storage boxes in Caches, not Documents', () async {
    final documents = await Directory.systemTemp.createTemp('ensemble-docs-');
    final caches = await Directory.systemTemp.createTemp('ensemble-caches-');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      return call.method == 'getApplicationCacheDirectory'
          ? caches.path
          : documents.path;
    });
    debugIsAppleTVOverride = true;
    try {
      final storage = StorageManager();
      await storage.init();
      await storage.write('apple_tv_key', 'value');
      await storage.writeToSystemStorage('apple_tv_system_key', true);
      await GetStorage().queue.add(() async {});
      await GetStorage('system').queue.add(() async {});

      expect(File('${caches.path}/GetStorage.gs').readAsStringSync(),
          contains('apple_tv_key'));
      expect(File('${caches.path}/system.gs').readAsStringSync(),
          contains('apple_tv_system_key'));
      expect(documents.listSync(), isEmpty);
      expect(storage.read('apple_tv_key'), 'value');
    } finally {
      debugIsAppleTVOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      await documents.delete(recursive: true);
      await caches.delete(recursive: true);
    }
  });
}
