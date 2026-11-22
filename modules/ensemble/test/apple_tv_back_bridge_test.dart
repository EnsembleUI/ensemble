import 'package:ensemble/framework/tv/apple_tv.dart';
import 'package:ensemble/framework/tv/apple_tv_back_bridge.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pushes a second route whose focused widget answers `goBack` key events
/// with [onKey], then returns the events it saw.
Future<List<KeyEvent>> _pumpSecondRoute(
  WidgetTester tester,
  KeyEventResult Function(KeyEvent event) onKey,
) async {
  final seen = <KeyEvent>[];
  final navigatorKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(MaterialApp(
    navigatorKey: navigatorKey,
    home: const Text('first'),
  ));
  navigatorKey.currentState!.push(MaterialPageRoute<void>(
    builder: (_) => Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event.logicalKey != LogicalKeyboardKey.goBack) {
          return KeyEventResult.ignored;
        }
        seen.add(event);
        return onKey(event);
      },
      child: const Text('second'),
    ),
  ));
  await tester.pumpAndSettle();
  return seen;
}

Future<void> _pressMenu(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() {
    AppleTVBackBridge.debugUninstall();
    debugIsAppleTVOverride = null;
  });

  group('on Apple TV', () {
    setUp(() {
      debugIsAppleTVOverride = true;
      AppleTVBackBridge.install();
    });

    testWidgets('a handled key-up stops the system Back', (tester) async {
      final seen = await _pumpSecondRoute(
        tester,
        (_) => KeyEventResult.handled,
      );

      await _pressMenu(tester);

      expect(seen.map((e) => e.runtimeType), [KeyDownEvent, KeyUpEvent]);
      expect(find.text('second'), findsOneWidget);
    });

    testWidgets('a handled key-down with an ignored key-up still pops',
        (tester) async {
      // Same as Android TV: the key-up decides.
      final seen = await _pumpSecondRoute(
        tester,
        (e) =>
            e is KeyDownEvent ? KeyEventResult.handled : KeyEventResult.ignored,
      );

      await _pressMenu(tester);

      expect(seen.map((e) => e.runtimeType), [KeyDownEvent, KeyUpEvent]);
      expect(find.text('first'), findsOneWidget);
      expect(find.text('second'), findsNothing);
    });

    testWidgets('unhandled Back pops the route', (tester) async {
      final seen = await _pumpSecondRoute(
        tester,
        (_) => KeyEventResult.ignored,
      );

      await _pressMenu(tester);

      expect(seen, hasLength(2));
      expect(find.text('first'), findsOneWidget);
    });

    testWidgets('leaves no key marked as pressed', (tester) async {
      await _pumpSecondRoute(tester, (_) => KeyEventResult.handled);

      await _pressMenu(tester);

      expect(HardwareKeyboard.instance.physicalKeysPressed, isEmpty);
    });

    testWidgets('install twice registers one listener', (tester) async {
      AppleTVBackBridge.install();
      final seen = await _pumpSecondRoute(
        tester,
        (_) => KeyEventResult.handled,
      );

      await _pressMenu(tester);

      expect(seen, hasLength(2));
    });
  });

  testWidgets('does nothing outside Apple TV', (tester) async {
    debugIsAppleTVOverride = false;
    AppleTVBackBridge.install();
    final seen = await _pumpSecondRoute(
      tester,
      (_) => KeyEventResult.handled,
    );

    await _pressMenu(tester);

    expect(seen, isEmpty);
    expect(find.text('first'), findsOneWidget);
  });
}
