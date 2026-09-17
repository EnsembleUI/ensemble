import 'dart:convert';
import 'dart:io';

import 'package:ensemble_test_runner/execution/remote/remote_progress.dart';
import 'package:http/http.dart' as http;

/// Low-level Firebase Test Lab / Testing API client contract.
///
/// Implementations must never embed GCP credentials in app packages.
abstract class FtlClient {
  Future<FtlSubmitResult> submitAndroidInstrumentation({
    required String projectId,
    required String appApkGcs,
    required String testApkGcs,
    required List<Map<String, String>> devices,
    required String clientToken,
    Map<String, String> environmentVariables = const {},
    List<String> directoriesToPull = const [],
  });

  Future<FtlSubmitResult> submitIosXcTest({
    required String projectId,
    required String testsZipGcs,
    required String xctestrunGcs,
    required List<Map<String, String>> devices,
    required String clientToken,
    Map<String, String> environmentVariables = const {},
  });

  Future<FtlJobSnapshot> getTestMatrix(String projectId, String matrixId);

  Future<List<FtlJobSnapshot>> listRecentMatrices(
    String projectId, {
    String? clientTokenPrefix,
  });

  Future<void> cancelTestMatrix(String projectId, String matrixId);

  Future<void> downloadGcsPrefix({
    required String gcsUri,
    required String localDirectory,
  });

  Future<String> uploadFile({
    required String projectId,
    required String localPath,
    required String objectName,
  });
}

class FtlSubmitResult {
  final String matrixId;
  final bool accepted;
  final bool uncertain;
  final String? detail;
  final String? historyId;
  final String? resultsUrl;

  const FtlSubmitResult({
    required this.matrixId,
    this.accepted = true,
    this.uncertain = false,
    this.detail,
    this.historyId,
    this.resultsUrl,
  });
}

FtlSubmitResult ftlSubmitResultFromResponse({
  required String projectId,
  required Map<String, dynamic> decoded,
  String? fallbackMatrixId,
  bool accepted = true,
  bool uncertain = false,
  String? detail,
}) {
  final matrixId =
      matrixIdFromTestMatrixJson(decoded) ?? fallbackMatrixId ?? '';
  return FtlSubmitResult(
    matrixId: matrixId,
    accepted: accepted,
    uncertain: uncertain,
    detail: detail,
    historyId: historyIdFromTestMatrixJson(decoded),
    resultsUrl: resultsUrlFromTestMatrixJson(decoded),
  );
}

class FtlJobSnapshot {
  final String matrixId;
  final String state;
  final String? outcome;
  final String? resultStorageGcs;
  final String? historyId;
  final String? resultsUrl;
  final Map<String, String> labels;
  final Map<String, dynamic> raw;

  const FtlJobSnapshot({
    required this.matrixId,
    required this.state,
    this.outcome,
    this.resultStorageGcs,
    this.historyId,
    this.resultsUrl,
    this.labels = const {},
    this.raw = const {},
  });
}

/// HTTP-backed FTL client using Application Default Credentials via gcloud
/// when available. Without credentials, operations throw [FtlCredentialException].
class HttpFtlClient implements FtlClient {
  final http.Client _http;
  final Future<String?> Function()? accessTokenProvider;
  final String resultsBucket;

  HttpFtlClient({
    http.Client? httpClient,
    this.accessTokenProvider,
    this.resultsBucket = '',
  }) : _http = httpClient ?? http.Client();

