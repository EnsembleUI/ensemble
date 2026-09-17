import 'package:ensemble_test_runner/cli/yaml_test_app_patcher.dart';
import 'package:ensemble_test_runner/execution/device_discovery.dart';
import 'package:ensemble_test_runner/execution/device_selector.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';

abstract class ExecutionBackend {
  ExecutionMode get mode;
  bool get supportsParallel;
  bool get hostOwnsServices;
  String get entryRelativePath;

  Future<FlutterDevice?> selectDevice(List<String> arguments);
}

class WidgetExecutionBackend implements ExecutionBackend {
  const WidgetExecutionBackend();

  @override
  ExecutionMode get mode => ExecutionMode.widget;

  @override
  bool get supportsParallel => true;

  @override
  bool get hostOwnsServices => false;

  @override
  String get entryRelativePath => YamlTestAppPatcher.testEntryRelativePath;

  @override
  Future<FlutterDevice?> selectDevice(List<String> arguments) async => null;
}

class IntegrationExecutionBackend implements ExecutionBackend {
  const IntegrationExecutionBackend();

  @override
  ExecutionMode get mode => ExecutionMode.integration;

  @override
  bool get supportsParallel => false;

  @override
  bool get hostOwnsServices => true;

  @override
  String get entryRelativePath =>
      YamlTestAppPatcher.integrationTestEntryRelativePath;

  @override
  Future<FlutterDevice?> selectDevice(List<String> arguments) =>
      selectIntegrationDevice(arguments);
}

ExecutionBackend executionBackendFor(ExecutionMode mode) =>
    mode == ExecutionMode.integration
        ? const IntegrationExecutionBackend()
        : const WidgetExecutionBackend();
