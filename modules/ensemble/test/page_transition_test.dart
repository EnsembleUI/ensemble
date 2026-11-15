import 'package:ensemble/framework/theme/theme_manager.dart';
import 'package:ensemble/layout/ensemble_page_route.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

EnsemblePageRouteBuilder<void> _route(PageTransitionType type,
        {bool? opaque}) =>
    EnsemblePageRouteBuilder<void>(
      child: const SizedBox(),
      transitionType: type,
      alignment: Alignment.center,
      opaque: opaque,
    );

void main() {
  group('default page transitions', () {
    test('Ensemble theme pins the pre-Flutter-3.38 builders', () {
      final builders =
          ThemeManager().getAppTheme(null).pageTransitionsTheme.builders;
      expect(builders[TargetPlatform.android],
          isA<ZoomPageTransitionsBuilder>());
      expect(builders[TargetPlatform.iOS],
          isA<CupertinoPageTransitionsBuilder>());
      expect(builders[TargetPlatform.macOS],
          isA<CupertinoPageTransitionsBuilder>());
    });

    test('theme overrides keep the pinned default', () {
      final overrides =
          loadYaml('Colors:\n  primary: 0xFF123456\n') as YamlMap;
      expect(
          ThemeManager()
              .getAppTheme(overrides)
              .pageTransitionsTheme
              .builders[TargetPlatform.android],
          isA<ZoomPageTransitionsBuilder>());
    });
  });

  group('PageTransitionTypeX.fromString', () {
    test('unset type resolves to theme', () {
      expect(PageTransitionTypeX.fromString(null), PageTransitionType.theme);
    });

    test('parses predictiveBack', () {
      expect(PageTransitionTypeX.fromString('predictiveBack'),
          PageTransitionType.predictiveBack);
    });
  });

  group('EnsemblePageRouteBuilder opacity', () {
    test('existing transition types stay non-opaque', () {
      for (final type in PageTransitionType.values
          .where((t) => t != PageTransitionType.predictiveBack)) {
        expect(_route(type).opaque, isFalse, reason: type.name);
      }
    });

    test('predictiveBack routes are opaque', () {
      expect(_route(PageTransitionType.predictiveBack).opaque, isTrue);
    });

    test('explicit opaque wins (modal routes)', () {
      expect(
          _route(PageTransitionType.predictiveBack, opaque: false).opaque,
          isFalse);
    });
  });

  group('transition builder selection', () {
    Future<void> pushTwoRoutes(
      WidgetTester tester, {
      required TargetPlatform platform,
      required PageTransitionType type,
    }) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navigatorKey,
        theme: ThemeData(
          platform: platform,
          pageTransitionsTheme: ensembleDefaultPageTransitionsTheme,
        ),
        home: const Text('home'),
      ));
      navigatorKey.currentState!.push(EnsemblePageRouteBuilder<void>(
        child: const Text('second'),
        transitionType: type,
        alignment: Alignment.center,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('theme type uses Zoom on Android', (tester) async {
      await pushTwoRoutes(tester,
          platform: TargetPlatform.android, type: PageTransitionType.theme);
      expect(
          find.byWidgetPredicate(
              (w) => w.runtimeType.toString() == '_ZoomPageTransition'),
          findsWidgets);
      await tester.pumpAndSettle();
    });

    testWidgets('predictiveBack uses the predictive-back builder on Android',
        (tester) async {
      await pushTwoRoutes(tester,
          platform: TargetPlatform.android,
          type: PageTransitionType.predictiveBack);
      expect(
          find.byWidgetPredicate(
              (w) => w.runtimeType.toString() == '_PredictiveBackGestureDetector'),
          findsWidgets);
      await tester.pumpAndSettle();
    });

    testWidgets('predictiveBack falls back to the theme on iOS',
        (tester) async {
      await pushTwoRoutes(tester,
          platform: TargetPlatform.iOS,
          type: PageTransitionType.predictiveBack);
      expect(find.byType(CupertinoPageTransition), findsWidgets);
      await tester.pumpAndSettle();
    });
  });
}