  Future<Map<String, String>> _authHeaders() async {
    final token = accessTokenProvider != null
        ? await accessTokenProvider!()
        : await _defaultAccessToken();
    if (token == null || token.isEmpty) {
      throw FtlCredentialException(
        'No GCP access token. Set Application Default Credentials or '
        'ENSEMBLE_TEST_FTL_ACCESS_TOKEN for real Firebase Test Lab runs.',
      );
    }
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  Future<String?> _defaultAccessToken() async {
    final fromEnv = Platform.environment['ENSEMBLE_TEST_FTL_ACCESS_TOKEN'];
    if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
    try {
      final result = await Process.run(
        'gcloud',
        ['auth', 'print-access-token'],
        runInShell: true,
      );
      if (result.exitCode == 0) {
        return (result.stdout as String).trim();
      }
    } catch (_) {
      // Fall through.
    }
    return null;
  }

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
    final headers = await _authHeaders();
    final body = {
      'projectId': projectId,
      'clientInfo': {'name': 'ensemble_test_runner', 'clientInfoDetails': []},
      'testSpecification': {
        'androidInstrumentationTest': {
          'appApk': {'gcsPath': appApkGcs},
          'testApk': {'gcsPath': testApkGcs},
        },
        'testTimeout': '1800s',
        if (directoriesToPull.isNotEmpty)
          'testSetup': {
            'directoriesToPull': directoriesToPull,
            if (environmentVariables.isNotEmpty)
              'environmentVariables': [
                for (final e in environmentVariables.entries)
                  {'key': e.key, 'value': e.value},
              ],
          },
      },
      'environmentMatrix': {
        'androidDeviceList': {
          'androidDevices': [
            for (final d in devices)
              {
                'androidModelId': d['model'],
                if (d['version'] != null) 'androidVersionId': d['version'],
                if (d['locale'] != null) 'locale': d['locale'],
                if (d['orientation'] != null) 'orientation': d['orientation'],
              },
          ],
        },
      },
      'resultStorage': {
        'googleCloudStorage': {
          'gcsPath': resultsBucket.isEmpty
              ? 'gs://$projectId-ftl-results/$clientToken'
              : 'gs://$resultsBucket/$clientToken',
        },
      },
      'flakyTestAttempts': 0,
    };

    final uri = Uri.parse(
      'https://testing.googleapis.com/v1/projects/$projectId/testMatrices',
    );
    final requestId = clientToken;
    final response = await _http.post(
      uri.replace(queryParameters: {'requestId': requestId}),
      headers: headers,
      body: json.encode(body),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = json.decode(response.body) as Map<String, dynamic>;
      return ftlSubmitResultFromResponse(
        projectId: projectId,
        decoded: decoded,
        fallbackMatrixId: clientToken,
      );
    }
    if (response.statusCode == 409) {
      return FtlSubmitResult(
        matrixId: clientToken,
        accepted: true,
        uncertain: true,
        detail: 'Conflict/idempotent retry: ${response.body}',
      );
    }
    if (response.statusCode >= 500) {
      return FtlSubmitResult(
        matrixId: '',
        accepted: false,
        uncertain: true,
        detail: 'Server error ${response.statusCode}: ${response.body}',
      );
    }
    throw FtlApiException(
      'FTL Android submit failed (${response.statusCode}): ${response.body}',
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
    final headers = await _authHeaders();
    final body = {
      'projectId': projectId,
      'clientInfo': {'name': 'ensemble_test_runner'},
      'testSpecification': {
        'iosTestLoop': null,
        'iosXcTest': {
          'testsZip': {'gcsPath': testsZipGcs},
          'xctestrun': {'gcsPath': xctestrunGcs},
        },
        'testTimeout': '1800s',
      },
      'environmentMatrix': {
        'iosDeviceList': {
          'iosDevices': [
            for (final d in devices)
              {
                'iosModelId': d['model'],
                if (d['version'] != null) 'iosVersionId': d['version'],
                if (d['locale'] != null) 'locale': d['locale'],
                if (d['orientation'] != null) 'orientation': d['orientation'],
              },
          ],
        },
      },
      'resultStorage': {
        'googleCloudStorage': {
          'gcsPath': resultsBucket.isEmpty
              ? 'gs://$projectId-ftl-results/$clientToken'
              : 'gs://$resultsBucket/$clientToken',
        },
      },
    };
    final uri = Uri.parse(
      'https://testing.googleapis.com/v1/projects/$projectId/testMatrices',
    );
    final response = await _http.post(
      uri.replace(queryParameters: {'requestId': clientToken}),
      headers: headers,
      body: json.encode(body),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = json.decode(response.body) as Map<String, dynamic>;
      return ftlSubmitResultFromResponse(
        projectId: projectId,
        decoded: decoded,
        fallbackMatrixId: clientToken,
      );
    }
    if (response.statusCode == 409 || response.statusCode >= 500) {
      return FtlSubmitResult(
        matrixId: clientToken,
        accepted: response.statusCode == 409,
        uncertain: true,
        detail: response.body,
      );
    }
    throw FtlApiException(
      'FTL iOS submit failed (${response.statusCode}): ${response.body}',
    );
  }

  @override
  Future<FtlJobSnapshot> getTestMatrix(String projectId, String matrixId) async {
    final headers = await _authHeaders();
    final uri = Uri.parse(
      'https://testing.googleapis.com/v1/projects/$projectId/testMatrices/$matrixId',
    );
    final response = await _http.get(uri, headers: headers);
    if (response.statusCode != 200) {
      throw FtlApiException(
        'getTestMatrix failed (${response.statusCode}): ${response.body}',
      );
    }
    final decoded = json.decode(response.body) as Map<String, dynamic>;
    final storage = decoded['resultStorage'];
    String? gcs;
    if (storage is Map) {
      final gcsNode = storage['googleCloudStorage'];
      if (gcsNode is Map) gcs = gcsNode['gcsPath']?.toString();
    }
    return FtlJobSnapshot(
      matrixId: matrixId,
      state: decoded['state']?.toString() ?? 'UNKNOWN',
      outcome: decoded['outcomeSummary']?.toString(),
      resultStorageGcs: gcs,
      historyId: historyIdFromTestMatrixJson(decoded),
      resultsUrl: resultsUrlFromTestMatrixJson(decoded),
      raw: decoded,
    );
  }

  @override
  Future<List<FtlJobSnapshot>> listRecentMatrices(
    String projectId, {
    String? clientTokenPrefix,
  }) async {
    // Testing API has limited list support; callers should prefer known ids.
    return const [];
  }

  @override
  Future<void> cancelTestMatrix(String projectId, String matrixId) async {
    final headers = await _authHeaders();
    final uri = Uri.parse(
      'https://testing.googleapis.com/v1/projects/$projectId/testMatrices/$matrixId:cancel',
    );
    final response = await _http.post(uri, headers: headers, body: '{}');
    if (response.statusCode >= 300) {
      throw FtlApiException(
        'cancel failed (${response.statusCode}): ${response.body}',
      );
    }
  }

  @override
  Future<void> downloadGcsPrefix({
    required String gcsUri,
    required String localDirectory,
  }) async {
    Directory(localDirectory).createSync(recursive: true);
    final result = await Process.run(
      'gsutil',
      ['-m', 'cp', '-r', gcsUri, localDirectory],
      runInShell: true,
    );
    if (result.exitCode != 0) {
      throw FtlApiException(
        'gsutil download failed: ${result.stderr}',
      );
    }
  }

  @override
  Future<String> uploadFile({
    required String projectId,
    required String localPath,
    required String objectName,
  }) async {
    final bucket =
        resultsBucket.isEmpty ? '$projectId-ftl-uploads' : resultsBucket;
    final gcs = 'gs://$bucket/$objectName';
    final file = File(localPath);
    final bytes = file.existsSync() ? file.lengthSync() : 0;
    final result = await Process.run(
      'gsutil',
      ['cp', localPath, gcs],
      runInShell: true,
    );
    if (result.exitCode != 0) {
      throw FtlApiException(
        'gsutil upload failed (${_formatBytes(bytes)} → $gcs): '
        '${result.stderr}',
      );
    }
    return gcs;
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KiB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MiB';
}

class FtlCredentialException implements Exception {
  final String message;
  FtlCredentialException(this.message);
  @override
  String toString() => message;
}

class FtlApiException implements Exception {
  final String message;
  FtlApiException(this.message);
  @override
  String toString() => message;
}
