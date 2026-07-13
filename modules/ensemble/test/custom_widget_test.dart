import 'package:ensemble/framework/widget/view_util.dart';
import 'package:ensemble/widget/custom_widget/custom_widget_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('custom widget call preserves explicit testId without requiring id', () {
    final customWidgets = {
      'MiniCard': loadYaml('''
body:
  Text:
    text: Devices
''') as YamlMap,
    };

    final model = ViewUtil.buildModel(
      loadYaml('''
MiniCard:
  testId: devices_mini_card
'''),
      customWidgets,
    ) as CustomWidgetModel;

    expect(model.props['testId'], 'devices_mini_card');
    expect(model.props.containsKey('id'), isFalse);
  });
}
