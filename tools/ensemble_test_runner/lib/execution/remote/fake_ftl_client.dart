import 'dart:io';

import 'package:ensemble_test_runner/execution/remote/ftl_client.dart';
import 'package:path/path.dart' as p;

/// In-memory FTL client for contract tests (never satisfies production acceptance).
class FakeFtlClient implements FtlClient {
  final Map<String, FtlJobSnapshot> matrices = {};
  final List<Map<String, dynamic>> submitLog = [];
  bool failNextSubmit = false;
  bool uncertainNextSubmit = false;
  bool throwCredentialError = false;
  Duration? artificialDelay;

  @override
  Future<FtlSubmitResult> submitAndroidInstrumentation({
    required String projectId,
    required String appApkGcs,
    required String testApkGcs,
    required List<Map<String, String>> devices,
    required String clientToken,
    Map<String, String> environmentVariables = const {},
    List<String> directoriesToPull = const [],
  }) async {
    return _submit(
      projectId: projectId,
      clientToken: clientToken,
      kind: 'android',
      payload: {
        'appApkGcs': appApkGcs,
        'testApkGcs': testApkGcs,
        'devices': devices,
        'environmentVariables': environmentVariables,
        'directoriesToPull': directoriesToPull,
      },
    );
  }

  @override
  Future<FtlSubmitResult> submitIosXcTest({
    required String projectId,
    required String testsZipGcs,
    required String xctestrunGcs,
    required List<Map<String, String>> devices,
    required String clientToken,
    Map<String, String> environmentVariables = const {},
  }) async {
    return _submit(
      projectId: projectId,
      clientToken: clientToken,
      kind: 'ios',
      payload: {
        'testsZipGcs': testsZipGcs,
        'xctestrunGcs': xctestrunGcs,
        'devices': devices,
        'environmentVariables': environmentVariables,
      },
    );
  }

  Future<FtlSubmitResult> _submit({
    required String projectId,
    required String clientToken,
    required String kind,
    required Map<String, dynamic> payload,
  }) async {
    if (throwCredentialError) {
      throw FtlCredentialException('fake: no credentials');
    }
    if (artificialDelay != null) {
      await Future<void>.delayed(artificialDelay!);
    }
    submitLog.add({'kind': kind, 'clientToken': clientToken, ...payload});
    if (failNextSubmit) {
      failNextSubmit = false;
      return const FtlSubmitResult(
        matrixId: '',
        accepted: false,
        detail: 'rejected',
      );
    }
    if (uncertainNextSubmit) {
      uncertainNextSubmit = false;
      final existing = matrices[clientToken];
      if (existing != null) {
        return FtlSubmitResult(
          matrixId: existing.matrixId,
          accepted: true,
          uncertain: true,
          detail: 'uncertain accept; existing matrix',
        );
      }
      return FtlSubmitResult(
        matrixId: '',
        accepted: false,
        uncertain: true,
        detail: 'uncertain accept; no matrix yet',
      );
    }
    final matrixId = 'matrix-$clientToken';
    matrices[clientToken] = FtlJobSnapshot(
      matrixId: matrixId,
      state: 'RUNNING',
      resultStorageGcs: 'gs://fake-bucket/$clientToken',
      labels: {'clientToken': clientToken, 'projectId': projectId},
    );
    matrices[matrixId] = matrices[clientToken]!;
    return FtlSubmitResult(
      matrixId: matrixId,
      accepted: true,
      historyId: 'hist-$projectId',
    );
  }

  void finish(String matrixId, {String outcome = 'SUCCESS'}) {
    final current = matrices[matrixId];
    if (current == null) return;
    final finished = FtlJobSnapshot(
      matrixId: matrixId,
      state: 'FINISHED',
      outcome: outcome,
      resultStorageGcs: current.resultStorageGcs,
      labels: current.labels,
    );
    matrices[matrixId] = finished;
    for (final entry in matrices.entries.toList()) {
      if (entry.value.matrixId == matrixId) {
        matrices[entry.key] = finished;
      }
    }
  }

  @override
  Future<FtlJobSnapshot> getTestMatrix(String projectId, String matrixId) async {
    final snap = matrices[matrixId];
    if (snap == null) {
      throw FtlApiException('Unknown matrix $matrixId');
    }
    return snap;
  }

  @override
  Future<List<FtlJobSnapshot>> listRecentMatrices(
    String projectId, {
    String? clientTokenPrefix,
  }) async {
    final seen = <String>{};
    final out = <FtlJobSnapshot>[];
    for (final snap in matrices.values) {
      if (!seen.add(snap.matrixId)) continue;
      if (clientTokenPrefix != null) {
        final token = snap.labels['clientToken'] ?? '';
        if (!token.startsWith(clientTokenPrefix)) continue;
      }
      out.add(snap);
    }
    return out;
  }

  @override
  Future<void> cancelTestMatrix(String projectId, String matrixId) async {
    final current = matrices[matrixId];
    if (current == null) return;
    matrices[matrixId] = FtlJobSnapshot(
      matrixId: matrixId,
      state: 'CANCELLED',
      outcome: 'CANCELLED',
      resultStorageGcs: current.resultStorageGcs,
      labels: current.labels,
    );
  }

  @override
  Future<void> downloadGcsPrefix({
    required String gcsUri,
    required String localDirectory,
  }) async {
    final dir = Directory(localDirectory)..createSync(recursive: true);
    final token = gcsUri.split('/').last;
    final envelopeDir = Directory(p.join(dir.path, 'remote'))
      ..createSync(recursive: true);
    await File(p.join(envelopeDir.path, 'envelope.json')).writeAsString(
      '{"version":1,"runId":"$token","complete":true,"results":{"results":[],'
      '"suiteLogs":[],"metadata":{}},"cleanupErrors":[],"artifacts":[]}',
    );
  }

  @override
  Future<String> uploadFile({
    required String projectId,
    required String localPath,
    required String objectName,
  }) async {
    return 'gs://fake-bucket/$objectName';
  }
}
