import 'package:ensemble_test_runner/session/yaml/session_step_routing.dart';
import 'package:ensemble_test_runner/session/yaml/yaml_step_path.dart';

export 'package:ensemble_test_runner/session/yaml/yaml_step_path.dart';

/// YAML step → session path routing.
///
/// Paths are derived from [TestStepRegistry] categories via
/// [SessionStepRouting] — do not maintain a parallel name table here.
abstract final class YamlStepMigrationMatrix {
  YamlStepMigrationMatrix._();

  static YamlStepPath? pathFor(String stepType) =>
      SessionStepRouting.pathFor(stepType);

  static bool isControlFlow(String stepType) =>
      pathFor(stepType) == YamlStepPath.control;
}
