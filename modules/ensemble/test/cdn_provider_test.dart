import 'dart:ui';

import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/definition_providers/cdn_provider.dart';
import 'package:ensemble/framework/definition_providers/provider.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('cdnShouldFetchManifest', () {
    test('fetches when remote timestamp is unknown or local is unset', () {
      expect(
        cdnShouldFetchManifest(
          localLastUpdatedAt: 100,
          remoteLastUpdatedAt: null,
        ),
        isTrue,
      );
      expect(
        cdnShouldFetchManifest(
          localLastUpdatedAt: null,
          remoteLastUpdatedAt: 200,
        ),
        isTrue,
      );
    });

    test('fetches only when remote timestamp is newer', () {
      expect(
        cdnShouldFetchManifest(
          localLastUpdatedAt: 100,
          remoteLastUpdatedAt: 200,
        ),
        isTrue,
      );
      expect(
        cdnShouldFetchManifest(
          localLastUpdatedAt: 200,
          remoteLastUpdatedAt: 200,
        ),
        isFalse,
      );
      expect(
        cdnShouldFetchManifest(
          localLastUpdatedAt: 300,
          remoteLastUpdatedAt: 200,
        ),
        isFalse,
      );
    });
  });

  group('CDN lastUpdatedAt commit', () {
    test('does not advance local timestamp until manifest fetch succeeds',
        () async {
      final provider = CdnDefinitionProvider('test-app');
      expect(provider.lastUpdatedAtForTesting, isNull);

      expect(
        cdnShouldFetchManifest(
          localLastUpdatedAt: provider.lastUpdatedAtForTesting,
          remoteLastUpdatedAt: 500,
        ),
        isTrue,
      );
      expect(provider.lastUpdatedAtForTesting, isNull);

      provider.commitRemoteLastUpdatedAtForTesting(500);
      expect(provider.lastUpdatedAtForTesting, 500);

      expect(
        cdnShouldFetchManifest(
          localLastUpdatedAt: provider.lastUpdatedAtForTesting,
          remoteLastUpdatedAt: 500,
        ),
        isFalse,
      );
    });
  });

  group('CDN User-Agent', () {
    test('cdnUserAgent formats Ensemble version, platform, and app name', () {
      expect(
        CdnDefinitionProvider.cdnUserAgent(
          version: '1.2.44',
          platform: 'android',
          appName: 'ensemble_live',
        ),
        'Ensemble/1.2.44 (android; ensemble_live)',
      );
    });

    test('cdnUserAgent omits empty app name', () {
      expect(
        CdnDefinitionProvider.cdnUserAgent(
          version: '1.2.44',
          platform: 'ios',
          appName: '',
        ),
        'Ensemble/1.2.44 (ios)',
      );
    });

    test('cdnAppVersion formats version and build number', () {
      expect(
        CdnDefinitionProvider.cdnAppVersion(
          version: '1.2.3',
          buildNumber: '32',
        ),
        '1.2.3+32',
      );
    });

    test('cdnEnsembleHeaders includes Ensemble metadata headers', () {
      expect(
        CdnDefinitionProvider.cdnEnsembleHeaders(
          appId: 'e24402cb-75e2-404c-866c-29e6c3dd7992',
          runtimeVersion: '1.2.44',
          platform: 'android',
          appName: 'ensemble_live',
          appVersion: '1.2.3+32',
          userAgent: 'Ensemble/1.2.44 (android; ensemble_live)',
        ),
        {
          'User-Agent': 'Ensemble/1.2.44 (android; ensemble_live)',
          'X-Ensemble-App-Id': 'e24402cb-75e2-404c-866c-29e6c3dd7992',
          'X-Ensemble-Platform': 'android',
          'X-Ensemble-App-Name': 'ensemble_live',
          'X-Ensemble-App-Version': '1.2.3+32',
          'X-Ensemble-Runtime-Version': '1.2.44',
        },
      );
    });
  });

  group('CDN persisted cache tuple', () {
    test('cdnPersistedCacheEntry pairs manifest with snapshot metadata', () {
      expect(
        CdnDefinitionProvider.cdnPersistedCacheEntry(
          etag: 'etag-a',
          lastUpdatedAt: 42,
          manifestJson: '{"artifacts":{}}',
        ),
        ['etag-a', '42', '{"artifacts":{}}'],
      );
    });

    test('saveCachedState persists passed etag instead of later instance value',
        () async {
      const appId = 'snapshot-etag-app';
      const cacheKey = 'cdn_provider_state_$appId';
      SharedPreferences.setMockInitialValues({});

      final provider = CdnDefinitionProvider(appId);
      await provider.saveCachedStateForTesting(
        '{"manifest":"a"}',
        etag: 'etag-a',
        lastUpdatedAt: 100,
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(cacheKey), ['etag-a', '100', '{"manifest":"a"}']);

      await provider.saveCachedStateForTesting(
        '{"manifest":"b"}',
        etag: 'etag-b',
        lastUpdatedAt: 200,
      );
      expect(prefs.getStringList(cacheKey), ['etag-b', '200', '{"manifest":"b"}']);
    });
  });

  group('CDN cache invalidation', () {
    test('resets freshness metadata when persisted manifest is invalid',
        () async {
      const appId = 'corrupted-cache-app';
      const cacheKey = 'cdn_provider_state_$appId';
      SharedPreferences.setMockInitialValues({
        cacheKey: <String>['cached-etag', '12345', '{not valid json'],
      });

      final provider = CdnDefinitionProvider(appId);
      await provider.loadCachedStateForTesting();

      expect(provider.lastUpdatedAtForTesting, isNull);
      expect(provider.getSupportedLanguages(), isEmpty);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(cacheKey), isNull);
    });
  });

  group('CDN translation runtime refresh', () {
    testWidgets('picks up newly added translation keys without app restart',
        (tester) async {
      final provider = CdnDefinitionProvider('test-app');

      await provider.applyRuntimeManifestForTesting(_manifestWithoutNewKey());

      final tick = await _pumpTranslationApp(
        tester,
        provider: provider,
        locale: const Locale('en'),
        translationKey: 'greeting.new',
      );
      await tester.pumpAndSettle();

      expect(find.text('__missing__'), findsOneWidget);

      await provider.applyRuntimeManifestForTesting(_manifestWithNewKey());
      tick.value++;
      await tester.pumpAndSettle();

      // Regression expectation: translation should be immediately available
      // after runtime manifest refresh, without killing/restarting the app.
      expect(find.text('Hello from CDN'), findsOneWidget);
    });

    testWidgets('does not throw when runtime refresh has no app context',
        (tester) async {
      final provider = CdnDefinitionProvider('test-app');

      await expectLater(
        provider.applyRuntimeManifestForTesting(_manifestWithNewKey()),
        completes,
      );
    });

    testWidgets('resolves language fallback for locale with country code',
        (tester) async {
      final provider = CdnDefinitionProvider('test-app');
      await provider.applyRuntimeManifestForTesting(_manifestWithoutNewKey());

      final tick = await _pumpTranslationApp(
        tester,
        provider: provider,
        locale: const Locale('en', 'US'),
        translationKey: 'greeting.new',
        supportedLocales: const [Locale('en', 'US')],
      );
      await tester.pumpAndSettle();
      expect(find.text('__missing__'), findsOneWidget);

      await provider.applyRuntimeManifestForTesting(_manifestWithNewKey());
      tick.value++;
      await tester.pumpAndSettle();

      expect(find.text('Hello from CDN'), findsOneWidget);
    });

    testWidgets('falls back to default locale for missing current locale key',
        (tester) async {
      final provider = CdnDefinitionProvider('test-app');
      await provider
          .applyRuntimeManifestForTesting(_manifestDefaultFallbackInitial());

      final tick = await _pumpTranslationApp(
        tester,
        provider: provider,
        locale: const Locale('es'),
        translationKey: 'greeting.new',
        supportedLocales: const [Locale('es')],
      );
      await tester.pumpAndSettle();
      expect(find.text('__missing__'), findsOneWidget);

      await provider
          .applyRuntimeManifestForTesting(_manifestDefaultFallbackUpdated());
      tick.value++;
      await tester.pumpAndSettle();

      expect(find.text('Hello from default EN'), findsOneWidget);
    });

    testWidgets('applies pending translation updates on app resume',
        (tester) async {
      final provider = CdnDefinitionProvider('test-app');
      final config = EnsembleConfig(definitionProvider: provider);
      Ensemble().setEnsembleConfig(config);

      await provider.applyRuntimeManifestForTesting(
        _manifestWithArtifactRefresh(_manifestWithoutNewKey()),
      );
      await config.updateAppBundle();

      final tick = await _pumpTranslationApp(
        tester,
        provider: provider,
        locale: const Locale('en'),
        translationKey: 'greeting.new',
      );
      await tester.pumpAndSettle();
      expect(find.text('__missing__'), findsOneWidget);

      provider.rebuildManifestCacheForTesting(
        _manifestWithArtifactRefresh(_manifestWithNewKey()),
      );
      provider.hasPendingUpdateForTesting = true;

      provider.onAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      tick.value++;
      await tester.pumpAndSettle();

      expect(find.text('Hello from CDN'), findsOneWidget);
      expect(provider.hasPendingUpdateForTesting, isFalse);
    });

    testWidgets('updates changed value for existing translation key',
        (tester) async {
      final provider = CdnDefinitionProvider('test-app');
      await provider
          .applyRuntimeManifestForTesting(_manifestWithExistingInitialValue());

      final tick = await _pumpTranslationApp(
        tester,
        provider: provider,
        locale: const Locale('en'),
        translationKey: 'greeting.old',
      );
      await tester.pumpAndSettle();
      expect(find.text('Hello old'), findsOneWidget);

      await provider
          .applyRuntimeManifestForTesting(_manifestWithExistingUpdatedValue());
      tick.value++;
      await tester.pumpAndSettle();

      expect(find.text('Hello updated'), findsOneWidget);
    });
  });

  group('CDN stale refresh outcome', () {
    test('shouldApplyCdnStaleRefreshImmediately requires both flags', () {
      final provider = CdnDefinitionProvider('test-app');

      expect(
        provider.shouldApplyCdnStaleRefreshImmediately(
          artifactRefreshEnabled: true,
          hasEnsembleConfig: true,
        ),
        isTrue,
      );
      expect(
        provider.shouldApplyCdnStaleRefreshImmediately(
          artifactRefreshEnabled: false,
          hasEnsembleConfig: true,
        ),
        isFalse,
      );
      expect(
        provider.shouldApplyCdnStaleRefreshImmediately(
          artifactRefreshEnabled: true,
          hasEnsembleConfig: false,
        ),
        isFalse,
      );
    });

    test(
        'applyStaleRefreshOutcome syncs bundle immediately when refresh enabled',
        () async {
      final provider = CdnDefinitionProvider('test-app');
      final config = EnsembleConfig(definitionProvider: provider);
      Ensemble().setEnsembleConfig(config);

      await provider.applyRuntimeManifestForTesting(
        _manifestWithArtifactRefresh(_manifestWithResourceVersion('v1')),
      );
      await config.updateAppBundle();

      provider.rebuildManifestCacheForTesting(
        _manifestWithArtifactRefresh(_manifestWithResourceVersion('v2')),
      );

      await provider.applyStaleRefreshOutcomeForTesting();

      expect(provider.hasPendingUpdateForTesting, isFalse);
      expect(
        config.getResources()?[ResourceArtifactEntry.Scripts.name]['version'],
        'v2',
      );
    });

    test('applyStaleRefreshOutcome defers when artifact refresh is disabled',
        () async {
      final provider = CdnDefinitionProvider('test-app');
      final config = EnsembleConfig(definitionProvider: provider);
      Ensemble().setEnsembleConfig(config);

      await provider.applyRuntimeManifestForTesting(
        _manifestWithResourceVersion('v1'),
      );
      await config.updateAppBundle();

      provider.rebuildManifestCacheForTesting(_manifestWithResourceVersion('v2'));

      await provider.applyStaleRefreshOutcomeForTesting();

      expect(provider.hasPendingUpdateForTesting, isTrue);
      expect(
        config.getResources()?[ResourceArtifactEntry.Scripts.name]['version'],
        'v1',
      );
    });
  });

  group('CDN pending update ordering', () {
    test('handlePendingUpdate syncs app bundle from CDN cache and fires refresh',
        () async {
      final provider = CdnDefinitionProvider('test-app');
      final config = EnsembleConfig(definitionProvider: provider);
      Ensemble().setEnsembleConfig(config);

      await provider.applyRuntimeManifestForTesting(
        _manifestWithResourceVersion('v1'),
      );
      await config.updateAppBundle();

      expect(
        config.getResources()?[ResourceArtifactEntry.Scripts.name]['version'],
        'v1',
      );

      provider.rebuildManifestCacheForTesting(
        _manifestWithResourceVersion('v2'),
      );
      provider.hasPendingUpdateForTesting = true;

      await provider.handlePendingUpdateForTesting();

      expect(
        config.getResources()?[ResourceArtifactEntry.Scripts.name]['version'],
        'v2',
      );
      expect(provider.hasPendingUpdateForTesting, isFalse);
    });
  });
}

