import 'dart:convert';

import 'package:ensemble_test_runner/execution/remote/setup/command_runner.dart';
import 'package:ensemble_test_runner/execution/remote/setup/remote_setup_models.dart';

/// Thin gcloud wrapper. Never creates service-account JSON keys.
class GcloudClient {
  final CommandRunner runner;

  GcloudClient(this.runner);

  Future<CommandResult> _gcloud(List<String> args) async {
    if (args.contains('keys') && args.contains('create')) {
      throw RemoteSetupException(
        'Refusing service-account JSON key creation. '
        'Use Workload Identity Federation only.',
      );
    }
    return runner.run('gcloud', args);
  }

  Future<void> ensureAvailable() async {
    final result = await _gcloud(['--version']);
    if (!result.ok) {
      throw RemoteSetupException(
        'gcloud is not available on PATH. Install the Google Cloud CLI and '
        'run `gcloud auth login`.\n${result.stderr}'.trim(),
      );
    }
  }

  Future<String> activeAccount() async {
    final result = await _gcloud(['config', 'get-value', 'account']);
    final account = result.stdout.trim();
    if (!result.ok || account.isEmpty || account == '(unset)') {
      throw RemoteSetupException(
        'No active gcloud account. Run `gcloud auth login` '
        '(and `gcloud auth application-default login` if needed).',
      );
    }
    return account;
  }

  Future<({String projectId, String projectNumber})> describeProject(
    String projectId,
  ) async {
    final result = await _gcloud([
      'projects',
      'describe',
      projectId,
      '--format=json',
    ]);
    if (!result.ok) {
      throw RemoteSetupException(
        'Cannot access project "$projectId": ${result.stderr.trim()}',
      );
    }
    final json = jsonDecode(result.stdout) as Map<String, dynamic>;
    final number = json['projectNumber']?.toString() ?? '';
    if (number.isEmpty) {
      throw RemoteSetupException(
        'Project "$projectId" did not return a projectNumber.',
      );
    }
    return (
      projectId: json['projectId']?.toString() ?? projectId,
      projectNumber: number,
    );
  }

  Future<bool> isBillingEnabled(String projectId) async {
    final result = await _gcloud([
      'billing',
      'projects',
      'describe',
      projectId,
      '--format=json',
    ]);
    if (!result.ok) {
      // Billing API may be restricted; treat as unknown → caller hard-fails.
      throw RemoteSetupException(
        'Cannot verify billing for "$projectId": ${result.stderr.trim()}\n'
        'Enable Cloud Billing on the project, then retry.',
      );
    }
    final json = jsonDecode(result.stdout) as Map<String, dynamic>;
    return json['billingEnabled'] == true;
  }

  Future<Set<String>> enabledApis(String projectId) async {
    final result = await _gcloud([
      'services',
      'list',
      '--enabled',
      '--project=$projectId',
      '--format=value(config.name)',
    ]);
    if (!result.ok) {
      throw RemoteSetupException(
        'Cannot list enabled APIs: ${result.stderr.trim()}',
      );
    }
    return result.stdout
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
  }

  Future<void> enableApi(String projectId, String api) async {
    final result = await _gcloud([
      'services',
      'enable',
      api,
      '--project=$projectId',
    ]);
    if (!result.ok && !_isAlreadyExists(result.stderr)) {
      throw RemoteSetupException(
        'Failed to enable $api: ${result.stderr.trim()}',
      );
    }
  }

  Future<bool> serviceAccountExists(
    String email, {
    String? projectId,
  }) async {
    final args = [
      'iam',
      'service-accounts',
      'describe',
      email,
      '--format=value(email)',
      if (projectId != null) '--project=$projectId',
    ];
    final result = await _gcloud(args);
    return result.ok && result.stdout.trim().isNotEmpty;
  }

  Future<void> createServiceAccount({
    required String projectId,
    required String accountId,
    required String displayName,
  }) async {
    final result = await _gcloud([
      'iam',
      'service-accounts',
      'create',
      accountId,
      '--project=$projectId',
      '--display-name=$displayName',
      '--description=Ensemble Test Runner Firebase Test Lab CI '
          '(Workload Identity Federation; no keys)',
    ]);
    if (!result.ok && !_isAlreadyExists(result.stderr)) {
      throw RemoteSetupException(
        'Failed to create service account: ${result.stderr.trim()}',
      );
    }
  }

