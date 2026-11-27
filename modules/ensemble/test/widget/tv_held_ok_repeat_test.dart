import 'package:ensemble/action/bottom_sheet_actions.dart';
import 'package:ensemble/action/dialog_actions.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/definition_providers/provider.dart';
import 'package:ensemble/framework/device.dart';
import 'package:ensemble/framework/scope.dart';
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

  /// Same layering as an embedded Ensemble screen: host Shortcuts (which
  /// accept repeats) around a MaterialApp, guard around the content.
  Widget app(Widget home) => Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
        },
        child: MaterialApp(
          home: Material(child: TVFocusWidget.blockHeldActivation(home)),
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
  /// guard of its own: the Ensemble content under test must bring it.
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
