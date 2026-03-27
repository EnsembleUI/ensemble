import 'dart:ui';

import 'package:ensemble/framework/definition_providers/cdn_provider.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}

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