Map<String, dynamic> _manifestWithArtifactRefresh(Map<String, dynamic> manifest) {
  final artifacts =
      Map<String, dynamic>.from(manifest['artifacts'] as Map<String, dynamic>);
  final config =
      Map<String, dynamic>.from(artifacts['config'] as Map? ?? <String, dynamic>{});
  final envVariables = Map<String, dynamic>.from(
      config['envVariables'] as Map? ?? <String, dynamic>{});
  envVariables['ENABLE_ARTIFACT_REFRESH'] = 'true';
  config['envVariables'] = envVariables;
  artifacts['config'] = config;
  return {'artifacts': artifacts};
}

Map<String, dynamic> _manifestWithResourceVersion(String version) => {
      'artifacts': {
        'config': <String, dynamic>{},
        'screens': <dynamic>[],
        'theme': '',
        'widgets': <String, dynamic>{},
        'scripts': <String, dynamic>{
          'version': version,
        },
        'actions': <dynamic>[],
        'translations': <dynamic>[],
      }
    };

Future<ValueNotifier<int>> _pumpTranslationApp(
  WidgetTester tester, {
  required CdnDefinitionProvider provider,
  required Locale locale,
  required String translationKey,
  List<Locale>? supportedLocales,
}) async {
  final tick = ValueNotifier<int>(0);
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: Utils.globalAppKey,
      locale: locale,
      supportedLocales: supportedLocales ?? [locale],
      localizationsDelegates: [
        provider.getI18NDelegate()!,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: ValueListenableBuilder<int>(
        valueListenable: tick,
        builder: (_, __, ___) => Text(
          FlutterI18n.translate(
            Utils.globalAppKey.currentContext!,
            translationKey,
            fallbackKey: '__missing__',
          ),
          textDirection: TextDirection.ltr,
        ),
      ),
    ),
  );
  return tick;
}

