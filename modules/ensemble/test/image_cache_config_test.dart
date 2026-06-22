import 'package:ensemble/framework/theme/theme_manager.dart';
import 'package:ensemble/widget/image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:yaml/yaml.dart';

class _FakePathProvider extends PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async => '/tmp';

  @override
  Future<String?> getApplicationSupportPath() async => '/tmp';

  @override
  Future<String?> getApplicationDocumentsPath() async => '/tmp';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    PathProviderPlatform.instance = _FakePathProvider();
  });

  tearDown(() => ImageCacheConfig().reset());

  group('ImageCacheConfig', () {
    test('configure applies positive stalePeriodMinutes and maxObjects', () {
      ImageCacheConfig().configure(
        stalePeriodMinutes: 120,
        maxObjects: 300,
      );

      expect(ImageCacheConfig().stalePeriodMinutes, 120);
      expect(ImageCacheConfig().maxObjects, 300);
      expect(ImageCacheConfig().isInitialized, isTrue);
    });

    test('configure ignores non-positive values and keeps defaults', () {
      ImageCacheConfig().configure(
        stalePeriodMinutes: 0,
        maxObjects: -1,
      );

      expect(
        ImageCacheConfig().stalePeriodMinutes,
        ImageCacheConfig.defaultStalePeriodMinutes,
      );
      expect(
        ImageCacheConfig().maxObjects,
        ImageCacheConfig.defaultMaxObjects,
      );
      expect(ImageCacheConfig().isInitialized, isTrue);
    });

    test('reset restores defaults and clears initialized flag', () {
      ImageCacheConfig().configure(
        stalePeriodMinutes: 60,
        maxObjects: 100,
      );

      ImageCacheConfig().reset();

      expect(
        ImageCacheConfig().stalePeriodMinutes,
        ImageCacheConfig.defaultStalePeriodMinutes,
      );
      expect(
        ImageCacheConfig().maxObjects,
        ImageCacheConfig.defaultMaxObjects,
      );
      expect(ImageCacheConfig().isInitialized, isFalse);
    });
  });

  group('ThemeManager imageCache integration', () {
    test('getAppTheme configures cache from App.imageCache', () {
      final overrides = YamlMap.wrap({
        'App': {
          'imageCache': {
            'stalePeriodMinutes': 10080,
            'maxObjects': 500,
          },
        },
      });

      ThemeManager().getAppTheme(overrides);

      expect(ImageCacheConfig().stalePeriodMinutes, 10080);
      expect(ImageCacheConfig().maxObjects, 500);
      expect(ImageCacheConfig().isInitialized, isTrue);
    });

    test('getAppTheme leaves cache defaults when imageCache is absent', () {
      ImageCacheConfig().reset();

      ThemeManager().getAppTheme(YamlMap.wrap({}));

      expect(ImageCacheConfig().isInitialized, isFalse);
      expect(
        ImageCacheConfig().stalePeriodMinutes,
        ImageCacheConfig.defaultStalePeriodMinutes,
      );
    });

    test('getAppTheme ignores invalid imageCache values', () {
      final overrides = YamlMap.wrap({
        'App': {
          'imageCache': {
            'stalePeriodMinutes': 0,
            'maxObjects': -5,
          },
        },
      });

      ThemeManager().getAppTheme(overrides);

      expect(ImageCacheConfig().isInitialized, isFalse);
    });
  });
}
