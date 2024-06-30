import 'package:ensemble/action/navigation_action.dart';
import 'package:ensemble/framework/action.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('unmarshal action', () {
    const navigateBackMatcher = TypeMatcher<NavigateBackAction>();
    expect(EnsembleAction.from('navigateBack'), navigateBackMatcher);
    expect(EnsembleAction.from(YamlMap.wrap({'navigateBack': {}})),
        navigateBackMatcher);
    expect(EnsembleAction.from(YamlMap.wrap({'navigateBack': null})),
        navigateBackMatcher);

    const closeAllDialogsMatcher = TypeMatcher<CloseAllDialogsAction>();
    expect(EnsembleAction.from('closeAllDialogs'), closeAllDialogsMatcher);
    expect(EnsembleAction.from(YamlMap.wrap({'closeAllDialogs': {}})),
        closeAllDialogsMatcher);
  });
}
