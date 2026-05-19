import 'package:ensemble/framework/definition_providers/local_provider.dart';
import 'package:ensemble/framework/definition_providers/remote_provider.dart';
import 'package:ensemble/framework/widget/screen.dart';
import 'package:ensemble/page_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  /// When [isSafeRemoteScreenSelector] rejects the resolved screen id, both
  /// local (bundle) and remote (HTTP) providers must return the same empty
  /// definition they use for missing screens — without touching assets or the
  /// network. This locks in the path-traversal regression fix on the provider
  /// boundary, not only the pure helper.
  Future<void> assertBlockedSameAsEmpty(
    Future<ScreenDefinition> Function() load,
  ) async {
    final blocked = await load();
    final empty = ScreenDefinition(YamlMap());
    final blockedModel = blocked.getModel(null) as SinglePageModel;
    final emptyModel = empty.getModel(null) as SinglePageModel;
    expect(blockedModel.rootWidgetModel, emptyModel.rootWidgetModel);
  }

  group('LocalDefinitionProvider screen selector', () {
    const basePath = 'ensemble/';
    const safeHome = 'home';

    test('blocks traversal in screenId before reading the asset bundle', () {
      final provider = LocalDefinitionProvider(basePath, safeHome);
      return assertBlockedSameAsEmpty(
        () => provider.getDefinition(screenId: r'..%2fsecrets'),
      );
    });

    test('blocks traversal in screenName before reading the asset bundle', () {
      final provider = LocalDefinitionProvider(basePath, safeHome);
      return assertBlockedSameAsEmpty(
        () => provider.getDefinition(screenName: 'foo/bar'),
      );
    });

    test('blocks unsafe appHome when no screen override is passed', () {
      final provider = LocalDefinitionProvider(basePath, '../evil');
      return assertBlockedSameAsEmpty(() => provider.getDefinition());
    });
  });

  group('RemoteDefinitionProvider screen selector', () {
    const baseUrl = 'https://example.invalid/app/';
    const safeHome = 'home';

    test('blocks traversal in screenId before HTTP', () {
      final provider = RemoteDefinitionProvider(baseUrl, safeHome);
      return assertBlockedSameAsEmpty(
        () => provider.getDefinition(screenId: '../outside'),
      );
    });

    test('blocks traversal in screenName before HTTP', () {
      final provider = RemoteDefinitionProvider(baseUrl, safeHome);
      return assertBlockedSameAsEmpty(
        () => provider.getDefinition(screenName: r'a\b'),
      );
    });

    test('blocks unsafe appHome when no screen override is passed', () {
      final provider = RemoteDefinitionProvider(baseUrl, '..%2fcfg');
      return assertBlockedSameAsEmpty(() => provider.getDefinition());
    });
  });
}
