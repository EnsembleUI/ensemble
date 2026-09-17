import 'package:ensemble_test_runner/execution/remote/setup/gcloud_client.dart';
import 'package:ensemble_test_runner/execution/remote/setup/remote_setup_models.dart';
import 'package:ensemble_test_runner/execution/remote/setup/remote_setup_planner.dart';

/// Read-only health check for remote FTL GCP prerequisites.
class RemoteDoctor {
  final GcloudClient gcloud;

  RemoteDoctor(this.gcloud);

  Future<RemoteDoctorReport> run({
    required String projectId,
    required String repository,
  }) async {
    final findings = <DoctorFinding>[];
    RemoteCiConfig? ciConfig;

    try {
      await gcloud.ensureAvailable();
      findings.add(const DoctorFinding(DoctorSeverity.ok, 'gcloud is available'));
    } on RemoteSetupException catch (error) {
      findings.add(DoctorFinding(DoctorSeverity.error, error.message));
      return RemoteDoctorReport(findings: findings);
    }

    try {
      final account = await gcloud.activeAccount();
      findings.add(
        DoctorFinding(DoctorSeverity.ok, 'Active gcloud account: $account'),
      );
    } on RemoteSetupException catch (error) {
      findings.add(DoctorFinding(DoctorSeverity.error, error.message));
      return RemoteDoctorReport(findings: findings);
    }

    try {
      parseRepositorySlug(repository);
    } on RemoteSetupException catch (error) {
      findings.add(DoctorFinding(DoctorSeverity.error, error.message));
      return RemoteDoctorReport(findings: findings);
    }

    try {
      final plan = await RemoteSetupPlanner(gcloud).build(
        projectId: projectId,
        repository: repository,
        repair: false,
      );
      ciConfig = plan.ciConfig;

      final pending = plan.mutatingSteps;
      if (pending.isEmpty) {
        findings.add(
          const DoctorFinding(
            DoctorSeverity.ok,
            'All GCP resources and bindings are present',
          ),
        );
      } else {
        for (final step in pending) {
          findings.add(
            DoctorFinding(
              DoctorSeverity.warn,
              'Missing or incomplete: ${step.description}',
            ),
          );
        }
        findings.add(
          const DoctorFinding(
            DoctorSeverity.error,
            'Run `ensemble_test remote setup --gcp-project=... --repo=...` '
            '(or --repair) to fix.',
          ),
        );
      }

      // Drift that requires --repair (skip action on condition).
      for (final step in plan.steps) {
        if (step.kind == SetupStepKind.updateWifProviderCondition &&
            step.action == SetupStepAction.skip) {
          findings.add(
            DoctorFinding(DoctorSeverity.warn, step.description),
          );
        }
      }
    } on RemoteSetupException catch (error) {
      findings.add(DoctorFinding(DoctorSeverity.error, error.message));
    }

    return RemoteDoctorReport(findings: findings, ciConfig: ciConfig);
  }
}