Map<String, dynamic> _manifestWithoutNewKey() => {
      'artifacts': {
        'config': <String, dynamic>{},
        'screens': <dynamic>[],
        'theme': '',
        'widgets': <String, dynamic>{},
        'scripts': <String, dynamic>{},
        'actions': <dynamic>[],
        'translations': [
          {
            'id': 'i18n_en',
            'defaultLocale': true,
            'content': '''
greeting:
  old: Hello old
''',
          }
        ],
      }
    };

Map<String, dynamic> _manifestWithNewKey() => {
      'artifacts': {
        'config': <String, dynamic>{},
        'screens': <dynamic>[],
        'theme': '',
        'widgets': <String, dynamic>{},
        'scripts': <String, dynamic>{},
        'actions': <dynamic>[],
        'translations': [
          {
            'id': 'i18n_en',
            'defaultLocale': true,
            'content': '''
greeting:
  old: Hello old
  new: Hello from CDN
''',
          }
        ],
      }
    };

Map<String, dynamic> _manifestDefaultFallbackInitial() => {
      'artifacts': {
        'config': <String, dynamic>{},
        'screens': <dynamic>[],
        'theme': '',
        'widgets': <String, dynamic>{},
        'scripts': <String, dynamic>{},
        'actions': <dynamic>[],
        'translations': [
          {
            'id': 'i18n_en',
            'defaultLocale': true,
            'content': '''
greeting:
  old: Hello old
''',
          },
          {
            'id': 'i18n_es',
            'defaultLocale': false,
            'content': '''
greeting:
  old: Hola viejo
''',
          }
        ],
      }
    };

