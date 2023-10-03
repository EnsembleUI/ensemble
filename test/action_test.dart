import 'package:ensemble/action/navigation_action.dart';
import 'package:ensemble/framework/action.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('unmarshal action', () {
    const navigateBackMatcher = TypeMatcher<NavigateBackAction>();
    expect(EnsembleAction.fromYaml('navigateBack'), navigateBackMatcher);
    expect(EnsembleAction.fromYaml(YamlMap.wrap({'navigateBack': {}})),
        navigateBackMatcher);
    expect(EnsembleAction.fromYaml(YamlMap.wrap({'navigateBack': null})),
        navigateBackMatcher);

    const closeAllDialogsMatcher = TypeMatcher<CloseAllDialogsAction>();
    expect(EnsembleAction.fromYaml('closeAllDialogs'), closeAllDialogsMatcher);
    expect(EnsembleAction.fromYaml(YamlMap.wrap({'closeAllDialogs': {}})),
        closeAllDialogsMatcher);
  });
}
