/// Public API for running declarative YAML tests against Ensemble apps.
///
/// Use [runEnsembleYamlTests] to execute a discovered suite from a Flutter
/// test, or use [EnsembleTestParser] and the model types for tooling that needs
/// to inspect or build test definitions. The `ensemble_test` executable is the
/// recommended command-line entry point for application developers.
library ensemble_test_runner;

export 'discovery/ensemble_test_discovery.dart';
export 'entry/ensemble_test_entry.dart';
export 'entry/ensemble_integration_test_entry.dart';
export 'vocabulary/test_step_vocabulary.dart';
export 'actions/test_execution_config.dart';
export 'actions/test_step_executor.dart';
export 'assertions/assertion_engine.dart';
export 'models/ensemble_test_models.dart';
export 'mocks/test_api_provider_overlay.dart';
export 'mocks/test_logger.dart';
export 'parser/ensemble_test_parser.dart';
export 'schema/ensemble_test_schema_builder.dart';
export 'reporters/html_test_reporter.dart';
export 'reporters/test_reporter.dart';
export 'runner/ensemble_test_context.dart';
export 'runner/ensemble_test_harness.dart';
export 'runner/ensemble_test_runner.dart';
export 'session/session.dart';
export 'session/local/local_execution_session.dart';
export 'session/local/standalone_test_session_factory.dart';
export 'session/yaml/yaml_step_migration_matrix.dart';
export 'session/yaml/yaml_step_dispatcher.dart';
export 'session/yaml/session_step_routing.dart';
export 'execution/remote/remote_models.dart';
export 'execution/remote/remote_suite_validator.dart';
export 'execution/remote/remote_provider.dart';
export 'execution/remote/remote_orchestrator.dart';
export 'execution/remote/acceptance_ledger.dart';
export 'execution/remote/remote_report_reconciler.dart';
export 'execution/remote/native_build_service.dart';
export 'execution/remote/remote_run_store.dart';
export 'execution/remote/file_remote_run_store.dart';
export 'execution/remote/gcs_remote_run_store.dart';
export 'execution/remote/firebase_test_lab_provider.dart';
export 'execution/remote/fake_ftl_client.dart';
export 'execution/remote/ftl_client.dart';
