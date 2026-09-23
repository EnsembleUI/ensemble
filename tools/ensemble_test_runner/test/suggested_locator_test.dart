import 'package:ensemble_test_runner/mocks/test_api_provider_overlay.dart';
import 'package:ensemble_test_runner/mocks/test_logger.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:ensemble_test_runner/session/actions/test_action.dart';
import 'package:ensemble_test_runner/session/local/local_execution_session.dart';
import 'package:ensemble_test_runner/session/local/widget_locator_id.dart';
import 'package:ensemble_test_runner/session/observation/observation_options.dart';
import 'package:ensemble_test_runner/session/observation/suggested_locator.dart';
import 'package:ensemble_test_runner/session/observation/ui_element.dart';
import 'package:ensemble_test_runner/session/session_capabilities.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

EnsembleTestContext _ctx(String id) => EnsembleTestContext(
      testCase: EnsembleTestCase(id: id, steps: const []),
      apiOverlay: TestApiProviderOverlay(mocks: const {}),
      logger: TestLogger(),
      setup: const EnsembleTestSetup(),
    );

EnsembleTestHarness _harness() => EnsembleTestHarness(
      appPath: 'unused/',
      appHome: 'Home',
    );

List<UiElement> _flatten(List<UiElement> roots) {
  final out = <UiElement>[];
  void walk(UiElement e) {
    out.add(e);
    for (final child in e.children) {
      walk(child);
    }
  }

  for (final root in roots) {
    walk(root);
  }
  return out;
}

