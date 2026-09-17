import 'dart:convert';

import 'package:ensemble_test_runner/execution/remote/setup/command_runner.dart';
import 'package:ensemble_test_runner/execution/remote/setup/gcloud_client.dart';
import 'package:ensemble_test_runner/execution/remote/setup/remote_admin_cli.dart';
import 'package:ensemble_test_runner/execution/remote/setup/remote_setup_models.dart';
import 'package:ensemble_test_runner/execution/remote/setup/remote_setup_planner.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeGcloudState {
  bool gcloudAvailable = true;
  String? account = 'user@example.com';
  bool billingEnabled = true;
  final Set<String> enabledApis = {};
  final Set<String> serviceAccounts = {};
  final Set<String> wifPools = {};
  final Map<String, Map<String, dynamic>> wifProviders = {};
  final Set<String> buckets = {};
  final Set<String> bucketsWithLifecycle = {};
  final Set<String> projectBindings = {};
  final Set<String> saBindings = {};
  final Set<String> bucketBindings = {};
  final List<String> mutatingCommands = [];

  CommandResult handle(List<String> args) {
    if (!gcloudAvailable) {
      return const CommandResult(exitCode: 127, stderr: 'gcloud: not found');
    }
    if (args.isNotEmpty && args.first == '--version') {
      return const CommandResult(exitCode: 0, stdout: 'Google Cloud SDK 500.0.0');
    }
    if (args.length >= 3 &&
        args[0] == 'config' &&
        args[1] == 'get-value' &&
        args[2] == 'account') {
      if (account == null || account!.isEmpty) {
        return const CommandResult(exitCode: 0, stdout: '(unset)\n');
      }
      return CommandResult(exitCode: 0, stdout: '$account\n');
    }
    if (args.length >= 3 && args[0] == 'projects' && args[1] == 'describe') {
      return CommandResult(
        exitCode: 0,
        stdout: jsonEncode({
          'projectId': args[2],
          'projectNumber': '123456789',
        }),
      );
    }
    if (args.length >= 4 &&
        args[0] == 'billing' &&
        args[1] == 'projects' &&
        args[2] == 'describe') {
      return CommandResult(
        exitCode: 0,
        stdout: jsonEncode({'billingEnabled': billingEnabled}),
      );
    }
    if (args.length >= 2 && args[0] == 'services' && args[1] == 'list') {
      return CommandResult(
        exitCode: 0,
        stdout: '${enabledApis.join('\n')}\n',
      );
    }
    if (args.length >= 2 && args[0] == 'services' && args[1] == 'enable') {
      mutatingCommands.add(args.join(' '));
      enabledApis.add(args[2]);
      return const CommandResult(exitCode: 0);
    }
    if (args.length >= 3 &&
        args[0] == 'iam' &&
        args[1] == 'service-accounts' &&
        args[2] == 'describe') {
      final email = args[3];
      if (serviceAccounts.contains(email)) {
        return CommandResult(exitCode: 0, stdout: '$email\n');
      }
      return const CommandResult(exitCode: 1, stderr: 'NOT_FOUND');
    }
    if (args.length >= 3 &&
        args[0] == 'iam' &&
        args[1] == 'service-accounts' &&
        args[2] == 'create') {
      mutatingCommands.add(args.join(' '));
      final id = args[3];
      final project = args
          .firstWhere((a) => a.startsWith('--project='))
          .substring('--project='.length);
      serviceAccounts.add('$id@$project.iam.gserviceaccount.com');
      return const CommandResult(exitCode: 0);
    }
    if (args.length >= 3 &&
        args[0] == 'iam' &&
        args[1] == 'workload-identity-pools' &&
        args[2] == 'describe') {
      final pool = args[3];
      if (wifPools.contains(pool)) {
        return CommandResult(exitCode: 0, stdout: 'pools/$pool\n');
      }
      return const CommandResult(exitCode: 1, stderr: 'NOT_FOUND');
    }
    if (args.length >= 3 &&
        args[0] == 'iam' &&
        args[1] == 'workload-identity-pools' &&
        args[2] == 'create') {
      mutatingCommands.add(args.join(' '));
      wifPools.add(args[3]);
      return const CommandResult(exitCode: 0);
    }
    if (args.contains('providers') && args.contains('describe')) {
      final providerId = args[args.indexOf('providers') + 2];
      final json = wifProviders[providerId];
      if (json == null) {
        return const CommandResult(exitCode: 1, stderr: 'NOT_FOUND');
      }
      return CommandResult(exitCode: 0, stdout: jsonEncode(json));
    }
    if (args.contains('create-oidc')) {
      mutatingCommands.add(args.join(' '));
      final providerId = args[args.indexOf('create-oidc') + 1];
      final condition = args
          .firstWhere((a) => a.startsWith('--attribute-condition='))
          .substring('--attribute-condition='.length);
      wifPools.add('ensemble-test-ftl');
      wifProviders[providerId] = {'attributeCondition': condition};
      return const CommandResult(exitCode: 0);
    }
    if (args.contains('update-oidc')) {
      mutatingCommands.add(args.join(' '));
      final providerId = args[args.indexOf('update-oidc') + 1];
      final condition = args
          .firstWhere((a) => a.startsWith('--attribute-condition='))
          .substring('--attribute-condition='.length);
      wifProviders[providerId] = {'attributeCondition': condition};
      return const CommandResult(exitCode: 0);
    }
    if (args.length >= 3 &&
        args[0] == 'projects' &&
        args[1] == 'get-iam-policy') {
      return CommandResult(
        exitCode: 0,
        stdout: jsonEncode({
          'bindings': [
            for (final key in projectBindings)
              {
                'role': key.split('|').first,
                'members': [key.split('|').last],
              },
          ],
        }),
      );
    }
    if (args.contains('add-iam-policy-binding') && args[0] == 'projects') {
      mutatingCommands.add(args.join(' '));
      final member =
          args.firstWhere((a) => a.startsWith('--member=')).substring(9);
      final role = args.firstWhere((a) => a.startsWith('--role=')).substring(7);
      projectBindings.add('$role|$member');
      return const CommandResult(exitCode: 0);
    }
    if (args.length >= 4 &&
        args[0] == 'iam' &&
        args[1] == 'service-accounts' &&
        args[2] == 'get-iam-policy') {
      return CommandResult(
        exitCode: 0,
        stdout: jsonEncode({
          'bindings': [
            for (final key in saBindings)
              {
                'role': key.split('|').first,
                'members': [key.split('|').last],
              },
          ],
        }),
      );
    }
    if (args.length >= 4 &&
        args[0] == 'iam' &&
        args[1] == 'service-accounts' &&
        args[2] == 'add-iam-policy-binding') {
      mutatingCommands.add(args.join(' '));
      final member =
          args.firstWhere((a) => a.startsWith('--member=')).substring(9);
      final role = args.firstWhere((a) => a.startsWith('--role=')).substring(7);
      saBindings.add('$role|$member');
      return const CommandResult(exitCode: 0);
    }
    if (args.length >= 4 &&
        args[0] == 'storage' &&
        args[1] == 'buckets' &&
        args[2] == 'describe') {
      final name = args[3].replaceFirst('gs://', '');
      if (!buckets.contains(name)) {
        return const CommandResult(exitCode: 1, stderr: 'NOT_FOUND');
      }
      if (args.contains('--format=json')) {
        return CommandResult(
          exitCode: 0,
          stdout: jsonEncode({
            'name': name,
            if (bucketsWithLifecycle.contains(name))
              'lifecycle': {
                'rule': [
                  {
                    'action': {'type': 'Delete'},
                    'condition': {'age': 14},
                  },
                ],
              },
          }),
        );
      }
      return CommandResult(exitCode: 0, stdout: '$name\n');
    }
    if (args.length >= 4 &&
        args[0] == 'storage' &&
        args[1] == 'buckets' &&
        args[2] == 'create') {
      mutatingCommands.add(args.join(' '));
      final name = args[3].replaceFirst('gs://', '');
      buckets.add(name);
      return const CommandResult(exitCode: 0);
    }
    if (args.length >= 4 &&
        args[0] == 'storage' &&
        args[1] == 'buckets' &&
        args[2] == 'update') {
      mutatingCommands.add(args.join(' '));
      final name = args[3].replaceFirst('gs://', '');
      bucketsWithLifecycle.add(name);
      return const CommandResult(exitCode: 0);
    }
    if (args.length >= 4 &&
        args[0] == 'storage' &&
        args[1] == 'buckets' &&
        args[2] == 'get-iam-policy') {
      final name = args[3].replaceFirst('gs://', '');
      return CommandResult(
        exitCode: 0,
        stdout: jsonEncode({
          'bindings': [
            for (final key in bucketBindings)
              if (key.startsWith('$name|'))
                {
                  'role': key.split('|')[1],
                  'members': [key.split('|')[2]],
                },
          ],
        }),
      );
    }
    if (args.length >= 4 &&
        args[0] == 'storage' &&
        args[1] == 'buckets' &&
        args[2] == 'add-iam-policy-binding') {
      mutatingCommands.add(args.join(' '));
      final name = args[3].replaceFirst('gs://', '');
      final member =
          args.firstWhere((a) => a.startsWith('--member=')).substring(9);
      final role = args.firstWhere((a) => a.startsWith('--role=')).substring(7);
      bucketBindings.add('$name|$role|$member');
      return const CommandResult(exitCode: 0);
    }
    return CommandResult(
      exitCode: 1,
      stderr: 'unhandled fake gcloud: ${args.join(' ')}',
    );
  }
}

