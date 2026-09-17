import 'package:ensemble_test_runner/execution/remote/setup/gcloud_client.dart';
import 'package:ensemble_test_runner/execution/remote/setup/remote_setup_models.dart';

/// Discovers GCP state and builds an idempotent create/reuse/repair plan.
class RemoteSetupPlanner {
  final GcloudClient gcloud;

  RemoteSetupPlanner(this.gcloud);

  Future<RemoteSetupPlan> build({
    required String projectId,
    required String repository,
    bool repair = false,
  }) async {
    final repo = parseRepositorySlug(repository);
    await gcloud.ensureAvailable();
    final account = await gcloud.activeAccount();
    final project = await gcloud.describeProject(projectId);
    final billing = await gcloud.isBillingEnabled(project.projectId);
    if (!billing) {
      throw RemoteSetupException(
        'Billing is not enabled on project "${project.projectId}". '
        'Firebase Test Lab and GCS require an active Cloud Billing account.',
      );
    }

    final saEmail =
        RemoteSetupConstants.serviceAccountEmail(project.projectId);
    final resultsBucket =
        RemoteSetupConstants.resultsBucket(project.projectId);
    final remoteBucket =
        RemoteSetupConstants.remoteRunsBucket(project.projectId);
    final expectedCondition = 'assertion.repository=="$repo"';
    final principalSet = RemoteSetupConstants.wifPrincipalSet(
      projectNumber: project.projectNumber,
      poolId: RemoteSetupConstants.wifPoolId,
      repository: repo,
    );
    final wifProvider = RemoteSetupConstants.wifProviderResource(
      projectNumber: project.projectNumber,
      poolId: RemoteSetupConstants.wifPoolId,
      providerId: RemoteSetupConstants.wifProviderId,
    );
    final saMember = 'serviceAccount:$saEmail';

    final steps = <SetupPlanStep>[];

    final enabled = await gcloud.enabledApis(project.projectId);
    for (final api in RemoteSetupConstants.requiredApis) {
      if (enabled.contains(api)) {
        steps.add(
          SetupPlanStep(
            kind: SetupStepKind.enableApi,
            action: SetupStepAction.reuse,
            description: 'API already enabled: $api',
            details: {'api': api},
          ),
        );
      } else {
        steps.add(
          SetupPlanStep(
            kind: SetupStepKind.enableApi,
            action: SetupStepAction.create,
            description: 'Enable API $api',
            details: {'api': api},
          ),
        );
      }
    }

    final saExists = await gcloud.serviceAccountExists(
      saEmail,
      projectId: project.projectId,
    );
    steps.add(
      SetupPlanStep(
        kind: SetupStepKind.createServiceAccount,
        action: saExists ? SetupStepAction.reuse : SetupStepAction.create,
        description: saExists
            ? 'Reuse service account $saEmail'
            : 'Create service account $saEmail (no keys)',
        details: {'email': saEmail},
      ),
    );

    final poolExists = await gcloud.wifPoolExists(
      project.projectId,
      RemoteSetupConstants.wifPoolId,
    );
    steps.add(
      SetupPlanStep(
        kind: SetupStepKind.createWifPool,
        action: poolExists ? SetupStepAction.reuse : SetupStepAction.create,
        description: poolExists
            ? 'Reuse WIF pool ${RemoteSetupConstants.wifPoolId}'
            : 'Create WIF pool ${RemoteSetupConstants.wifPoolId}',
        details: {'poolId': RemoteSetupConstants.wifPoolId},
      ),
    );

    final provider = poolExists
        ? await gcloud.describeWifProvider(
            projectId: project.projectId,
            poolId: RemoteSetupConstants.wifPoolId,
            providerId: RemoteSetupConstants.wifProviderId,
          )
        : null;
    if (provider == null) {
      steps.add(
        SetupPlanStep(
          kind: SetupStepKind.createWifProvider,
          action: SetupStepAction.create,
          description:
              'Create GitHub OIDC WIF provider restricted to $repo',
          details: {'repository': repo},
        ),
      );
    } else {
      final condition = wifAttributeCondition(provider) ?? '';
      final matches = condition.contains(repo);
      if (!matches && repair) {
        steps.add(
          SetupPlanStep(
            kind: SetupStepKind.updateWifProviderCondition,
            action: SetupStepAction.repair,
            description:
                'Repair WIF provider condition to assertion.repository=="$repo"',
            details: {
              'repository': repo,
              'currentCondition': condition,
            },
          ),
        );
      } else if (!matches) {
        steps.add(
          SetupPlanStep(
            kind: SetupStepKind.updateWifProviderCondition,
            action: SetupStepAction.skip,
            description:
                'WIF provider exists with different condition ($condition). '
                'Re-run with --repair to update to $expectedCondition.',
            details: {'repository': repo, 'currentCondition': condition},
          ),
        );
      } else {
        steps.add(
          SetupPlanStep(
            kind: SetupStepKind.createWifProvider,
            action: SetupStepAction.reuse,
            description: 'Reuse WIF provider for $repo',
            details: {'repository': repo},
          ),
        );
      }
    }

    for (final projectRole in RemoteSetupConstants.projectRoles) {
      final hasProjectRole = await gcloud.projectHasIamBinding(
        projectId: project.projectId,
        member: saMember,
        role: projectRole,
      );
      steps.add(
        SetupPlanStep(
          kind: SetupStepKind.bindProjectIam,
          action:
              hasProjectRole ? SetupStepAction.reuse : SetupStepAction.create,
          description: hasProjectRole
              ? 'Reuse project IAM $projectRole for CI SA'
              : 'Grant $projectRole to CI SA (additive binding only)',
          details: {'role': projectRole, 'member': saMember},
        ),
      );
    }

    const wiRole = 'roles/iam.workloadIdentityUser';
    final hasWi = await gcloud.serviceAccountHasIamBinding(
      serviceAccountEmail: saEmail,
      member: principalSet,
      role: wiRole,
    );
    steps.add(
      SetupPlanStep(
        kind: SetupStepKind.bindWorkloadIdentityUser,
        action: hasWi ? SetupStepAction.reuse : SetupStepAction.create,
        description: hasWi
            ? 'Reuse workloadIdentityUser for $repo'
            : 'Allow repository $repo to impersonate CI SA via WIF',
        details: {'member': principalSet, 'role': wiRole},
      ),
    );

    for (final bucket in [resultsBucket, remoteBucket]) {
      final exists = await gcloud.bucketExists(bucket);
      steps.add(
        SetupPlanStep(
          kind: SetupStepKind.createBucket,
          action: exists ? SetupStepAction.reuse : SetupStepAction.create,
          description: exists
              ? 'Reuse bucket gs://$bucket'
              : 'Create bucket gs://$bucket',
          details: {'bucket': bucket},
        ),
      );

      final hasLifecycle = exists &&
          await gcloud.bucketHasLifecycleRetention(
            bucket,
            days: RemoteSetupConstants.artifactRetentionDays,
          );
      if (!exists) {
        steps.add(
          SetupPlanStep(
            kind: SetupStepKind.setBucketLifecycle,
            action: SetupStepAction.create,
            description:
                'Set ${RemoteSetupConstants.artifactRetentionDays}-day '
                'object retention on gs://$bucket',
            details: {'bucket': bucket},
          ),
        );
      } else if (!hasLifecycle) {
        steps.add(
          SetupPlanStep(
            kind: SetupStepKind.setBucketLifecycle,
            action: repair ? SetupStepAction.repair : SetupStepAction.create,
            description:
                'Set ${RemoteSetupConstants.artifactRetentionDays}-day '
                'object retention on gs://$bucket',
            details: {'bucket': bucket},
          ),
        );
      } else {
        steps.add(
          SetupPlanStep(
            kind: SetupStepKind.setBucketLifecycle,
            action: SetupStepAction.reuse,
            description: 'Lifecycle already set on gs://$bucket',
            details: {'bucket': bucket},
          ),
        );
      }

      const objectAdmin = 'roles/storage.objectAdmin';
      final hasBucketIam = exists &&
          await gcloud.bucketHasIamBinding(
            bucket: bucket,
            member: saMember,
            role: objectAdmin,
          );
      steps.add(
        SetupPlanStep(
          kind: SetupStepKind.bindBucketIam,
          action: hasBucketIam ? SetupStepAction.reuse : SetupStepAction.create,
          description: hasBucketIam
              ? 'Reuse $objectAdmin on gs://$bucket'
              : 'Grant $objectAdmin on gs://$bucket to CI SA',
          details: {'bucket': bucket, 'role': objectAdmin, 'member': saMember},
        ),
      );
    }

    return RemoteSetupPlan(
      projectId: project.projectId,
      projectNumber: project.projectNumber,
      repository: repo,
      account: account,
      steps: steps,
      ciConfig: RemoteCiConfig(
        projectId: project.projectId,
        resultsBucket: resultsBucket,
        remoteStoreBucket: remoteBucket,
        wifProvider: wifProvider,
        serviceAccountEmail: saEmail,
      ),
    );
  }
}
