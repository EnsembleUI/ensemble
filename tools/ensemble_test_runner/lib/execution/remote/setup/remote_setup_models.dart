/// Stable names and printed CI configuration for remote FTL setup.
library;

class RemoteSetupConstants {
  static const serviceAccountId = 'ensemble-test-ftl-ci';
  static const wifPoolId = 'ensemble-test-ftl';
  static const wifProviderId = 'github';
  static const wifPoolDisplayName = 'Ensemble Test Runner FTL';
  static const artifactRetentionDays = 14;

  /// Project roles required to submit/collect Firebase Test Lab runs.
  /// See https://firebase.google.com/docs/test-lab/android/iam-permissions-reference
  static const projectRoles = <String>[
    'roles/cloudtestservice.testAdmin',
    'roles/firebase.analyticsViewer',
  ];

  static const requiredApis = <String>[
    'testing.googleapis.com',
    'toolresults.googleapis.com',
    'storage.googleapis.com',
    'iam.googleapis.com',
    'iamcredentials.googleapis.com',
    'cloudresourcemanager.googleapis.com',
    'sts.googleapis.com',
    'serviceusage.googleapis.com',
  ];

  static String serviceAccountEmail(String projectId) =>
      '$serviceAccountId@$projectId.iam.gserviceaccount.com';

  static String resultsBucket(String projectId) =>
      '$projectId-ensemble-ftl-results';

  static String remoteRunsBucket(String projectId) =>
      '$projectId-ensemble-remote-runs';

  static String wifProviderResource({
    required String projectNumber,
    required String poolId,
    required String providerId,
  }) =>
      'projects/$projectNumber/locations/global/workloadIdentityPools/'
      '$poolId/providers/$providerId';

  static String wifPrincipalSet({
    required String projectNumber,
    required String poolId,
    required String repository,
  }) =>
      'principalSet://iam.googleapis.com/projects/$projectNumber/'
      'locations/global/workloadIdentityPools/$poolId/'
      'attribute.repository/$repository';
}

/// Values the user pastes into any CI platform.
class RemoteCiConfig {
  final String projectId;
  final String resultsBucket;
  final String remoteStoreBucket;
  final String wifProvider;
  final String serviceAccountEmail;

  const RemoteCiConfig({
    required this.projectId,
    required this.resultsBucket,
    required this.remoteStoreBucket,
    required this.wifProvider,
    required this.serviceAccountEmail,
  });

  Map<String, String> get asEnv => {
        'ENSEMBLE_TEST_FTL_PROJECT_ID': projectId,
        'ENSEMBLE_TEST_FTL_RESULTS_BUCKET': resultsBucket,
        'ENSEMBLE_TEST_REMOTE_STORE_GCS_BUCKET': remoteStoreBucket,
        'ENSEMBLE_TEST_GCP_WIF_PROVIDER': wifProvider,
        'ENSEMBLE_TEST_GCP_SERVICE_ACCOUNT': serviceAccountEmail,
      };

  String formatBlock() {
    final buffer = StringBuffer()
      ..writeln('=== Ensemble remote CI configuration ===')
      ..writeln(
        'Add these as variables/secrets in your CI platform '
        '(GitHub Actions vars, GitLab CI/CD variables, etc.):',
      )
      ..writeln();
    for (final entry in asEnv.entries) {
      buffer.writeln('${entry.key}=${entry.value}');
    }
    return buffer.toString().trimRight();
  }
}

enum SetupStepKind {
  enableApi,
  createServiceAccount,
  createWifPool,
  createWifProvider,
  updateWifProviderCondition,
  bindProjectIam,
  bindWorkloadIdentityUser,
  createBucket,
  setBucketLifecycle,
  bindBucketIam,
}

enum SetupStepAction { create, reuse, repair, skip }

class SetupPlanStep {
  final SetupStepKind kind;
  final SetupStepAction action;
  final String description;
  final Map<String, String> details;

  const SetupPlanStep({
    required this.kind,
    required this.action,
    required this.description,
    this.details = const {},
  });

  bool get mutates =>
      action == SetupStepAction.create || action == SetupStepAction.repair;
}

class RemoteSetupPlan {
  final String projectId;
  final String projectNumber;
  final String repository;
  final String account;
  final List<SetupPlanStep> steps;
  final RemoteCiConfig ciConfig;

  const RemoteSetupPlan({
    required this.projectId,
    required this.projectNumber,
    required this.repository,
    required this.account,
    required this.steps,
    required this.ciConfig,
  });

  List<SetupPlanStep> get mutatingSteps =>
      steps.where((s) => s.mutates).toList();

  String formatProposedChanges() {
    final buffer = StringBuffer()
      ..writeln('Proposed GCP changes for project $projectId')
      ..writeln('  account: $account')
      ..writeln('  repository (WIF condition): $repository')
      ..writeln('  project number: $projectNumber')
      ..writeln();
    if (steps.isEmpty) {
      buffer.writeln('  (no steps)');
      return buffer.toString().trimRight();
    }
    for (final step in steps) {
      buffer.writeln('  [${step.action.name}] ${step.description}');
    }
    return buffer.toString().trimRight();
  }
}

enum DoctorSeverity { ok, warn, error }

class DoctorFinding {
  final DoctorSeverity severity;
  final String message;

  const DoctorFinding(this.severity, this.message);
}

class RemoteDoctorReport {
  final List<DoctorFinding> findings;
  final RemoteCiConfig? ciConfig;

  const RemoteDoctorReport({
    required this.findings,
    this.ciConfig,
  });

  bool get hasErrors =>
      findings.any((f) => f.severity == DoctorSeverity.error);

  String format() {
    final buffer = StringBuffer()..writeln('Ensemble remote doctor');
    for (final f in findings) {
      final tag = switch (f.severity) {
        DoctorSeverity.ok => 'OK',
        DoctorSeverity.warn => 'WARN',
        DoctorSeverity.error => 'ERROR',
      };
      buffer.writeln('[$tag] ${f.message}');
    }
    if (ciConfig != null && !hasErrors) {
      buffer
        ..writeln()
        ..writeln(ciConfig!.formatBlock());
    }
    return buffer.toString().trimRight();
  }
}

class RemoteSetupException implements Exception {
  final String message;
  RemoteSetupException(this.message);
  @override
  String toString() => message;
}

/// Validates `Owner/repo` shape for WIF attribute conditions.
String parseRepositorySlug(String raw) {
  final value = raw.trim();
  final match = RegExp(r'^([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)$').firstMatch(value);
  if (match == null) {
    throw RemoteSetupException(
      'Invalid --repo "$raw". Expected Owner/name '
      '(used only to restrict the WIF provider condition).',
    );
  }
  return '${match.group(1)}/${match.group(2)}';
}