Map<String, dynamic> _manifestDefaultFallbackUpdated() => {
      'artifacts': {
        'config': <String, dynamic>{},
        'screens': <dynamic>[],
        'theme': '',
        'widgets': <String, dynamic>{},
        'scripts': <String, dynamic>{},
        'actions': <dynamic>[],
        'translations': [
          {
            'id': 'i18n_en',
            'defaultLocale': true,
            'content': '''
greeting:
  old: Hello old
  new: Hello from default EN
''',
          },
          {
            'id': 'i18n_es',
            'defaultLocale': false,
            'content': '''
greeting:
  old: Hola viejo
''',
          }
        ],
      }
    };

Map<String, dynamic> _manifestWithExistingInitialValue() => {
      'artifacts': {
        'config': <String, dynamic>{},
        'screens': <dynamic>[],
        'theme': '',
        'widgets': <String, dynamic>{},
        'scripts': <String, dynamic>{},
        'actions': <dynamic>[],
        'translations': [
          {
            'id': 'i18n_en',
            'defaultLocale': true,
            'content': '''
greeting:
  old: Hello old
''',
          }
        ],
      }
    };

Map<String, dynamic> _manifestWithExistingUpdatedValue() => {
      'artifacts': {
        'config': <String, dynamic>{},
        'screens': <dynamic>[],
        'theme': '',
        'widgets': <String, dynamic>{},
        'scripts': <String, dynamic>{},
        'actions': <dynamic>[],
        'translations': [
          {
            'id': 'i18n_en',
            'defaultLocale': true,
            'content': '''
greeting:
  old: Hello updated
''',
          }
        ],
      }
    };
