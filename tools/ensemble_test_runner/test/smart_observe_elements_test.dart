import 'dart:typed_data';

import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/widget/lottie/lottie.dart';
import 'package:ensemble_test_runner/mocks/test_api_provider_overlay.dart';
import 'package:ensemble_test_runner/mocks/test_logger.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:ensemble_test_runner/session/actions/test_action.dart';
import 'package:ensemble_test_runner/session/local/local_execution_session.dart';
import 'package:ensemble_test_runner/session/observation/observation_options.dart';
import 'package:ensemble_test_runner/session/observation/ui_element.dart';
import 'package:ensemble_test_runner/session/session_capabilities.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
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

  testWidgets('observe keeps unkeyed primaries under a keyed page shell',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KeyedSubtree(
            key: const ValueKey('Home'),
            child: SizedBox.expand(
              child: Column(
                children: [
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text('Share wifi'),
                  ),
                  const Text('Your network is online'),
                  ElevatedButton(
                    key: const ValueKey('devices_mini_card'),
                    onPressed: () {},
                    child: const Text('Devices'),
                  ),
                ],
              ),
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
        testCase: const EnsembleTestCase(id: 'keyed-shell-observe', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
      permissions: SessionPermissions.restrictedUi,
    );
    addTearDown(session.close);

    final observation = await session.observe(
      options: const ObservationOptions(
        synchronization: ObservationSynchronization.immediate,
      ),
    );
    final flat = _flatten(observation.elements);
    expect(
      flat.any((e) =>
          (e.text ?? '') == 'Share wifi' || (e.label ?? '') == 'Share wifi'),
      isTrue,
      reason: 'unkeyed button under Home shell must be observed',
    );
    expect(
      flat.any((e) => (e.text ?? '').contains('network is online')),
      isTrue,
      reason: 'standalone text under Home shell must be observed',
    );
    expect(
      flat.any((e) => e.testId == 'devices_mini_card'),
      isTrue,
    );
    expect(
      flat.where((e) => e.testId == 'Home'),
      isEmpty,
      reason: 'page-shell id must not attach to child rows or be kept itself',
    );
    final networkText = flat.where(
      (e) => (e.text ?? '').contains('network is online'),
    );
    expect(
      networkText.length,
      1,
      reason: 'Text+RichText must not produce duplicate observe rows',
    );
    await session.close();
  });

  testWidgets(
      'observe does not stamp page-shell id when shell has only unkeyed kids',
      (tester) async {
    // Loading screens often wrap only Text/Lottie under KeyedSubtree(id:
    // AutoSignIn) with no sibling keyed widgets — exclusive-wrapper used to
    // inherit the route name onto every child (overlay chips showed
    // AutoSignIn as id while Selector correctly used text=).
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KeyedSubtree(
            key: const ValueKey('AutoSignIn'),
            child: SizedBox.expand(
              child: Column(
                children: const [
                  Text('Even geduld..'),
                  Text('We halen de gegevens op.'),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final session = LocalTestExecutionSession.attach(
      tester: tester,
      harness: EnsembleTestHarness(
        appPath: 'unused/',
        appHome: 'AutoSignIn',
      ),
      context: EnsembleTestContext(
        testCase: const EnsembleTestCase(
          id: 'shell-unkeyed-observe',
          steps: [],
        ),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
      permissions: SessionPermissions.restrictedUi,
    );
    addTearDown(session.close);

    final observation = await session.observe(
      options: const ObservationOptions(
        synchronization: ObservationSynchronization.immediate,
      ),
    );
    final flat = _flatten(observation.elements);
    expect(flat.length, greaterThanOrEqualTo(2));
    expect(
      flat.where((e) => e.testId == 'AutoSignIn'),
      isEmpty,
      reason: 'route shell id must not attach when only unkeyed children',
    );
    expect(
      flat.any((e) => (e.text ?? '').contains('Even geduld')),
      isTrue,
    );
    await session.close();
  });

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

  testWidgets('observe types cards separately from buttons', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TextButton(
                onPressed: () {},
                child: const Text('Get started →'),
              ),
              SizedBox(
                width: 160,
                height: 100,
                child: InkWell(
                  key: const ValueKey('devices_mini_card'),
                  onTap: () {},
                  child: const Column(
                    children: [
                      Text('Devices'),
                      Text('2'),
                      Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 360,
                height: 56,
                child: InkWell(
                  onTap: () {},
                  child: const Row(
                    children: [
                      Expanded(child: Text('Guest wifi')),
                      Text('KPN_Gast'),
                      Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 360,
                height: 56,
                child: InkWell(
                  onTap: () {},
                  child: const Row(
                    children: [
                      Expanded(child: Text('Password')),
                      Icon(Icons.visibility),
                    ],
                  ),
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
        testCase: const EnsembleTestCase(id: 'tap-shapes', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
      permissions: SessionPermissions.restrictedUi,
    );
    addTearDown(session.close);

    final observation = await session.observe(
      options: const ObservationOptions(
        synchronization: ObservationSynchronization.immediate,
      ),
    );
    final flat = _flatten(observation.elements);

    expect(
      flat.any(
          (e) => e.type == 'button' && (e.text ?? '').contains('Get started')),
      isTrue,
    );
    expect(
      flat.firstWhere((e) => e.testId == 'devices_mini_card').type,
      'card',
    );
    expect(
      flat.any(
          (e) => e.type == 'card' && (e.text ?? '').contains('Guest wifi')),
      isTrue,
    );
    expect(
      flat.any((e) => e.type == 'card' && (e.text ?? '').contains('Password')),
      isTrue,
    );
    final tappableCard =
        flat.firstWhere((e) => e.testId == 'devices_mini_card');
    expect(tappableCard.state.enabled, isTrue);

    // Nested captions + nav chevrons under the card must stay in the tree.
    final guestCard = flat.firstWhere(
      (e) => e.type == 'card' && (e.text ?? '').contains('Guest wifi'),
    );
    final guestFlat = _flatten([guestCard]);
    expect(
      guestFlat.any((e) => e.type == 'text' && (e.text ?? '') == 'KPN_Gast'),
      isTrue,
      reason: 'Status / value text nested under a tappable row must be kept',
    );
    expect(
      guestFlat.any((e) => e.type == 'text' && (e.text ?? '') == 'Guest wifi'),
      isTrue,
      reason: 'Title Text stays a child even when the card header shows it',
    );
    expect(
      guestFlat.any((e) => e.type == 'icon'),
      isTrue,
      reason: 'Nav chevron under a settings row must be observed',
    );
    expect(
      _flatten([tappableCard]).any(
        (e) => e.type == 'text' && (e.text ?? '') == 'Devices',
      ),
      isTrue,
      reason: 'Title Text stays a child under the keyed card',
    );
    // Badge / status copy nested under a keyed card (e.g. "Bedraad").
    expect(
      _flatten([tappableCard]).any(
        (e) => e.type == 'text' && (e.text ?? '') == '2',
      ),
      isTrue,
      reason: 'Secondary caption nested under a keyed card must be kept',
    );
    await session.close();
  });

  testWidgets(
    'tappable settings row observes both the row card and keyed checkbox',
    (tester) async {
      // Mirrors RestoreSettings: FlexRow onTap + Checkbox with testId.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 88,
              child: GestureDetector(
                onTap: () {},
                child: const Row(
                  children: [
                    KeyedSubtree(
                      key: ValueKey('restore_dns_checkbox'),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Checkbox(
                          value: true,
                          onChanged: null,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('DNS settings',
                                style: TextStyle(fontSize: 14)),
                            Text(
                              'Edit DNS settings',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Icon(Icons.info_outline),
                  ],
                ),
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
          testCase: const EnsembleTestCase(id: 'row-and-checkbox', steps: []),
          apiOverlay: TestApiProviderOverlay(mocks: const {}),
          logger: TestLogger(),
          setup: const EnsembleTestSetup(),
        ),
        permissions: SessionPermissions.restrictedUi,
      );
      addTearDown(session.close);

      final observation = await session.observe(
        options: const ObservationOptions(
          synchronization: ObservationSynchronization.immediate,
        ),
      );
      final flat = _flatten(observation.elements);

      final checkboxes = flat
          .where((e) => e.testId == 'restore_dns_checkbox')
          .toList();
      expect(
        checkboxes,
        hasLength(1),
        reason: 'KeyedSubtree + Checkbox must not both keep the same testId',
      );
      final checkbox = checkboxes.single;
      expect(
        checkbox.type,
        'checkbox',
        reason: 'Keyed Checkbox must not inherit the row InkWell card type',
      );
      expect(checkbox.state.checked, isTrue);
      expect(
        checkbox.children.where((c) => c.type == 'checkbox'),
        isEmpty,
        reason: 'checkbox must not nest a duplicate of itself',
      );

      expect(
        flat.any(
          (e) =>
              e.type == 'card' &&
              (e.text ?? '').contains('DNS settings') &&
              (e.testId == null || e.testId!.isEmpty),
        ),
        isTrue,
        reason: 'Tappable FlexRow/GestureDetector should still observe as card',
      );

      final infoIcons = flat.where((e) => e.type == 'icon').toList();
      expect(
        infoIcons,
        isNotEmpty,
        reason:
            'Nested actionable chrome (info icon) under the card must be observed',
      );
      expect(
        observation.elements.any(
          (e) =>
              e.type == 'card' &&
              e.children.any((c) => c.type == 'icon' || c.type == 'checkbox'),
        ),
        isTrue,
        reason: 'Nested actions should nest under the row card',
      );
    },
  );

  testWidgets(
    'observe orders roots top-to-bottom (app bar before body)',
    (tester) async {
      // Scaffold visits body before the AppBar in the element walk — without
      // visual sort the back button would appear after body cards.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                key: const ValueKey('back_button'),
                icon: const Icon(Icons.arrow_back),
                onPressed: () {},
              ),
              title: const Text('Devices'),
            ),
            body: ListView(
              children: [
                Card(
                  child: ListTile(
                    key: const ValueKey('gateway_card'),
                    title: const Text('KPN Box 12'),
                    onTap: () {},
                  ),
                ),
                const Text('Footer feedback'),
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
          testCase: const EnsembleTestCase(id: 'visual-order', steps: []),
          apiOverlay: TestApiProviderOverlay(mocks: const {}),
          logger: TestLogger(),
          setup: const EnsembleTestSetup(),
        ),
        permissions: SessionPermissions.restrictedUi,
      );
      addTearDown(session.close);

      final observation = await session.observe(
        options: const ObservationOptions(
          synchronization: ObservationSynchronization.immediate,
        ),
      );
      final roots = observation.elements;
      expect(roots, isNotEmpty);

      final backIndex = roots.indexWhere(
        (e) => e.testId == 'back_button' || e.type == 'icon',
      );
      final cardIndex = roots.indexWhere(
        (e) => e.testId == 'gateway_card' || e.type == 'card',
      );
      expect(backIndex, greaterThanOrEqualTo(0), reason: 'back control kept');
      expect(cardIndex, greaterThanOrEqualTo(0), reason: 'body card kept');
      expect(
        backIndex,
        lessThan(cardIndex),
        reason: 'header back button must precede body card in the tree',
      );

      final backTop = roots[backIndex].bounds?.top;
      final cardTop = roots[cardIndex].bounds?.top;
      expect(backTop, isNotNull);
      expect(cardTop, isNotNull);
      expect(backTop!, lessThan(cardTop!));
    },
  );

  testWidgets(
    'unkeyed caption button is interactable and taps via label+role',
    (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              // Ensemble-style tab pill: InkWell + Text, no ValueKey / Semantics.
              child: InkWell(
                onTap: () => tapped = true,
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('Netwerk'),
                ),
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
          testCase: const EnsembleTestCase(id: 'caption-button', steps: []),
          apiOverlay: TestApiProviderOverlay(mocks: const {}),
          logger: TestLogger(),
          setup: const EnsembleTestSetup(),
        ),
        permissions: SessionPermissions.restrictedUi,
      );
      addTearDown(session.close);

      final observation = await session.observe(
        options: const ObservationOptions(
          synchronization: ObservationSynchronization.immediate,
        ),
      );
      final flat = _flatten(observation.elements);
      final button = flat.firstWhere((e) => e.type == 'button');
      expect(button.text, 'Netwerk');
      expect(button.label, 'Netwerk');
      expect(button.role, 'button');
      expect(button.state.interactable, isTrue);
      expect(button.supportedActions, contains('tap'));

      final result = await session.act(
        const TapAction(
          ElementTarget(
            locator: ElementLocator(label: 'Netwerk', role: 'button'),
          ),
        ),
      );
      expect(result.succeeded, isTrue, reason: result.error?.toString());
      expect(tapped, isTrue);
    },
  );

  testWidgets(
    'toast banners observe as toast without enabled=false',
    (tester) async {
      // Mirrors fluttertoast FToast + Ensemble ToastController: Positioned
      // gravity wrapper around GestureDetector(onTap: null) + message body.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                const Center(child: Text('Screen body')),
                Positioned(
                  top: 100,
                  left: 24,
                  right: 24,
                  child: GestureDetector(
                    onTap: null,
                    behavior: HitTestBehavior.translucent,
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade900,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.error_outline),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'No token found, please open the app again.',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final session = LocalTestExecutionSession.attach(
        tester: tester,
        harness: EnsembleTestHarness(appPath: 'unused/', appHome: 'Home'),
        context: EnsembleTestContext(
          testCase: const EnsembleTestCase(id: 'toast-observe', steps: []),
          apiOverlay: TestApiProviderOverlay(mocks: const {}),
          logger: TestLogger(),
          setup: const EnsembleTestSetup(),
        ),
        permissions: SessionPermissions.restrictedUi,
      );
      addTearDown(session.close);

      final observation = await session.observe(
        options: const ObservationOptions(
          synchronization: ObservationSynchronization.immediate,
        ),
      );
      final flat = _flatten(observation.elements);
      final toast = flat.firstWhere(
        (e) => (e.text ?? '').contains('No token found'),
        orElse: () => flat.firstWhere((e) => e.type == 'toast'),
      );
      expect(toast.type, 'toast');
      expect(
        toast.state.enabled,
        isNull,
        reason: 'non-tappable toast must not report enabled=false',
      );
      expect(
        _flatten([toast]).where((e) => e.type == 'card'),
        isEmpty,
        reason: 'toast chrome must not nest a decorative card',
      );
      expect(
        _flatten([toast]).any(
          (e) =>
              e.type == 'text' && (e.text ?? '').contains('No token found'),
        ),
        isTrue,
        reason: 'message Text stays a child of the toast',
      );
      await session.close();
    },
  );

  testWidgets('compact tappable back-arrow image observes as icon',
      (tester) async {
    final png = Uint8List.fromList(<int>[
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
      0x00,
      0x00,
      0x00,
      0x0D,
      0x49,
      0x48,
      0x44,
      0x52,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x01,
      0x08,
      0x06,
      0x00,
      0x00,
      0x00,
      0x1F,
      0x15,
      0xC4,
      0x89,
      0x00,
      0x00,
      0x00,
      0x0A,
      0x49,
      0x44,
      0x41,
      0x54,
      0x78,
      0x9C,
      0x63,
      0x00,
      0x01,
      0x00,
      0x00,
      0x05,
      0x00,
      0x01,
      0x0D,
      0x0A,
      0x2D,
      0xB4,
      0x00,
      0x00,
      0x00,
      0x00,
      0x49,
      0x45,
      0x4E,
      0x44,
      0xAE,
      0x42,
      0x60,
      0x82,
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: InkWell(
              onTap: () {},
              child: SizedBox(
                width: 44,
                height: 44,
                child: Image.memory(png, fit: BoxFit.contain),
              ),
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
        testCase: const EnsembleTestCase(id: 'back-icon', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
      permissions: SessionPermissions.restrictedUi,
    );
    addTearDown(session.close);

    final observation = await session.observe(
      options: const ObservationOptions(
        synchronization: ObservationSynchronization.immediate,
      ),
    );
    final flat = _flatten(observation.elements);
    expect(
      flat.where((e) => e.type == 'image'),
      isEmpty,
      reason: 'compact tappable arrow must not observe as decorative image',
    );
    expect(flat.any((e) => e.type == 'icon'), isTrue);
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
    // Nested InkWell+Icon collapses to one icon host (no leaf Icon child).
    final rootIcons =
        observation.elements.where((e) => e.type == 'icon').toList();
    expect(rootIcons, hasLength(1));
    expect(rootIcons.single.children, isEmpty);
    expect(
      rootIcons.single.text,
      isNull,
      reason: 'do not invent Material icon names',
    );
    expect(
      rootIcons.single.state.enabled,
      isTrue,
      reason: 'compact InkWell with onTap is an actionable icon host',
    );
    expect(rootIcons.single.state.interactable, isTrue);

    // Dropdown keeps its expand chevron; value caption stays on the dropdown row.
    final dropdowns =
        observation.elements.where((e) => e.type == 'dropdown').toList();
    expect(dropdowns, hasLength(1));
    final dropdownFlat = _flatten(dropdowns);
    expect(
      dropdownFlat.where((e) => e.type == 'text' && (e.text ?? '') == 'HGW_SAH'),
      isEmpty,
      reason: 'value caption must not duplicate under the dropdown',
    );
    expect(
      dropdownFlat.any((e) => e.type == 'icon'),
      isTrue,
      reason: 'dropdown chevron must remain visible in the observe tree',
    );
    expect(flat.where((e) => e.type == 'dropdown').length, 1);

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
    final icon =
        _flatten(observation.elements).firstWhere((e) => e.type == 'icon');
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

  testWidgets('observe recognizes image / gif / lottie (and tappable media)',
      (tester) async {
    // 1x1 PNG
    final png = Uint8List.fromList(<int>[
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
      0x00,
      0x00,
      0x00,
      0x0D,
      0x49,
      0x48,
      0x44,
      0x52,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x01,
      0x08,
      0x06,
      0x00,
      0x00,
      0x00,
      0x1F,
      0x15,
      0xC4,
      0x89,
      0x00,
      0x00,
      0x00,
      0x0A,
      0x49,
      0x44,
      0x41,
      0x54,
      0x78,
      0x9C,
      0x63,
      0x00,
      0x01,
      0x00,
      0x00,
      0x05,
      0x00,
      0x01,
      0x0D,
      0x0A,
      0x2D,
      0xB4,
      0x00,
      0x00,
      0x00,
      0x00,
      0x49,
      0x45,
      0x4E,
      0x44,
      0xAE,
      0x42,
      0x60,
      0x82,
    ]);
    final lottie = EnsembleLottie();
    lottie.controller.source = 'assets/anim.json';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Image.memory(png,
                  key: const ValueKey('hero_image'), width: 40, height: 40),
              Image(
                key: const ValueKey('spinner_gif'),
                image: NetworkImage('https://example.com/spinner.gif'),
                width: 40,
                height: 40,
                errorBuilder: (_, __, ___) =>
                    const SizedBox(width: 40, height: 40),
              ),
              KeyedSubtree(key: const ValueKey('hero_lottie'), child: lottie),
              // Compact tappable media → icon (back/close chrome).
              GestureDetector(
                onTap: () {},
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Image.memory(png, fit: BoxFit.contain),
                ),
              ),
              // Larger tappable illustration → stays image.
              GestureDetector(
                onTap: () {},
                child: SizedBox(
                  width: 180,
                  height: 180,
                  child: Image.memory(png, fit: BoxFit.contain),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    final session = LocalTestExecutionSession.attach(
      tester: tester,
      harness: EnsembleTestHarness(
        appPath: 'unused/',
        appHome: 'Home',
      ),
      context: EnsembleTestContext(
        testCase: const EnsembleTestCase(id: 'media-observe', steps: []),
        apiOverlay: TestApiProviderOverlay(mocks: const {}),
        logger: TestLogger(),
        setup: const EnsembleTestSetup(),
      ),
      permissions: SessionPermissions.restrictedUi,
    );
    addTearDown(session.close);

    final observation = await session.observe(
      options: const ObservationOptions(
        synchronization: ObservationSynchronization.immediate,
      ),
    );
    final flat = _flatten(observation.elements);

    expect(
      flat.firstWhere((e) => e.testId == 'hero_image').type,
      'image',
    );
    expect(
      flat.firstWhere((e) => e.testId == 'spinner_gif').type,
      'gif',
    );
    expect(
      flat.firstWhere((e) => e.testId == 'hero_lottie').type,
      'lottie',
    );
    expect(
      flat.any((e) => e.type == 'icon' && e.testId == null),
      isTrue,
      reason: 'compact tappable image (back arrow) should be icon',
    );
    expect(
      flat.any((e) => e.type == 'image' && e.testId == null),
      isTrue,
      reason: 'large tappable illustration should stay image',
    );
    await session.close();
  });

  testWidgets(
    'observe nests feedback panel content under a non-tappable visual card',
    (tester) async {
      // FeedbackInput-style: bordered Column chrome, no onTap on the shell;
      // rating icons / copy live inside and must nest under type=card.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Container(
                width: 320,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFD3D3D3)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Wat vind je van deze pagina?'),
                    const Text('We zijn benieuwd naar je mening!'),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (var i = 0; i < 5; i++)
                          InkWell(
                            onTap: () {},
                            child: const SizedBox(
                              width: 40,
                              height: 40,
                              child: Icon(Icons.sentiment_satisfied),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
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
          testCase: const EnsembleTestCase(id: 'visual-card', steps: []),
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

      final card = observation.elements.where((e) => e.type == 'card').firstOrNull;
      expect(card, isNotNull, reason: 'bordered panel must observe as card');
      expect(card!.state.enabled, isNull,
          reason: 'non-tappable card has no enabled flag');
      expect(card.state.interactable, isFalse);
      expect(card.supportedActions, isNot(contains('tap')));

      final flatKids = _flatten(card.children);
      expect(
        flatKids.where((e) => e.type == 'text').length,
        greaterThanOrEqualTo(2),
      );
      expect(
        flatKids.where((e) => e.type == 'icon').length,
        5,
        reason: 'rating faces nest under the visual card',
      );
      expect(
        observation.elements.where((e) => e.type == 'icon'),
        isEmpty,
        reason: 'rating icons must not float as root siblings',
      );

      await session.close();
    },
  );

  testWidgets(
    'observe does not wrap a keyed tappable card in a decorative visual card',
    (tester) async {
      // Devices ModemInfo: wrapperCard* Column chrome around gateway_card.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Container(
                width: 320,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(blurRadius: 16, color: Color(0x0D000000)),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: const ValueKey('gateway_card'),
                    onTap: () {},
                    child: const SizedBox(
                      height: 120,
                      child: Center(child: Text('KPN Box 12')),
                    ),
                  ),
                ),
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
          testCase: const EnsembleTestCase(id: 'no-double-card', steps: []),
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
      final cards =
          observation.elements.where((e) => e.type == 'card').toList();
      expect(cards, hasLength(1), reason: 'wrapper chrome must not add a card');
      expect(cards.single.testId, 'gateway_card');
      expect(cards.single.state.interactable, isTrue);
      expect(cards.single.children.where((e) => e.type == 'card'), isEmpty);

      await session.close();
    },
  );

  testWidgets(
    'observe treats Invokable isDisabled as enabled=false '
    'even when InkWell.onTap is still wired',
    (tester) async {
      // Mirrors InHome BackButton: YAML keeps onTap + executeConditionalAction,
      // and passes isDisabled as a custom-widget / Invokable input. InkWell.onTap
      // alone still looks enabled.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KeyedSubtree(
              key: const ValueKey('back_button'),
              child: _InvokableFlagHost(
                isDisabled: true,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {},
                    child: const SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(
                        Icons.arrow_back,
                        color: Color(0xff737373),
                      ),
                    ),
                  ),
                ),
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
          testCase: const EnsembleTestCase(id: 'disabled-back', steps: []),
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
      final back = _flatten(observation.elements)
          .singleWhere((e) => e.testId == 'back_button');
      expect(back.type, 'icon');
      expect(back.state.enabled, isFalse);
      expect(back.state.interactable, isFalse);
      expect(back.supportedActions, isNot(contains('tap')));
      expect(back.supportedActions, contains('waitFor'));
      expect(back.supportedActions, contains('expectDisabled'));

      await session.close();
    },
  );

  testWidgets(
    'observe treats custom-widget scope isDisabled as enabled=false',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              final scope = ScopeManager(
                DataContext(buildContext: context),
                PageData(),
              );
              scope.dataContext.addDataContextById('isDisabled', true);
              return Scaffold(
                body: DataScopeWidget(
                  debugLabel: 'CustomWidget',
                  scopeManager: scope,
                  child: KeyedSubtree(
                    key: const ValueKey('back_button'),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {},
                        child: const SizedBox(
                          width: 40,
                          height: 40,
                          child: Icon(Icons.arrow_back),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
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
          testCase: const EnsembleTestCase(id: 'scope-disabled-back', steps: []),
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
      final back = _flatten(observation.elements)
          .singleWhere((e) => e.testId == 'back_button');
      expect(back.state.enabled, isFalse);
      expect(back.state.interactable, isFalse);
      expect(back.supportedActions, isNot(contains('tap')));

      await session.close();
    },
  );

  testWidgets(
    'observe keeps enabled=true when isDisabled is false and onTap is wired',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KeyedSubtree(
              key: const ValueKey('back_button'),
              child: _InvokableFlagHost(
                isDisabled: false,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {},
                    child: const SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(Icons.arrow_back),
                    ),
                  ),
                ),
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
          testCase: const EnsembleTestCase(id: 'enabled-back', steps: []),
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
      final back = _flatten(observation.elements)
          .singleWhere((e) => e.testId == 'back_button');
      expect(back.state.enabled, isTrue);
      expect(back.state.interactable, isTrue);
      expect(back.supportedActions, contains('tap'));

      await session.close();
    },
  );

  testWidgets(
    'observe does not treat styling className alone as disabled',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KeyedSubtree(
              key: const ValueKey('back_button'),
              child: _InvokableClassOnlyHost(
                className: 'disabledBackButton',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {},
                    child: const SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(Icons.arrow_back),
                    ),
                  ),
                ),
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
          testCase: const EnsembleTestCase(id: 'classname-not-disabled', steps: []),
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
      final back = _flatten(observation.elements)
          .singleWhere((e) => e.testId == 'back_button');
      expect(
        back.state.enabled,
        isTrue,
        reason: 'className is styling only — require isDisabled/enabled flags',
      );

      await session.close();
    },
  );
}

/// Invokable host exposing Ensemble-style disable flags (Button.enabled /
/// custom-widget isDisabled), not styling className.
// ignore: must_be_immutable — Invokable.id is set in the constructor for tests.
class _InvokableFlagHost extends StatelessWidget with Invokable {
  _InvokableFlagHost({required this.isDisabled, required this.child}) {
    id = 'back_button';
  }

  final bool isDisabled;
  final Widget child;

  @override
  Map<String, Function> getters() => {
        'isDisabled': () => isDisabled,
        'enabled': () => !isDisabled,
      };

  @override
  Map<String, Function> setters() => {};

  @override
  Map<String, Function> methods() => {};

  @override
  Widget build(BuildContext context) => child;
}

/// Invokable with only className — must not be treated as a disable signal.
// ignore: must_be_immutable — Invokable.id is set in the constructor for tests.
class _InvokableClassOnlyHost extends StatelessWidget with Invokable {
  _InvokableClassOnlyHost({required this.className, required this.child}) {
    id = 'back_button';
  }

  final String className;
  final Widget child;

  @override
  Map<String, Function> getters() => {
        'className': () => className,
      };

  @override
  Map<String, Function> setters() => {};

  @override
  Map<String, Function> methods() => {};

  @override
  Widget build(BuildContext context) => child;
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
