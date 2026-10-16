import 'package:ensemble/framework/view/page.dart';
import 'package:ensemble/framework/widget/screen.dart';
import 'package:ensemble/page_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('parses existing header slots and sizing for an expandable TV header',
      () {
    final model = ScreenDefinition(loadYaml('''
View:
  header:
    titleWidget:
      Text:
        text: Browse
    flexibleBackground:
      Column:
        children:
          - Text:
              text: Featured
    styles:
      titleBarHeight: 56
      flexibleMinHeight: 56
      flexibleMaxHeight: 220
      collapsibleHeader:
        enabled: true
      animation:
        enabled: true
        duration: 200
        curve: easeInOut
        animationType: fade
  body:
    Column:
      children:
        - Text:
            text: Body
''')).getModel(null) as SinglePageModel;

    expect(model.headerModel?.titleWidget?.type, 'Text');
    expect(model.headerModel?.flexibleBackground?.type, 'Column');
    expect(model.headerModel?.inlineStyles?['flexibleMinHeight'], 56);
    expect(model.headerModel?.inlineStyles?['flexibleMaxHeight'], 220);
    expect(model.headerModel?.inlineStyles?['collapsibleHeader']['enabled'],
        isTrue);
    expect(model.headerModel?.inlineStyles?['animation']['duration'], 200);
  });

  testWidgets('scrollable headers retain flexible min and max heights',
      (tester) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(MaterialApp(
      home: CustomScrollView(
        controller: scrollController,
        slivers: [
          AnimatedAppBar(
            scrollController: scrollController,
            collapsedBarHeight: 56.0,
            expandedBarHeight: 220.0,
            titleBarHeight: 56.0,
            pinned: false,
            floating: false,
            animated: false,
            automaticallyImplyLeading: false,
            titleWidget: const Text('Browse'),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 500)),
        ],
      ),
    ));

    final appBar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
    expect(appBar.collapsedHeight, 56.0);
    expect(appBar.expandedHeight, 220.0);
    expect(appBar.toolbarHeight, 56.0);
  });

  test('keeps legacy collapsible header visibility configuration', () {
    final model = ScreenDefinition(loadYaml('''
View:
  header:
    title: Browse
    styles:
      collapsibleHeader:
        enabled: true
        visible: \${app.showHeader}
  body:
    Column:
      children:
        - Text:
            text: Body
''')).getModel(null) as SinglePageModel;

    final collapsible = model.headerModel?.inlineStyles?['collapsibleHeader'];
    expect(collapsible['enabled'], isTrue);
    expect(collapsible['visible'], r'${app.showHeader}');
  });
}
