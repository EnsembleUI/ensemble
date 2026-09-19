import 'dart:convert';
import 'dart:io';

import 'package:ensemble_test_runner/execution/remote/remote_provider.dart';
import 'package:ensemble_test_runner/execution/remote/remote_run_store.dart';
import 'package:ensemble_test_runner/reporters/atomic_file.dart';
import 'package:path/path.dart' as p;

/// Local/dev durable store using atomic JSON files + version field.
class FileRemoteRunStore implements RemoteRunStore {
  final Directory root;

  FileRemoteRunStore(this.root) {
    root.createSync(recursive: true);
  }

  File _manifestFile(String runId) =>
      File(p.join(root.path, '$runId.manifest.json'));

  @override
  Future<void> putIntent(RemoteRunIntent intent) async {
    final existing = await get(intent.manifest.runId);
    if (existing != null && existing.version != intent.manifest.version) {
      throw StateError(
        'putIntent version conflict for ${intent.manifest.runId}',
      );
    }
    final withStatus = intent.manifest.copyWith(
      status: 'intent_persisted',
      updatedAt: DateTime.now().toUtc(),
    );
    AtomicFile.writeStringSync(
      _manifestFile(intent.manifest.runId),
      withStatus.encode(),
    );
    AtomicFile.writeStringSync(
      File(p.join(root.path, '${intent.manifest.runId}.intent.json')),
      json.encode({
        'appPackagePath': intent.appPackagePath,
        'testPackagePath': intent.testPackagePath,
        'manifest': withStatus.toJson(),
      }),
    );
  }

  @override
  Future<void> putProviderRef({
    required String runId,
    required RemoteProviderJobRef ref,
    required int expectedVersion,
  }) async {
    final current = await get(runId);
    if (current == null) {
      throw StateError('Unknown runId $runId');
    }
    if (current.version != expectedVersion) {
      throw StateError(
        'putProviderRef CAS failed for $runId '
        '(expected $expectedVersion, got ${current.version})',
      );
    }
    final next = current.copyWith(
      providerRef: ref,
      status: 'submitted',
      version: current.version + 1,
      updatedAt: DateTime.now().toUtc(),
    );
    final ok = await compareAndSwap(next: next, expectedVersion: expectedVersion);
    if (!ok) {
      throw StateError('putProviderRef CAS lost race for $runId');
    }
  }

  @override
  Future<RemoteRunManifest?> get(String runId) async {
    final file = _manifestFile(runId);
    if (!file.existsSync()) return null;
    return RemoteRunManifest.decode(file.readAsStringSync());
  }

  @override
  Future<bool> compareAndSwap({
    required RemoteRunManifest next,
    required int expectedVersion,
  }) async {
    final current = await get(next.runId);
    if (current == null) return false;
    if (current.version != expectedVersion) return false;
    AtomicFile.writeStringSync(_manifestFile(next.runId), next.encode());
    return true;
  }
}
