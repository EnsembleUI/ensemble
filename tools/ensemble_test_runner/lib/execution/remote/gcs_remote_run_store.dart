import 'dart:convert';
import 'dart:io';

import 'package:ensemble_test_runner/execution/remote/remote_provider.dart';
import 'package:ensemble_test_runner/execution/remote/remote_run_store.dart';

/// CI-durable store using GCS objects with generation preconditions (CAS).
///
/// GitHub Actions artifacts must not be used as transactional CAS state.
class GcsRemoteRunStore implements RemoteRunStore {
  final String bucket;
  final String prefix;
  final Future<ProcessResult> Function(List<String> args) runGsutil;

  GcsRemoteRunStore({
    required this.bucket,
    this.prefix = 'ensemble-test-remote-runs',
    Future<ProcessResult> Function(List<String> args)? runGsutil,
  }) : runGsutil = runGsutil ??
            ((args) => Process.run('gsutil', args, runInShell: true));

  String _object(String runId) => 'gs://$bucket/$prefix/$runId.manifest.json';

  @override
  Future<void> putIntent(RemoteRunIntent intent) async {
    final withStatus = intent.manifest.copyWith(
      status: 'intent_persisted',
      updatedAt: DateTime.now().toUtc(),
    );
    final existing = await get(intent.manifest.runId);
    if (existing != null) {
      throw StateError(
        'putIntent: manifest already exists for ${intent.manifest.runId}',
      );
    }
    await _write(_object(intent.manifest.runId), withStatus.encode());
  }

  Future<void> _write(String gcsUri, String body) async {
    final tmp = File(
      '${Directory.systemTemp.path}/ensemble_remote_${DateTime.now().microsecondsSinceEpoch}.json',
    );
    tmp.writeAsStringSync(body);
    final result = await runGsutil(['cp', tmp.path, gcsUri]);
    tmp.deleteSync();
    if (result.exitCode != 0) {
      throw StateError('GCS write failed: ${result.stderr}');
    }
  }

  Future<({String body, String generation})?> _readWithGeneration(
    String runId,
  ) async {
    final gcsUri = _object(runId);
    final stat = await runGsutil(['stat', gcsUri]);
    if (stat.exitCode != 0) return null;
    final stdout = stat.stdout as String;
    final genMatch = RegExp(r'Generation:\s+(\d+)').firstMatch(stdout);
    final generation = genMatch?.group(1) ?? '0';
    final cat = await runGsutil(['cat', gcsUri]);
    if (cat.exitCode != 0) return null;
    return (body: cat.stdout as String, generation: generation);
  }

  @override
  Future<void> putProviderRef({
    required String runId,
    required RemoteProviderJobRef ref,
    required int expectedVersion,
  }) async {
    final current = await get(runId);
    if (current == null) throw StateError('Unknown runId $runId');
    if (current.version != expectedVersion) {
      throw StateError('putProviderRef CAS failed for $runId');
    }
    final next = current.copyWith(
      providerRef: ref,
      status: 'submitted',
      version: current.version + 1,
      updatedAt: DateTime.now().toUtc(),
    );
    final ok =
        await compareAndSwap(next: next, expectedVersion: expectedVersion);
    if (!ok) throw StateError('putProviderRef CAS lost race for $runId');
  }

  @override
  Future<RemoteRunManifest?> get(String runId) async {
    final read = await _readWithGeneration(runId);
    if (read == null) return null;
    return RemoteRunManifest.decode(read.body);
  }

  @override
  Future<bool> compareAndSwap({
    required RemoteRunManifest next,
    required int expectedVersion,
  }) async {
    final read = await _readWithGeneration(next.runId);
    if (read == null) return false;
    final current = RemoteRunManifest.decode(read.body);
    if (current.version != expectedVersion) return false;

    final tmp = File(
      '${Directory.systemTemp.path}/ensemble_remote_cas_${next.runId}.json',
    );
    tmp.writeAsStringSync(next.encode());
    final result = await runGsutil([
      '-h',
      'x-goog-if-generation-match:${read.generation}',
      'cp',
      tmp.path,
      _object(next.runId),
    ]);
    tmp.deleteSync();
    return result.exitCode == 0;
  }

  /// Optional checkpoint export for GHA artifacts (not CAS source of truth).
  Future<String> exportCheckpointJson(String runId) async {
    final manifest = await get(runId);
    if (manifest == null) {
      throw StateError('No manifest for $runId');
    }
    return json.encode({
      'checkpoint': true,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'manifest': manifest.toJson(),
    });
  }
}