void main() {
  group('parseRepositorySlug', () {
    test('accepts Owner/name', () {
      expect(parseRepositorySlug('EnsembleUI/ensemble'), 'EnsembleUI/ensemble');
    });

    test('rejects invalid', () {
      expect(
        () => parseRepositorySlug('not-a-repo'),
        throwsA(isA<RemoteSetupException>()),
      );
    });
  });

  group('GcloudClient key refusal', () {
    test('refuses keys create', () async {
      final runner = FakeCommandRunner();
      runner.when(
        'gcloud',
        (_) => const CommandResult(exitCode: 0),
      );
      final client = GcloudClient(runner);
      expect(
        () => client.runner.run('gcloud', [
          'iam',
          'service-accounts',
          'keys',
          'create',
          'key.json',
        ]),
        throwsStateError,
      );
    });
  });

  group('RemoteAdminCli', () {
    late _FakeGcloudState state;
    late FakeCommandRunner runner;
    late StringBuffer out;
    late StringBuffer err;

    setUp(() {
      state = _FakeGcloudState();
      runner = FakeCommandRunner()..when('gcloud', state.handle);
      out = StringBuffer();
      err = StringBuffer();
    });

    RemoteAdminCli cli({bool Function(String)? confirm}) => RemoteAdminCli(
          commandRunner: runner,
          stdoutSink: out,
          stderrSink: err,
          confirmOverride: confirm,
        );

    test('doctor fails when gcloud missing', () async {
      state.gcloudAvailable = false;
      final code = await cli().run([
        'doctor',
        '--gcp-project=demo',
        '--repo=Owner/repo',
      ]);
      expect(code, 1);
      expect(err.toString() + out.toString(), contains('gcloud'));
    });

    test('doctor fails when unauthenticated', () async {
      state.account = null;
      final code = await cli().run([
        'doctor',
        '--gcp-project=demo',
        '--repo=Owner/repo',
      ]);
      expect(code, 1);
      expect(out.toString(), contains('No active gcloud account'));
    });

    test('dry-run prints plan and CI values without mutating', () async {
      final code = await cli().run([
        'setup',
        '--gcp-project=demo',
        '--repo=Owner/app',
        '--dry-run',
      ]);
      expect(code, 0);
      expect(state.mutatingCommands, isEmpty);
      expect(out.toString(), contains('[create]'));
      expect(out.toString(), contains('ENSEMBLE_TEST_FTL_PROJECT_ID=demo'));
      expect(
        out.toString(),
        contains('ENSEMBLE_TEST_GCP_SERVICE_ACCOUNT='),
      );
      expect(
        out.toString(),
        contains('workloadIdentityPools/ensemble-test-ftl/providers/github'),
      );
      expect(runner.invokedGh, isFalse);
    });

    test('setup creates resources then second run reuses', () async {
      final first = await cli(confirm: (_) => true).run([
        'setup',
        '--gcp-project=demo',
        '--repo=Owner/app',
        '--yes',
      ]);
      expect(first, 0);
      expect(state.mutatingCommands, isNotEmpty);
      expect(state.serviceAccounts, contains(contains('ensemble-test-ftl-ci')));
      expect(out.toString(), contains('Setup complete.'));
      expect(out.toString(), contains('ENSEMBLE_TEST_FTL_RESULTS_BUCKET='));

      final before = List<String>.from(state.mutatingCommands);
      out.clear();
      final second = await cli(confirm: (_) => true).run([
        'setup',
        '--gcp-project=demo',
        '--repo=Owner/app',
        '--yes',
      ]);
      expect(second, 0);
      expect(state.mutatingCommands, before);
      expect(out.toString(), contains('Nothing to do'));
      expect(out.toString(), contains('ENSEMBLE_TEST_FTL_PROJECT_ID=demo'));
    });

    test('repair updates drifted WIF condition', () async {
      state.enabledApis.addAll(RemoteSetupConstants.requiredApis);
      state.serviceAccounts
          .add('ensemble-test-ftl-ci@demo.iam.gserviceaccount.com');
      state.wifPools.add('ensemble-test-ftl');
      state.wifProviders['github'] = {
        'attributeCondition': 'assertion.repository=="Other/repo"',
      };
      state.buckets.addAll([
        'demo-ensemble-ftl-results',
        'demo-ensemble-remote-runs',
      ]);
      state.bucketsWithLifecycle.addAll(state.buckets);
      state.projectBindings.add(
        'roles/cloudtestservice.testAdmin|serviceAccount:ensemble-test-ftl-ci@demo.iam.gserviceaccount.com',
      );
      state.projectBindings.add(
        'roles/firebase.analyticsViewer|serviceAccount:ensemble-test-ftl-ci@demo.iam.gserviceaccount.com',
      );
      state.saBindings.add(
        'roles/iam.workloadIdentityUser|principalSet://iam.googleapis.com/projects/123456789/locations/global/workloadIdentityPools/ensemble-test-ftl/attribute.repository/Owner/app',
      );
      state.bucketBindings.addAll([
        'demo-ensemble-ftl-results|roles/storage.objectAdmin|serviceAccount:ensemble-test-ftl-ci@demo.iam.gserviceaccount.com',
        'demo-ensemble-remote-runs|roles/storage.objectAdmin|serviceAccount:ensemble-test-ftl-ci@demo.iam.gserviceaccount.com',
      ]);

      final withoutRepair = await RemoteSetupPlanner(GcloudClient(runner)).build(
        projectId: 'demo',
        repository: 'Owner/app',
        repair: false,
      );
      expect(
        withoutRepair.steps.any(
          (s) =>
              s.kind == SetupStepKind.updateWifProviderCondition &&
              s.action == SetupStepAction.skip,
        ),
        isTrue,
      );

      final code = await cli(confirm: (_) => true).run([
        'setup',
        '--gcp-project=demo',
        '--repo=Owner/app',
        '--repair',
        '--yes',
      ]);
      expect(code, 0);
      expect(
        state.wifProviders['github']?['attributeCondition'],
        contains('Owner/app'),
      );
      expect(
        state.mutatingCommands.any((c) => c.contains('update-oidc')),
        isTrue,
      );
    });

    test('aborts without confirmation', () async {
      final code = await cli(confirm: (_) => false).run([
        'setup',
        '--gcp-project=demo',
        '--repo=Owner/app',
      ]);
      expect(code, 2);
      expect(state.mutatingCommands, isEmpty);
      expect(err.toString(), contains('Aborted'));
    });

    test('billing disabled fails with clear error', () async {
      state.billingEnabled = false;
      final code = await cli().run([
        'setup',
        '--gcp-project=demo',
        '--repo=Owner/app',
        '--dry-run',
      ]);
      expect(code, 1);
      expect(err.toString(), contains('Billing is not enabled'));
    });

    test('invalid repo fails', () async {
      final code = await cli().run([
        'setup',
        '--gcp-project=demo',
        '--repo=bad',
        '--dry-run',
      ]);
      expect(code, 1);
      expect(err.toString(), contains('Invalid --repo'));
    });

    test('createServiceAccount treats already-exists as success', () async {
      final runner = FakeCommandRunner();
      runner.when(
        'gcloud',
        (args) {
          if (args.contains('create') && args.contains('service-accounts')) {
            return const CommandResult(
              exitCode: 1,
              stderr:
                  'ERROR: Resource is the subject of a conflict: '
                  'Service account ensemble-test-ftl-ci already exists',
            );
          }
          return const CommandResult(exitCode: 1, stderr: 'unexpected');
        },
      );
      final client = GcloudClient(runner);
      await client.createServiceAccount(
        projectId: 'demo',
        accountId: 'ensemble-test-ftl-ci',
        displayName: 'x',
      );
    });

    test('serviceAccountExists passes gcloud --project', () async {
      final runner = FakeCommandRunner();
      runner.when(
        'gcloud',
        (args) {
          expect(args, contains('--project=demo'));
          expect(args, contains('describe'));
          return const CommandResult(
            exitCode: 0,
            stdout: 'ensemble-test-ftl-ci@demo.iam.gserviceaccount.com\n',
          );
        },
      );
      final exists = await GcloudClient(runner).serviceAccountExists(
        'ensemble-test-ftl-ci@demo.iam.gserviceaccount.com',
        projectId: 'demo',
      );
      expect(exists, isTrue);
    });

    test('rejects legacy --project flag', () async {
      final code = await cli().run([
        'setup',
        '--project=demo',
        '--repo=Owner/app',
        '--dry-run',
      ]);
      expect(code, 1);
      expect(err.toString(), contains('--gcp-project'));
    });

    test('planner never emits bucket delete', () async {
      final plan = await RemoteSetupPlanner(GcloudClient(runner)).build(
        projectId: 'demo',
        repository: 'Owner/app',
      );
      expect(
        plan.steps.any(
          (s) => s.description.toLowerCase().contains('delete bucket'),
        ),
        isFalse,
      );
      expect(
        plan.formatProposedChanges().toLowerCase(),
        isNot(contains('set-iam-policy')),
      );
    });
  });
}
