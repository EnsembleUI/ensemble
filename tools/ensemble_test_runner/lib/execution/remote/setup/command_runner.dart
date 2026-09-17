import 'dart:io';

/// Result of an external command invocation.
class CommandResult {
  final int exitCode;
  final String stdout;
  final String stderr;

  const CommandResult({
    required this.exitCode,
    this.stdout = '',
    this.stderr = '',
  });

  bool get ok => exitCode == 0;
}

/// Injectable process runner for gcloud (and tests).
abstract class CommandRunner {
  Future<CommandResult> run(
    String executable,
    List<String> arguments, {
    Map<String, String>? environment,
  });
}

class ProcessCommandRunner implements CommandRunner {
  @override
  Future<CommandResult> run(
    String executable,
    List<String> arguments, {
    Map<String, String>? environment,
  }) async {
    try {
      final result = await Process.run(
        executable,
        arguments,
        environment: environment,
        runInShell: true,
      );
      return CommandResult(
        exitCode: result.exitCode,
        stdout: (result.stdout ?? '').toString(),
        stderr: (result.stderr ?? '').toString(),
      );
    } on ProcessException catch (error) {
      return CommandResult(
        exitCode: 127,
        stderr: error.message,
      );
    }
  }
}

/// Records invocations for unit tests.
class FakeCommandRunner implements CommandRunner {
  final List<({String exe, List<String> args})> calls = [];
  final Map<String, CommandResult Function(List<String> args)> _handlers = {};
  CommandResult Function(String exe, List<String> args)? defaultHandler;
  bool rejectServiceAccountKeys = true;

  void when(
    String executable,
    CommandResult Function(List<String> args) handler,
  ) {
    _handlers[executable] = handler;
  }

  @override
  Future<CommandResult> run(
    String executable,
    List<String> arguments, {
    Map<String, String>? environment,
  }) async {
    calls.add((exe: executable, args: List<String>.from(arguments)));
    if (rejectServiceAccountKeys &&
        executable == 'gcloud' &&
        arguments.contains('keys') &&
        arguments.contains('create')) {
      throw StateError(
        'Refusing service-account JSON key creation. '
        'Use Workload Identity Federation only.',
      );
    }
    final handler = _handlers[executable];
    if (handler != null) return handler(arguments);
    if (defaultHandler != null) return defaultHandler!(executable, arguments);
    return CommandResult(
      exitCode: 1,
      stderr: 'No fake handler for $executable ${arguments.join(' ')}',
    );
  }

  bool get invokedGh => calls.any((c) => c.exe == 'gh');
}
