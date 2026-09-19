import 'dart:io';

import 'package:ensemble_test_runner/execution/remote/setup/command_runner.dart';
import 'package:ensemble_test_runner/execution/remote/setup/gcloud_client.dart';
import 'package:ensemble_test_runner/execution/remote/setup/remote_doctor.dart';
import 'package:ensemble_test_runner/execution/remote/setup/remote_setup_applier.dart';
import 'package:ensemble_test_runner/execution/remote/setup/remote_setup_models.dart';
import 'package:ensemble_test_runner/execution/remote/setup/remote_setup_planner.dart';

/// CLI for `ensemble_test remote setup|doctor`.
class RemoteAdminCli {
  final CommandRunner commandRunner;
  final StringSink stdoutSink;
  final StringSink stderrSink;
  final String? Function()? readLine;
  final bool Function(String message)? confirmOverride;

  RemoteAdminCli({
    CommandRunner? commandRunner,
    StringSink? stdoutSink,
    StringSink? stderrSink,
    this.readLine,
    this.confirmOverride,
  })  : commandRunner = commandRunner ?? ProcessCommandRunner(),
        stdoutSink = stdoutSink ?? stdout,
        stderrSink = stderrSink ?? stderr;

  Future<int> run(List<String> arguments) async {
    if (arguments.isEmpty) {
      _usage();
      return 2;
    }
    final command = arguments.first;
    final rest = arguments.skip(1).toList();
    try {
      return switch (command) {
        'doctor' => await _doctor(rest),
        'setup' => await _setup(rest),
        'help' || '--help' || '-h' => () {
            _usage();
            return 0;
          }(),
        _ => () {
            stderrSink.writeln('Unknown remote command "$command".');
            _usage();
            return 2;
          }(),
      };
    } on RemoteSetupException catch (error) {
      stderrSink.writeln(error.message);
      return 1;
    }
  }

  Future<int> _doctor(List<String> args) async {
    final project = _requireGcpProject(args);
    final repo = _requireOption(args, '--repo');
    final gcloud = GcloudClient(commandRunner);
    final report = await RemoteDoctor(gcloud).run(
      projectId: project,
      repository: repo,
    );
    stdoutSink.writeln(report.format());
    return report.hasErrors ? 1 : 0;
  }

  Future<int> _setup(List<String> args) async {
    final project = _requireGcpProject(args);
    final repo = _requireOption(args, '--repo');
    final dryRun = args.contains('--dry-run');
    final repair = args.contains('--repair');
    final yes = args.contains('--yes');

    final gcloud = GcloudClient(commandRunner);
    final planner = RemoteSetupPlanner(gcloud);
    final plan = await planner.build(
      projectId: project,
      repository: repo,
      repair: repair,
    );

    stdoutSink.writeln(plan.formatProposedChanges());
    stdoutSink.writeln();

    if (dryRun) {
      stdoutSink.writeln('Dry run only — no changes were made.');
      stdoutSink.writeln();
      stdoutSink.writeln(plan.ciConfig.formatBlock());
      return 0;
    }

    final mutating = plan.mutatingSteps;
    if (mutating.isEmpty) {
      stdoutSink.writeln('Nothing to do — resources already configured.');
      stdoutSink.writeln();
      stdoutSink.writeln(plan.ciConfig.formatBlock());
      return 0;
    }

    final confirmed = yes ||
        (confirmOverride != null
            ? confirmOverride!(
                'Apply ${mutating.length} change(s)? Type yes to continue: ',
              )
            : _confirm(
                'Apply ${mutating.length} change(s)? Type yes to continue: ',
              ));
    if (!confirmed) {
      stderrSink.writeln('Aborted — no changes made.');
      return 2;
    }

    await RemoteSetupApplier(gcloud).apply(plan);
    stdoutSink.writeln('Setup complete.');
    stdoutSink.writeln();
    stdoutSink.writeln(plan.ciConfig.formatBlock());
    return 0;
  }

  bool _confirm(String prompt) {
    stdoutSink.write(prompt);
    final line = readLine != null ? readLine!() : stdin.readLineSync();
    return line != null && line.trim().toLowerCase() == 'yes';
  }

  String _requireGcpProject(List<String> args) {
    if (_optionValues(args, '--project').isNotEmpty) {
      throw RemoteSetupException(
        'Use --gcp-project=<id> (not --project). '
        '--gcp-project is the Google Cloud project for Firebase Test Lab.',
      );
    }
    return _requireOption(args, '--gcp-project');
  }

  List<String> _optionValues(List<String> args, String name) {
    final values = <String>[];
    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      if (arg.startsWith('$name=')) {
        values.add(arg.substring(name.length + 1));
      } else if (arg == name && i + 1 < args.length) {
        values.add(args[i + 1]);
      }
    }
    return values;
  }

  String _requireOption(List<String> args, String name) {
    final values = _optionValues(args, name);
    if (values.isEmpty || values.last.trim().isEmpty) {
      throw RemoteSetupException('Missing required $name');
    }
    if (values.length > 1) {
      throw RemoteSetupException('$name may be specified only once.');
    }
    return values.single.trim();
  }

  void _usage() {
    stdoutSink.writeln('''
ensemble_test remote — Firebase Test Lab GCP setup (gcloud only)

Usage:
  ensemble_test remote doctor --gcp-project=<id> --repo=<Owner/name>
  ensemble_test remote setup  --gcp-project=<id> --repo=<Owner/name> [options]

Options:
  --gcp-project   Google Cloud project ID for Firebase Test Lab / WIF / GCS
  --repo          GitHub Owner/name used only to restrict the WIF OIDC condition
  --dry-run       Print the plan and CI values; make no changes
  --repair        Fix drifted WIF conditions / missing pieces (never deletes buckets)
  --yes           Skip interactive confirmation

Setup never calls the GitHub API; it prints CI env values for you to paste
into GitHub Actions, GitLab, or any other platform.
'''.trim());
  }
}

/// Entry used by the main CLI when `arguments.first == 'remote'`.
Future<void> runRemoteAdminCli(
  List<String> remoteArgs, {
  CommandRunner? commandRunner,
}) async {
  final code = await RemoteAdminCli(commandRunner: commandRunner).run(remoteArgs);
  exit(code);
}
