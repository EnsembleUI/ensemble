import 'package:ensemble_test_runner/mocks/test_api_provider_overlay.dart';
import 'package:ensemble_test_runner/mocks/test_logger.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:ensemble_test_runner/session/local/local_execution_session.dart';
import 'package:ensemble_test_runner/session/observation/observation_options.dart';
import 'package:ensemble_test_runner/session/observation/ui_element.dart';
import 'package:ensemble_test_runner/session/session_capabilities.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'observe keeps one logical control per Text / TextField / button',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const Text('Hello', key: ValueKey('greeting_text')),
                TextField(
                  key: const ValueKey('name_input'),
                  controller: TextEditingController(),
                  decoration: const InputDecoration(hintText: 'Name'),
                ),
                ElevatedButton(
                  key: const ValueKey('navigate_button'),
                  onPressed: () {},
                  child: const Text('Say goodbye'),
                ),
              ],
            ),
          ),
        ),
      );

      final session = LocalTestExecutionSession.attach(
        tester: tester,
        harness: EnsembleTestHarness(
          appPath: 'unused/',
          appHome: 'Home',
        ),
        context: EnsembleTestContext(
          testCase: const EnsembleTestCase(id: 'logical-observe', steps: []),
          apiOverlay: TestApiProviderOverlay(mocks: const {}),
          logger: TestLogger(),
          setup: const EnsembleTestSetup(),
        ),
        permissions: SessionPermissions.restrictedUi,
      );

      final observation = await session.observe(
        options: const ObservationOptions(
          synchronization: ObservationSynchronization.immediate,
        ),
      );

      final flat = _flatten(observation.elements);
      expect(flat.length, lessThan(10));
      expect(
        flat.where((e) => e.type == 'textInput').length,
        1,
        reason: 'TextField descendants must not inflate extra textInput rows',
      );
      expect(
        flat.where((e) => e.type == 'button').length,
        1,
        reason: 'Button descendants must not inflate extra button rows',
      );
      expect(
        flat.map((e) => e.testId),
        containsAll(['greeting_text', 'name_input', 'navigate_button']),
      );

      await session.close();
    },
  );

  testWidgets('observe nests keyed child under keyed parent', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Container(
            key: const ValueKey('card'),
            child: ElevatedButton(
              key: const ValueKey('card_button'),
              onPressed: () {},
              child: const Text('Go'),
            ),
          ),
        ),
      ),
    );

    final session = LocalTestExecutionSession.attach(
      tester: tester,
      harness: EnsembleTestHarness(
        appPath: 'unused/',
        appHome: 'Home',
      ),
      context: EnsembleTestContext(
        testCase: const EnsembleTestCase(id: 'nested-observe', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
      permissions: SessionPermissions.restrictedUi,
    );

    final observation = await session.observe(
      options: const ObservationOptions(
        synchronization: ObservationSynchronization.immediate,
      ),
    );

    final card = observation.elements.firstWhere((e) => e.testId == 'card');
    expect(
      card.children.map((e) => e.testId),
      contains('card_button'),
    );

    await session.close();
  });

  testWidgets('observe types icon / switch / dropdown distinctly from button',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              IconButton(
                key: const ValueKey('theme_icon'),
                onPressed: () {},
                icon: const Icon(Icons.dark_mode),
              ),
              // Ensemble IconButton pattern: Material + InkWell + Icon.
              Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const ValueKey('lang_icon'),
                  onTap: () {},
                  child: const SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(child: Text('A')),
                  ),
                ),
              ),
              Switch(
                key: const ValueKey('stub_switch'),
                value: false,
                onChanged: (_) {},
              ),
              DropdownButton<String>(
                key: const ValueKey('device_dropdown'),
                value: 'a',
                items: const [
                  DropdownMenuItem(value: 'a', child: Text('A')),
                  DropdownMenuItem(value: 'b', child: Text('B')),
                ],
                onChanged: (_) {},
              ),
              // Host/custom dropdown pattern: tap target + value + chevron.
              InkWell(
                key: const ValueKey('custom_dropdown'),
                onTap: () {},
                child: const Row(
                  children: [
                    Text('HGW_SAH'),
                    Icon(Icons.keyboard_arrow_down),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final session = LocalTestExecutionSession.attach(
      tester: tester,
      harness: EnsembleTestHarness(
        appPath: 'unused/',
        appHome: 'Home',
      ),
      context: EnsembleTestContext(
        testCase: const EnsembleTestCase(id: 'typed-observe', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
      permissions: SessionPermissions.restrictedUi,
    );

    final observation = await session.observe(
      options: const ObservationOptions(
        synchronization: ObservationSynchronization.immediate,
      ),
    );
    final flat = _flatten(observation.elements);

    expect(
      flat.firstWhere((e) => e.testId == 'theme_icon').type,
      'icon',
    );
    expect(
      flat.firstWhere((e) => e.testId == 'lang_icon').type,
      'icon',
      reason: 'compact InkWell with tiny glyph text should still be icon',
    );
    expect(
      flat.firstWhere((e) => e.testId == 'stub_switch').type,
      'switch',
    );
    expect(
      flat.firstWhere((e) => e.testId == 'device_dropdown').type,
      'dropdown',
    );
    expect(
      flat.firstWhere((e) => e.testId == 'device_dropdown').options,
      ['A', 'B'],
    );
    expect(
      flat.firstWhere((e) => e.testId == 'custom_dropdown').type,
      'dropdown',
      reason: 'value text + chevron InkWell should be dropdown',
    );
    expect(
      flat.firstWhere((e) => e.testId == 'custom_dropdown').options,
      isEmpty,
      reason: 'custom InkWell dropdowns have no items list to read',
    );

    await session.close();
  });

  testWidgets('observe keeps one icon/dropdown when InkWells nest',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              // Nested tap targets — only the outer logical control should remain.
              Material(
                child: InkWell(
                  onTap: () {},
                  child: InkWell(
                    onTap: () {},
                    child: const SizedBox(
                      width: 48,
                      height: 48,
                      child: Icon(Icons.dark_mode),
                    ),
                  ),
                ),
              ),
              InkWell(
                onTap: () {},
                child: const Row(
                  children: [
                    Text('HGW_SAH'),
                    Icon(Icons.keyboard_arrow_down),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final session = LocalTestExecutionSession.attach(
      tester: tester,
      harness: EnsembleTestHarness(
        appPath: 'unused/',
        appHome: 'Home',
      ),
      context: EnsembleTestContext(
        testCase: const EnsembleTestCase(id: 'dedupe-observe', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
      permissions: SessionPermissions.restrictedUi,
    );

    final observation = await session.observe(
      options: const ObservationOptions(
        synchronization: ObservationSynchronization.immediate,
      ),
    );
    final flat = _flatten(observation.elements);
    expect(flat.where((e) => e.type == 'icon').length, 1);
    expect(flat.where((e) => e.type == 'dropdown').length, 1);
    expect(
      observation.elements.where((e) => e.type == 'icon').single.children,
      isEmpty,
    );
    expect(
      observation.elements.where((e) => e.type == 'dropdown').single.children,
      isEmpty,
    );
    final icon = flat.singleWhere((e) => e.type == 'icon');
    expect(icon.text, isNull, reason: 'do not invent Material icon names');
    expect(
      icon.state.enabled,
      isNull,
      reason: 'decorative Icon under InkWell is not an IconButton host',
    );

    await session.close();
  });

  testWidgets('observe icon value uses tooltip when present', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IconButton(
            tooltip: 'Toggle theme',
            onPressed: () {},
            icon: const Icon(Icons.dark_mode),
          ),
        ),
      ),
    );

    final session = LocalTestExecutionSession.attach(
      tester: tester,
      harness: EnsembleTestHarness(
        appPath: 'unused/',
        appHome: 'Home',
      ),
      context: EnsembleTestContext(
        testCase: const EnsembleTestCase(id: 'icon-tooltip', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
      permissions: SessionPermissions.restrictedUi,
    );

    final observation = await session.observe(
      options: const ObservationOptions(
        synchronization: ObservationSynchronization.immediate,
      ),
    );
    final icon = _flatten(observation.elements)
        .firstWhere((e) => e.type == 'icon');
    expect(icon.text, 'Toggle theme');
    expect(icon.state.enabled, isTrue);

    await session.close();
  });

  testWidgets('observe textInput keeps hint/label separate from value',
      (tester) async {
    final filled = TextEditingController(text: 'http://instellen.local/ws');
    final empty = TextEditingController();
    addTearDown(filled.dispose);
    addTearDown(empty.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Local API Endpoint'),
              TextField(
                key: const ValueKey('api_input'),
                controller: filled,
                decoration: const InputDecoration(
                  hintText: 'https://example.com',
                ),
              ),
              const Text('Generated Password Override'),
              TextField(
                key: const ValueKey('password_override'),
                controller: empty,
                decoration: const InputDecoration(
                  hintText: 'Optional INHOME_GENERATED_PASSWORD',
                ),
              ),
              const Text('Use Stub URL'),
              Switch(
                key: const ValueKey('stub_switch'),
                value: true,
                onChanged: (_) {},
              ),
            ],
          ),
        ),
      ),
    );

    final session = LocalTestExecutionSession.attach(
      tester: tester,
      harness: EnsembleTestHarness(
        appPath: 'unused/',
        appHome: 'Home',
      ),
      context: EnsembleTestContext(
        testCase: const EnsembleTestCase(id: 'textinput-fields', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
      permissions: SessionPermissions.restrictedUi,
    );

    final observation = await session.observe(
      options: const ObservationOptions(
        synchronization: ObservationSynchronization.immediate,
      ),
    );
    final flat = _flatten(observation.elements);

    expect(
      flat.where((e) => e.type == 'text' && e.text == 'Local API Endpoint'),
      isEmpty,
      reason: 'sibling label text should be absorbed into the textInput',
    );
    expect(
      flat.where(
        (e) => e.type == 'text' && e.text == 'Generated Password Override',
      ),
      isEmpty,
    );
    expect(
      flat.where((e) => e.type == 'text' && e.text == 'Use Stub URL'),
      isEmpty,
    );

    final api = flat.firstWhere((e) => e.testId == 'api_input');
    expect(api.type, 'textInput');
    expect(api.text, 'http://instellen.local/ws');
    expect(api.label, 'Local API Endpoint');
    expect(api.hint, 'https://example.com');

    final override = flat.firstWhere((e) => e.testId == 'password_override');
    expect(override.type, 'textInput');
    expect(override.text, isNull, reason: 'hint must not become value');
    expect(override.label, 'Generated Password Override');
    expect(override.hint, 'Optional INHOME_GENERATED_PASSWORD');

    final stub = flat.firstWhere((e) => e.testId == 'stub_switch');
    expect(stub.type, 'switch');
    expect(stub.label, 'Use Stub URL');
    expect(stub.state.checked, isTrue);
    expect(stub.text, isNull);

    await session.close();
  });
}

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
