import 'dart:convert';
import 'dart:io';

import 'package:ensemble_test_runner/execution/remote/setup/gcloud_client.dart';
import 'package:ensemble_test_runner/execution/remote/setup/remote_setup_models.dart';

/// Applies mutating steps from a [RemoteSetupPlan]. Never deletes buckets.
class RemoteSetupApplier {
  final GcloudClient gcloud;

  RemoteSetupApplier(this.gcloud);

  Future<void> apply(RemoteSetupPlan plan) async {
    final saEmail = plan.ciConfig.serviceAccountEmail;
    final saMember = 'serviceAccount:$saEmail';
    final principalSet = RemoteSetupConstants.wifPrincipalSet(
      projectNumber: plan.projectNumber,
      poolId: RemoteSetupConstants.wifPoolId,
      repository: plan.repository,
    );

    for (final step in plan.steps) {
      if (!step.mutates) continue;
      switch (step.kind) {
        case SetupStepKind.enableApi:
          await gcloud.enableApi(plan.projectId, step.details['api']!);
        case SetupStepKind.createServiceAccount:
          await gcloud.createServiceAccount(
            projectId: plan.projectId,
            accountId: RemoteSetupConstants.serviceAccountId,
            displayName: 'Ensemble Test FTL CI',
          );
        case SetupStepKind.createWifPool:
          await gcloud.createWifPool(
            projectId: plan.projectId,
            poolId: RemoteSetupConstants.wifPoolId,
            displayName: RemoteSetupConstants.wifPoolDisplayName,
          );
        case SetupStepKind.createWifProvider:
          await gcloud.createWifGithubProvider(
            projectId: plan.projectId,
            poolId: RemoteSetupConstants.wifPoolId,
            providerId: RemoteSetupConstants.wifProviderId,
            repository: plan.repository,
          );
        case SetupStepKind.updateWifProviderCondition:
          await gcloud.updateWifProviderCondition(
            projectId: plan.projectId,
            poolId: RemoteSetupConstants.wifPoolId,
            providerId: RemoteSetupConstants.wifProviderId,
            repository: plan.repository,
          );
        case SetupStepKind.bindProjectIam:
          await gcloud.addProjectIamBinding(
            projectId: plan.projectId,
            member: saMember,
            role: step.details['role']!,
          );
        case SetupStepKind.bindWorkloadIdentityUser:
          await gcloud.addServiceAccountIamBinding(
            serviceAccountEmail: saEmail,
            member: principalSet,
            role: 'roles/iam.workloadIdentityUser',
          );
        case SetupStepKind.createBucket:
          await gcloud.createBucket(
            projectId: plan.projectId,
            bucket: step.details['bucket']!,
            location: 'US',
          );
        case SetupStepKind.setBucketLifecycle:
          await _setLifecycle(step.details['bucket']!);
        case SetupStepKind.bindBucketIam:
          await gcloud.addBucketIamBinding(
            bucket: step.details['bucket']!,
            member: saMember,
            role: step.details['role']!,
          );
      }
    }
  }

  Future<void> _setLifecycle(String bucket) async {
    final file = File(
      '${Directory.systemTemp.path}/ensemble_ftl_lifecycle_$bucket.json',
    );
    file.writeAsStringSync(
      jsonEncode({
        'rule': [
          {
            'action': {'type': 'Delete'},
            'condition': {
              'age': RemoteSetupConstants.artifactRetentionDays,
            },
          },
        ],
      }),
    );
    try {
      await gcloud.setBucketLifecycleFromFile(
        bucket: bucket,
        lifecycleFilePath: file.path,
      );
    } finally {
      if (file.existsSync()) file.deleteSync();
    }
  }
}