  Future<bool> wifPoolExists(String projectId, String poolId) async {
    final result = await _gcloud([
      'iam',
      'workload-identity-pools',
      'describe',
      poolId,
      '--project=$projectId',
      '--location=global',
      '--format=value(name)',
    ]);
    return result.ok;
  }

  Future<void> createWifPool({
    required String projectId,
    required String poolId,
    required String displayName,
  }) async {
    final result = await _gcloud([
      'iam',
      'workload-identity-pools',
      'create',
      poolId,
      '--project=$projectId',
      '--location=global',
      '--display-name=$displayName',
    ]);
    if (!result.ok && !_isAlreadyExists(result.stderr)) {
      throw RemoteSetupException(
        'Failed to create WIF pool: ${result.stderr.trim()}',
      );
    }
  }

  Future<Map<String, dynamic>?> describeWifProvider({
    required String projectId,
    required String poolId,
    required String providerId,
  }) async {
    final result = await _gcloud([
      'iam',
      'workload-identity-pools',
      'providers',
      'describe',
      providerId,
      '--project=$projectId',
      '--location=global',
      '--workload-identity-pool=$poolId',
      '--format=json',
    ]);
    if (!result.ok) return null;
    return jsonDecode(result.stdout) as Map<String, dynamic>;
  }

  Future<void> createWifGithubProvider({
    required String projectId,
    required String poolId,
    required String providerId,
    required String repository,
  }) async {
    final result = await _gcloud([
      'iam',
      'workload-identity-pools',
      'providers',
      'create-oidc',
      providerId,
      '--project=$projectId',
      '--location=global',
      '--workload-identity-pool=$poolId',
      '--display-name=GitHub Actions',
      '--issuer-uri=https://token.actions.githubusercontent.com',
      '--attribute-mapping=google.subject=assertion.sub,'
          'attribute.repository=assertion.repository,'
          'attribute.actor=assertion.actor,'
          'attribute.aud=assertion.aud',
      '--attribute-condition=assertion.repository=="$repository"',
    ]);
    if (!result.ok && !_isAlreadyExists(result.stderr)) {
      throw RemoteSetupException(
        'Failed to create WIF provider: ${result.stderr.trim()}',
      );
    }
  }

  Future<void> updateWifProviderCondition({
    required String projectId,
    required String poolId,
    required String providerId,
    required String repository,
  }) async {
    final result = await _gcloud([
      'iam',
      'workload-identity-pools',
      'providers',
      'update-oidc',
      providerId,
      '--project=$projectId',
      '--location=global',
      '--workload-identity-pool=$poolId',
      '--attribute-condition=assertion.repository=="$repository"',
    ]);
    if (!result.ok) {
      throw RemoteSetupException(
        'Failed to update WIF provider condition: ${result.stderr.trim()}',
      );
    }
  }

  Future<bool> projectHasIamBinding({
    required String projectId,
    required String member,
    required String role,
  }) async {
    final result = await _gcloud([
      'projects',
      'get-iam-policy',
      projectId,
      '--format=json',
    ]);
    if (!result.ok) return false;
    return _policyHasBinding(result.stdout, member: member, role: role);
  }

  Future<void> addProjectIamBinding({
    required String projectId,
    required String member,
    required String role,
  }) async {
    final result = await _gcloud([
      'projects',
      'add-iam-policy-binding',
      projectId,
      '--member=$member',
      '--role=$role',
      // Required when the project policy already has conditional bindings.
      '--condition=None',
    ]);
    if (!result.ok && !_isAlreadyExists(result.stderr)) {
      throw RemoteSetupException(
        'Failed to add project IAM binding $role for $member: '
        '${result.stderr.trim()}',
      );
    }
  }

  Future<bool> serviceAccountHasIamBinding({
    required String serviceAccountEmail,
    required String member,
    required String role,
  }) async {
    final result = await _gcloud([
      'iam',
      'service-accounts',
      'get-iam-policy',
      serviceAccountEmail,
      '--format=json',
    ]);
    if (!result.ok) return false;
    return _policyHasBinding(result.stdout, member: member, role: role);
  }

  Future<void> addServiceAccountIamBinding({
    required String serviceAccountEmail,
    required String member,
    required String role,
  }) async {
    final result = await _gcloud([
      'iam',
      'service-accounts',
      'add-iam-policy-binding',
      serviceAccountEmail,
      '--member=$member',
      '--role=$role',
    ]);
    if (!result.ok && !_isAlreadyExists(result.stderr)) {
      throw RemoteSetupException(
        'Failed to add SA IAM binding $role for $member: '
        '${result.stderr.trim()}',
      );
    }
  }

