import 'package:ensemble_test_runner/actions/scrollable_waiter.dart';
import 'package:ensemble_test_runner/actions/test_execution_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('returns the first scrollable when no id is supplied',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SingleChildScrollView(child: Text('content')),
      ),
    );

    final result = await ScrollableWaiter(
      tester: tester,
      config: const TestExecutionConfig(),
    ).wait(timeoutMs: 100);

    expect(result, findsOneWidget);
    expect(result.evaluate().single.widget, isA<Scrollable>());
  });

  testWidgets('resolves a keyed scrollable', (tester) async {
    final key = const ValueKey('results-scroll');
    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          key: key,
          child: const Text('results'),
        ),
      ),
    );

    final result = await ScrollableWaiter(
      tester: tester,
      config: const TestExecutionConfig(),
    ).wait(scrollableId: 'results-scroll', timeoutMs: 100);

    expect(result.evaluate(), hasLength(1));
    expect(result.evaluate().single.widget, isA<Scrollable>());
  });

  testWidgets('waits for a scrollable created by a later frame',
      (tester) async {
    await tester.pumpWidget(const _DelayedScrollView());

    final result = await ScrollableWaiter(
      tester: tester,
      config: const TestExecutionConfig(
        waitPollInterval: Duration(milliseconds: 10),
      ),
    ).wait(timeoutMs: 200);

    expect(result, findsOneWidget);
    expect(result.evaluate().single.widget, isA<Scrollable>());
  });
}

class _DelayedScrollView extends StatefulWidget {
  const _DelayedScrollView();

  @override
  State<_DelayedScrollView> createState() => _DelayedScrollViewState();
}

class _DelayedScrollViewState extends State<_DelayedScrollView> {
  var _ready = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 30), () {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: _ready
            ? const SingleChildScrollView(child: Text('ready'))
            : const SizedBox.shrink(),
      );
}