void main() {
  test('formatSuggestedSelector prefers id then label/text + role', () {
    expect(
      formatSuggestedSelector(const ElementLocator(id: 'login_test_token')),
      'id=login_test_token',
    );
    expect(
      formatSuggestedSelector(
        const ElementLocator(label: 'Log in', role: 'button'),
      ),
      'label="Log in", role=button',
    );
    expect(
      formatSuggestedSelector(
        const ElementLocator(text: 'Submit', role: 'button'),
      ),
      'text="Submit", role=button',
    );
    expect(
      formatSuggestedSelector(
        const ElementLocator(label: 'Say "hi"', role: 'button'),
      ),
      r'label="Say \"hi\"", role=button',
    );
  });

  testWidgets('enrichSuggestedLocators prefers unique id', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ElevatedButton(
            key: const ValueKey('login_test_token'),
            onPressed: () {},
            child: const Text('Login with test token'),
          ),
        ),
      ),
    );

    final session = LocalTestExecutionSession.attach(
      tester: tester,
      harness: _harness(),
      context: _ctx('locator_id'),
      permissions: SessionPermissions.restrictedUi,
    );
    addTearDown(session.close);

    final obs = await session.observe(
      options: const ObservationOptions(
        synchronization: ObservationSynchronization.immediate,
      ),
    );
    final enriched = enrichSuggestedLocators(
      observation: obs,
      resolver: session.resolver,
      registry: session.registry,
    );
    final button = _flatten(enriched.elements).firstWhere(
      (e) => e.testId == 'login_test_token',
    );
    expect(button.suggestedLocator?.id, 'login_test_token');
    expect(button.locatorWarning, isNull);
    expect(
      formatSuggestedSelector(button.suggestedLocator!),
      'id=login_test_token',
    );
  });

  testWidgets('enrichSuggestedLocators warns on ambiguous duplicates',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ElevatedButton(
                onPressed: () {},
                child: const Text('Dup'),
              ),
              ElevatedButton(
                onPressed: () {},
                child: const Text('Dup'),
              ),
            ],
          ),
        ),
      ),
    );

    final session = LocalTestExecutionSession.attach(
      tester: tester,
      harness: _harness(),
      context: _ctx('locator_ambiguous'),
      permissions: SessionPermissions.restrictedUi,
    );
    addTearDown(session.close);

    final obs = await session.observe(
      options: const ObservationOptions(
        synchronization: ObservationSynchronization.immediate,
      ),
    );
    final enriched = enrichSuggestedLocators(
      observation: obs,
      resolver: session.resolver,
      registry: session.registry,
    );
    final buttons = _flatten(enriched.elements)
        .where((e) => (e.type ?? '').toLowerCase() == 'button')
        .toList();
    expect(buttons, isNotEmpty);
    for (final button in buttons) {
      expect(button.suggestedLocator, isNull);
      expect(
        button.locatorWarning,
        anyOf(
          contains('Ambiguous'),
          equals('No stable locator available'),
        ),
      );
    }
  });

  testWidgets('observer reports Invokable YAML id without ValueKey',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _InvokableHost(
            id: 'rgUrl',
            child: TextField(
              controller: TextEditingController(),
            ),
          ),
        ),
      ),
    );

    final session = LocalTestExecutionSession.attach(
      tester: tester,
      harness: _harness(),
      context: _ctx('locator_invokable_id'),
      permissions: SessionPermissions.restrictedUi,
    );
    addTearDown(session.close);

    final obs = await session.observe(
      options: const ObservationOptions(
        synchronization: ObservationSynchronization.immediate,
      ),
    );
    final inputs = _flatten(obs.elements)
        .where((e) => (e.type ?? '').toLowerCase() == 'textinput')
        .toList();
    expect(inputs, isNotEmpty);
    expect(inputs.any((e) => e.testId == 'rgUrl'), isTrue);
  });

  testWidgets(
      'finderForId matches once when ValueKey and Invokable share an id',
      (tester) async {
    // Ensemble orientation: Invokable host, KeyedSubtree(testId) inside build.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _InvokableHost(
            id: 'extenderName',
            child: KeyedSubtree(
              key: const ValueKey('extenderName'),
              child: TextField(
                controller: TextEditingController(),
              ),
            ),
          ),
        ),
      ),
    );

    final matches = finderForLocatorId('extenderName').evaluate();
    expect(matches, hasLength(1));
    expect(matches.single.widget, isA<KeyedSubtree>());
  });

  testWidgets(
      'finderForId uses ValueKey only — ignores Invokable without a key',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _InvokableHost(
            id: 'rgUrl',
            child: TextField(
              controller: TextEditingController(),
            ),
          ),
        ),
      ),
    );

    // Steps wait for KeyedSubtree(testId); bare Invokable must not match early.
    expect(finderForLocatorId('rgUrl').evaluate(), isEmpty);

    // Observe still surfaces YAML id via Invokable for inspect-ui.
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      harness: _harness(),
      context: _ctx('locator_invokable_observe'),
      permissions: SessionPermissions.restrictedUi,
    );
    addTearDown(session.close);
    final obs = await session.observe(
      options: const ObservationOptions(
        synchronization: ObservationSynchronization.immediate,
      ),
    );
    expect(
      _flatten(obs.elements).any((e) => e.testId == 'rgUrl'),
      isTrue,
    );
  });

  testWidgets(
      'testId ValueKey is what finders resolve',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: _InvokableHost(
            id: 'emailInput',
            child: KeyedSubtree(
              key: const ValueKey('login_field'),
              child: TextField(
                controller: TextEditingController(),
              ),
            ),
          ),
        ),
      ),
    );

    expect(finderForLocatorId('login_field').evaluate(), hasLength(1));
    expect(finderForLocatorId('emailInput').evaluate(), isEmpty);
  });

  testWidgets('enrichSuggestedLocators prefers id over label+role',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Semantics(
            label: 'Device Type',
            button: true,
            child: DropdownButton<String>(
              key: const ValueKey('deviceTypeSelector'),
              value: 'HGW_SAH',
              items: const [
                DropdownMenuItem(value: 'HGW_SAH', child: Text('HGW_SAH')),
                DropdownMenuItem(value: 'FWA_ARC', child: Text('FWA_ARC')),
              ],
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    final session = LocalTestExecutionSession.attach(
      tester: tester,
      harness: _harness(),
      context: _ctx('locator_id_over_label'),
      permissions: SessionPermissions.restrictedUi,
    );
    addTearDown(session.close);

    final obs = await session.observe(
      options: const ObservationOptions(
        synchronization: ObservationSynchronization.immediate,
      ),
    );
    final enriched = enrichSuggestedLocators(
      observation: obs,
      resolver: session.resolver,
      registry: session.registry,
    );
    final dropdown = _flatten(enriched.elements).firstWhere(
      (e) => e.testId == 'deviceTypeSelector',
    );
    expect(dropdown.suggestedLocator?.id, 'deviceTypeSelector');
    expect(dropdown.suggestedLocator?.label, isNull);
    expect(dropdown.locatorWarning, isNull);
    expect(
      formatSuggestedSelector(dropdown.suggestedLocator!),
      'id=deviceTypeSelector',
    );
  });

  testWidgets('enrichSuggestedLocators marks unlabeled icons unavailable',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IconButton(
            icon: const Icon(Icons.star),
            onPressed: () {},
          ),
        ),
      ),
    );

    final session = LocalTestExecutionSession.attach(
      tester: tester,
      harness: _harness(),
      context: _ctx('locator_icon'),
      permissions: SessionPermissions.restrictedUi,
    );
    addTearDown(session.close);

    final obs = await session.observe(
      options: const ObservationOptions(
        synchronization: ObservationSynchronization.immediate,
      ),
    );
    final enriched = enrichSuggestedLocators(
      observation: obs,
      resolver: session.resolver,
      registry: session.registry,
    );
    final icons = _flatten(enriched.elements)
        .where((e) => (e.type ?? '').toLowerCase() == 'icon')
        .toList();
    expect(icons, isNotEmpty);
    for (final icon in icons) {
      expect(icon.testId, isNull);
      expect(icon.suggestedLocator, isNull);
      expect(icon.locatorWarning, 'No stable locator available');
    }
  });

  testWidgets(
    'adjacent text nodes get distinct text= selectors, not a merged label',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MergeSemantics(
              child: const Column(
                children: [
                  Text('Wifi naam'),
                  Text('KPN'),
                ],
              ),
            ),
          ),
        ),
      );

      final session = LocalTestExecutionSession.attach(
        tester: tester,
        harness: _harness(),
        context: _ctx('merged_text_label'),
        permissions: SessionPermissions.restrictedUi,
      );
      addTearDown(session.close);

      final obs = await session.observe(
        options: const ObservationOptions(
          synchronization: ObservationSynchronization.immediate,
        ),
      );
      final enriched = enrichSuggestedLocators(
        observation: obs,
        resolver: session.resolver,
        registry: session.registry,
      );
      final texts = _flatten(enriched.elements)
          .where((e) => (e.type ?? '').toLowerCase() == 'text')
          .toList();
      final wifi = texts.firstWhere((e) => e.text == 'Wifi naam');
      final kpn = texts.firstWhere((e) => e.text == 'KPN');
      expect(wifi.suggestedLocator?.text, 'Wifi naam');
      expect(wifi.suggestedLocator?.label, isNull);
      expect(kpn.suggestedLocator?.text, 'KPN');
      expect(kpn.suggestedLocator?.label, isNull);
      expect(
        formatSuggestedSelector(wifi.suggestedLocator!),
        contains('text="Wifi naam"'),
      );
      expect(
        formatSuggestedSelector(kpn.suggestedLocator!),
        contains('text="KPN"'),
      );
    },
  );
}

class _InvokableHost extends StatefulWidget with Invokable {
  _InvokableHost({required String id, required this.child}) {
    this.id = id;
  }

  final Widget child;

  @override
  Map<String, Function> getters() => {};

  @override
  Map<String, Function> setters() => {};

  @override
  Map<String, Function> methods() => {};

  @override
  State<_InvokableHost> createState() => _InvokableHostState();
}

class _InvokableHostState extends State<_InvokableHost> {
  @override
  Widget build(BuildContext context) => widget.child;
}