  Future<bool> bucketExists(String bucket) async {
    final result = await _gcloud([
      'storage',
      'buckets',
      'describe',
      'gs://$bucket',
      '--format=value(name)',
    ]);
    return result.ok;
  }

  Future<void> createBucket({
    required String projectId,
    required String bucket,
    required String location,
  }) async {
    final result = await _gcloud([
      'storage',
      'buckets',
      'create',
      'gs://$bucket',
      '--project=$projectId',
      '--location=$location',
      '--uniform-bucket-level-access',
    ]);
    if (!result.ok && !_isAlreadyExists(result.stderr)) {
      throw RemoteSetupException(
        'Failed to create bucket gs://$bucket: ${result.stderr.trim()}\n'
        'If the name is taken by another project, choose a different project '
        'id or rename manually — setup never deletes existing buckets.',
      );
    }
  }

  Future<bool> bucketHasLifecycleRetention(
    String bucket, {
    required int days,
  }) async {
    final result = await _gcloud([
      'storage',
      'buckets',
      'describe',
      'gs://$bucket',
      '--format=json',
    ]);
    if (!result.ok) return false;
    final json = jsonDecode(result.stdout) as Map<String, dynamic>;
    final lifecycle = json['lifecycle'];
    if (lifecycle is! Map) return false;
    final rules = lifecycle['rule'];
    if (rules is! List) return false;
    for (final rule in rules) {
      if (rule is! Map) continue;
      final action = rule['action'];
      final condition = rule['condition'];
      if (action is Map &&
          action['type'] == 'Delete' &&
          condition is Map &&
          condition['age'] == days) {
        return true;
      }
    }
    return false;
  }

  Future<void> setBucketLifecycleFromFile({
    required String bucket,
    required String lifecycleFilePath,
  }) async {
    final result = await _gcloud([
      'storage',
      'buckets',
      'update',
      'gs://$bucket',
      '--lifecycle-file=$lifecycleFilePath',
    ]);
    if (!result.ok) {
      throw RemoteSetupException(
        'Failed to set lifecycle on gs://$bucket: ${result.stderr.trim()}',
      );
    }
  }

  Future<bool> bucketHasIamBinding({
    required String bucket,
    required String member,
    required String role,
  }) async {
    final result = await _gcloud([
      'storage',
      'buckets',
      'get-iam-policy',
      'gs://$bucket',
      '--format=json',
    ]);
    if (!result.ok) return false;
    return _policyHasBinding(result.stdout, member: member, role: role);
  }

  Future<void> addBucketIamBinding({
    required String bucket,
    required String member,
    required String role,
  }) async {
    final result = await _gcloud([
      'storage',
      'buckets',
      'add-iam-policy-binding',
      'gs://$bucket',
      '--member=$member',
      '--role=$role',
    ]);
    if (!result.ok && !_isAlreadyExists(result.stderr)) {
      throw RemoteSetupException(
        'Failed to add bucket IAM $role on gs://$bucket for $member: '
        '${result.stderr.trim()}',
      );
    }
  }

  bool _policyHasBinding(
    String policyJson, {
    required String member,
    required String role,
  }) {
    try {
      final json = jsonDecode(policyJson) as Map<String, dynamic>;
      final bindings = json['bindings'];
      if (bindings is! List) return false;
      for (final binding in bindings) {
        if (binding is! Map) continue;
        if (binding['role']?.toString() != role) continue;
        final members = binding['members'];
        if (members is List && members.map((e) => e.toString()).contains(member)) {
          return true;
        }
      }
    } catch (_) {
      return false;
    }
    return false;
  }

  /// Treat create races / soft-deleted reuse as success for idempotent setup.
  bool _isAlreadyExists(String stderr) {
    final text = stderr.toLowerCase();
    return text.contains('already exists') ||
        text.contains('already_exists') ||
        text.contains('already has') ||
        text.contains('already enabled') ||
        text.contains('conflict') ||
        text.contains('httpstatuscode: 409');
  }
}

/// Extracts attribute condition string from a WIF provider describe JSON.
String? wifAttributeCondition(Map<String, dynamic> providerJson) {
  final direct = providerJson['attributeCondition']?.toString();
  if (direct != null && direct.isNotEmpty) return direct;
  final oidc = providerJson['oidc'];
  if (oidc is Map) {
    final nested = oidc['attributeCondition']?.toString();
    if (nested != null && nested.isNotEmpty) return nested;
  }
  return null;
}
