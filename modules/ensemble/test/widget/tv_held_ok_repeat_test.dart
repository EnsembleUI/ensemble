import 'package:ensemble/action/bottom_sheet_actions.dart';
import 'package:ensemble/action/dialog_actions.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/definition_providers/provider.dart';
import 'package:ensemble/framework/device.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/theme_manager.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/framework/tv/tv_focus_widget.dart';
import 'package:ensemble/framework/widget/screen.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// Holding OK on a TV remote sends one key-down, then repeats until key-up.
/// The focused control must activate once, while held arrows keep navigating.
void main() {
  tearDown(() => Device.debugOverrideIsTV(null));

  /// Host Shortcuts (which accept repeats) around a MaterialApp, with the
  /// helper around the tap target as the TV widget wrappers apply it.
  Widget app(Widget home) => Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
        },
        child: MaterialApp(
          home: Material(child: TVFocusWidget.blockHeldActivation(home, null)),
        ),
      );

  Future<void> hold(WidgetTester tester, LogicalKeyboardKey key,
      {int repeats = 3}) async {
    await tester.sendKeyDownEvent(key);
    for (var i = 0; i < repeats; i++) {
      await tester.sendKeyRepeatEvent(key);
      await tester.pump();
    }
    await tester.sendKeyUpEvent(key);
    await tester.pump();
  }

  Future<int> holdOnButton(WidgetTester tester, LogicalKeyboardKey key) async {
    var taps = 0;
    await tester.pumpWidget(app(InkWell(
      autofocus: true,
      splashFactory: NoSplash.splashFactory, // as Ensemble's TV InkWell
      onTap: () => taps++,
      child: const SizedBox(width: 100, height: 100),
    )));
    await tester.pump();
    await hold(tester, key);
    return taps;
  }

  testWidgets('held OK/Enter taps once on TV', (tester) async {
    Device.debugOverrideIsTV(true);
    expect(await holdOnButton(tester, LogicalKeyboardKey.select), 1);
    expect(await holdOnButton(tester, LogicalKeyboardKey.enter), 1);
  });

  testWidgets('held OK flips a Switch once on TV', (tester) async {
    Device.debugOverrideIsTV(true);
    var changes = 0;
    await tester.pumpWidget(app(StatefulBuilder(
      builder: (_, setState) => Switch(
        autofocus: true,
        value: changes.isOdd,
        onChanged: (_) => setState(() => changes++),
      ),
    )));
    await tester.pump();
    await hold(tester, LogicalKeyboardKey.select);
    expect(changes, 1);
  });

  testWidgets('off TV, held OK keeps Flutter default repeats', (tester) async {
    Device.debugOverrideIsTV(false);
    expect(await holdOnButton(tester, LogicalKeyboardKey.select), 4);
  });

  testWidgets('held arrow keeps moving focus on TV', (tester) async {
    Device.debugOverrideIsTV(true);
    final nodes = List.generate(3, (_) => FocusNode());
    addTearDown(() => nodes.forEach((n) => n.dispose()));

    await tester.pumpWidget(app(Row(
      children: [
        for (final node in nodes)
          InkWell(
            focusNode: node,
            autofocus: node == nodes.first,
            onTap: () {},
            child: const SizedBox(width: 100, height: 100),
          ),
      ],
    )));
    await tester.pump();
    expect(nodes.first.hasPrimaryFocus, isTrue);

    await hold(tester, LogicalKeyboardKey.arrowRight, repeats: 1);
    expect(nodes.last.hasPrimaryFocus, isTrue);
  });

  /// Host-style Shortcuts (accepting repeats) around a MaterialApp with no
  /// guard of its own: each Ensemble tap target's TV wrapper must bring it.
  Widget hostApp(Widget home) => Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
        },
        child: MaterialApp(
          navigatorKey: Utils.globalAppKey, // Ensemble pages read it
          theme: ThemeData(splashFactory: NoSplash.splashFactory),
          home: home,
        ),
      );

  const followCard = '''
Column:
  onTap:
    executeCode:
      body: taps.text = taps.text + "x";
  children:
    - Text:
        text: Follow
''';

  /// A page with a `taps` Text that [followCard] appends to.
  Future<ScopeManager> pumpPage(WidgetTester tester) async {
    late ScopeManager scope;
    await tester.pumpWidget(hostApp(Builder(builder: (context) {
      scope = ScopeManager(DataContext(buildContext: context), PageData());
      return DataScopeWidget(
          scopeManager: scope,
          child: Scaffold(body: scope.buildWidgetFromDefinition(loadYaml('''
Text:
  id: taps
  text: ""
'''))));
    })));
    return scope;
  }

  /// Holds OK on the "Follow" card and expects exactly one tap.
  Future<void> holdOnFollowTapsOnce(WidgetTester tester) async {
    Focus.of(tester.element(find.text('Follow'))).requestFocus();
    await tester.pump();
    await hold(tester, LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(find.text('x'), findsOneWidget);
  }

  testWidgets('held OK taps a card in an Ensemble dialog once on TV',
      (tester) async {
    Device.debugOverrideIsTV(true);
    final scope = await pumpPage(tester);
    await ShowDialogAction(body: loadYaml(followCard), dismissible: true)
        .execute(tester.element(find.byType(Scaffold)), scope);
    await tester.pumpAndSettle();
    await holdOnFollowTapsOnce(tester);
  });

  testWidgets('held OK taps a card in an Ensemble bottom sheet once on TV',
      (tester) async {
    Device.debugOverrideIsTV(true);
    final scope = await pumpPage(tester);
    await ShowBottomSheetAction(
            body: loadYaml(followCard), payload: <String, dynamic>{})
        .execute(tester.element(find.byType(Scaffold)), scope);
    await tester.pumpAndSettle();
    await holdOnFollowTapsOnce(tester);
  });

  testWidgets('held OK taps a card on an Ensemble screen once on TV',
      (tester) async {
    Device.debugOverrideIsTV(true);
    await tester.pumpWidget(hostApp(Screen(
      appProvider: AppProvider(definitionProvider: _ScreenProvider('''
View:
  body:
    Column:
      children:
        - Text:
            id: taps
            text: ""
        - Column:
            onTap:
              executeCode:
                body: taps.text = taps.text + "x";
            children:
              - Text:
                  text: Follow
''')),
      apiProviders: const {},
    )));
    await tester.pumpAndSettle();
    await holdOnFollowTapsOnce(tester);
  });

  /// Real Ensemble widgets in an Ensemble page, no guard of the test's own:
  /// each widget's TV wrapper must bring it. `taps` records activations.
  Future<void> pumpYaml(WidgetTester tester, String yaml,
      {String? theme}) async {
    await tester.pumpWidget(hostApp(Builder(builder: (context) {
      if (theme != null) {
        EnsembleThemeManager()
            .init(context, {'test': loadYaml(theme) as YamlMap}, 'test');
      }
      final scope =
          ScopeManager(DataContext(buildContext: context), PageData());
      return DataScopeWidget(
          scopeManager: scope,
          child: Scaffold(
              body: scope.buildWidgetFromDefinition(loadYaml(yaml))));
    })));
    await tester.pumpAndSettle();
  }

  /// Focuses the only focusable widget, holds OK and returns activations.
  Future<int> holdOnFirstFocusable(WidgetTester tester) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab); // focus first target
    await tester.pump();
    await hold(tester, LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    final taps = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .firstWhere((t) => t.startsWith('taps:'));
    return taps.length - 'taps:'.length;
  }

  const counter = """
        - Text:
            id: taps
            text: "taps:"
""";
  const tap = 'executeCode:\n  body: taps.text = taps.text + "x";';
  String column(String extraStyles) => """
Column:
  children:
$counter        - Column:
            onTap:
              executeCode:
                body: taps.text = taps.text + "x";
            styles:
              width: 100
              height: 50
$extraStyles            children:
              - Text:
                  text: Follow
""";

  group('widget-level tvOptions.allowSelectRepeat on TV', () {
    setUp(() => Device.debugOverrideIsTV(true));

    testWidgets('box without tvOptions activates once', (tester) async {
      await pumpYaml(tester, column(''));
      expect(await holdOnFirstFocusable(tester), 1);
    });

    testWidgets('box with a tvOptions row activates once', (tester) async {
      await pumpYaml(tester, column("""              tvOptions:
                row: 0
"""));
      expect(await holdOnFirstFocusable(tester), 1);
    });

    testWidgets('allowSelectRepeat: true keeps repeating', (tester) async {
      await pumpYaml(tester, column("""              tvOptions:
                allowSelectRepeat: true
"""));
      expect(await holdOnFirstFocusable(tester), 4);
    });

    testWidgets('Switch activates once', (tester) async {
      await pumpYaml(tester, """
Column:
  children:
$counter        - Switch:
            onChange:
              executeCode:
                body: taps.text = taps.text + "x";
""");
      expect(await holdOnFirstFocusable(tester), 1);
    });

    testWidgets('Icon onTap activates once', (tester) async {
      await pumpYaml(tester, """
Column:
  children:
$counter        - Icon:
            name: home
            onTap:
              executeCode:
                body: taps.text = taps.text + "x";
""");
      expect(await holdOnFirstFocusable(tester), 1);
    });

    testWidgets('ListView onItemTap activates once and is guarded',
        (tester) async {
      String list(String styles) => """
Column:
  children:
$counter        - ListView:
            styles:
              height: 100
$styles            onItemTap:
              executeCode:
                body: taps.text = taps.text + "x";
            item-template:
              data: [1]
              name: item
              template:
                Text:
                  text: item
""";
      // Tapping rebuilds the list (the item loses focus), so also count the
      // guard the option removes, as the tap count alone can't tell.
      final guard = find.byWidgetPredicate((w) =>
          w is Focus && w.canRequestFocus == false && w.onKeyEvent != null);
      await pumpYaml(tester, list(''));
      final withGuard = guard.evaluate().length;
      expect(await holdOnFirstFocusable(tester), 1);
      await pumpYaml(tester,
          list('              tvOptions: { allowSelectRepeat: true }\n'));
      expect(withGuard - guard.evaluate().length, 1, reason: 'one per item');
    });

    testWidgets('TabBar tabs get the guard unless allowSelectRepeat is set',
        (tester) async {
      // Re-activating the selected tab has no visible effect, so count the
      // guards (non-focusable Focus with a key handler) the option removes.
      final guard = find.byWidgetPredicate((w) =>
          w is Focus && w.canRequestFocus == false && w.onKeyEvent != null);
      String tabBar(String styles) => """
TabBar:
$styles  items:
    - label: One
      body: { Text: { text: one } }
    - label: Two
      body: { Text: { text: two } }
""";
      await pumpYaml(tester, tabBar(''));
      final withGuard = guard.evaluate().length;
      await pumpYaml(
          tester, tabBar('  styles: { tvOptions: { allowSelectRepeat: true } }\n'));
      expect(withGuard - guard.evaluate().length, 2, reason: 'one per tab');
    });

    const switchYaml = """
Column:
  children:
$counter        - Switch:
            onChange:
              executeCode:
                body: taps.text = taps.text + "x";
""";

    testWidgets('widget theme allowSelectRepeat: true is inherited',
        (tester) async {
      addTearDown(EnsembleThemeManager().reset);
      await pumpYaml(tester, switchYaml, theme: """
Styles:
  Switch:
    tvOptions:
      allowSelectRepeat: true
""");
      expect(await holdOnFirstFocusable(tester), 4);
    });

    testWidgets('explicit tvOptions overrides the widget theme',
        (tester) async {
      addTearDown(EnsembleThemeManager().reset);
      await pumpYaml(
          tester,
          switchYaml.replaceFirst('            onChange:',
              '            styles: { tvOptions: { allowSelectRepeat: false } }\n            onChange:'),
          theme: """
Styles:
  Switch:
    tvOptions:
      allowSelectRepeat: true
""");
      expect(await holdOnFirstFocusable(tester), 1);
    });

    testWidgets('held OK keeps D-pad navigation working', (tester) async {
      await pumpYaml(tester, """
Row:
  children:
$counter        - Column: { onTap: { executeCode: { body: 'taps.text = taps.text + "a";' } }, styles: { width: 80, height: 40 }, children: [ { Text: { text: A } } ] }
        - Column: { onTap: { executeCode: { body: 'taps.text = taps.text + "b";' } }, styles: { width: 80, height: 40 }, children: [ { Text: { text: B } } ] }
""");
      expect(await holdOnFirstFocusable(tester), 1);
      await hold(tester, LogicalKeyboardKey.arrowRight, repeats: 1);
      await hold(tester, LogicalKeyboardKey.select);
      await tester.pumpAndSettle();
      expect(find.text('taps:ab'), findsOneWidget);
    });
  });

  testWidgets('off TV, Ensemble taps keep Flutter default repeats',
      (tester) async {
    Device.debugOverrideIsTV(false);
    await pumpYaml(tester, column(''));
    expect(await holdOnFirstFocusable(tester), 4);
  });
}

/// Serves one inline screen definition.
class _ScreenProvider extends Fake implements DefinitionProvider {
  _ScreenProvider(this.yaml);
  final String yaml;

  @override
  Future<ScreenDefinition> getDefinition(
          {String? screenId, String? screenName}) async =>
      ScreenDefinition(loadYaml(yaml));
}
