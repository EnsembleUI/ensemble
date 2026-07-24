import 'package:ensemble/framework/tv/tv_scrollbar_widget.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'fallback scrollbar restores its exact focus origin at the top boundary',
      (tester) async {
    final scrollController = ScrollController();
    final scrollbarFocusNode = FocusNode();
    final sourceFocusNode = FocusNode();
    final options = TVScrollbarOptionsComposite(
      ChangeNotifier(),
      inputs: const <String, dynamic>{},
    );
    var horizontalEventsAtParent = 0;
    var verticalEventsAtParent = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Focus(
            onKeyEvent: (_, event) {
              if (event is KeyDownEvent &&
                  (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                      event.logicalKey == LogicalKeyboardKey.arrowRight)) {
                horizontalEventsAtParent++;
              } else if (event is KeyDownEvent &&
                  (event.logicalKey == LogicalKeyboardKey.arrowUp ||
                      event.logicalKey == LogicalKeyboardKey.arrowDown)) {
                verticalEventsAtParent++;
              }
              return KeyEventResult.ignored;
            },
            child: Column(
              children: [
                Focus(
                  focusNode: sourceFocusNode,
                  child: const SizedBox(height: 1),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: 20,
                    itemBuilder: (_, index) => SizedBox(
                      height: 60,
                      child: Text('Item $index'),
                    ),
                  ),
                ),
                SizedBox(
                  height: 100,
                  width: 20,
                  child: TVScrollbarWidget(
                    scrollController: scrollController,
                    options: options,
                    focusNode: scrollbarFocusNode,
                    disableHorizontalNavigation: true,
                    restorePreviousFocusOnTop: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    sourceFocusNode.requestFocus();
    await tester.pump();
    expect(sourceFocusNode.hasFocus, isTrue);

    scrollbarFocusNode.requestFocus();
    await tester.pump();
    expect(scrollbarFocusNode.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    expect(horizontalEventsAtParent, 0);
    expect(scrollbarFocusNode.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    expect(sourceFocusNode.hasFocus, isTrue);
    expect(verticalEventsAtParent, 0);

    scrollbarFocusNode.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump(const Duration(milliseconds: 250));
    expect(scrollController.offset, greaterThan(0));

    scrollController.jumpTo(scrollController.position.maxScrollExtent);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    expect(verticalEventsAtParent, 1);

    scrollController.dispose();
    scrollbarFocusNode.dispose();
    sourceFocusNode.dispose();
  });
}
