import 'package:ensemble/framework/widget/screen.dart';
import 'package:ensemble/page_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('parses TV focus header and widget background separately from styles',
      () {
    final model = ScreenDefinition(loadYaml('''
View:
  header:
    titleWidget:
      Text:
        text: Expanded
    collapsedTitleWidget:
      Text:
        text: Collapsed
    styles:
      collapsibleHeader:
        enabled: true
        trigger: focus
        duration: 0
      collapsedBarHeight: 48
  styles:
    background:
      Container:
        styles:
          backgroundColor: '#000000'
  body:
    Column:
      children:
        - Text:
            text: Body
''')).getModel(null) as SinglePageModel;

    expect(model.headerModel?.titleWidget?.type, 'Text');
    expect(model.headerModel?.collapsedTitleWidget?.type, 'Text');
    expect(model.headerModel?.inlineStyles?['collapsibleHeader']['trigger'],
        'focus');
    expect(model.headerModel?.inlineStyles?['collapsibleHeader']['duration'], 0);
    expect(model.headerModel?.inlineStyles?['collapsedBarHeight'], 48);
    expect(model.backgroundWidget?.type, 'Container');
    expect(model.inlineStyles?.containsKey('background'), isFalse);
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
    expect(collapsible.containsKey('trigger'), isFalse);
  });

  test('parses the default collapsible header trigger', () {
    final model = ScreenDefinition(loadYaml('''
View:
  header:
    title: Browse
    styles:
      collapsibleHeader:
        enabled: true
        trigger: default
        visible: \${app.showHeader}
  body:
    Column:
      children:
        - Text:
            text: Body
''')).getModel(null) as SinglePageModel;

    final collapsible = model.headerModel?.inlineStyles?['collapsibleHeader'];
    expect(collapsible['trigger'], 'default');
    expect(collapsible['visible'], r'${app.showHeader}');
  });
}
