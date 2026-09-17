import 'dart:io';

/// Progress callback for remote orchestration (build → submit → poll → collect).
typedef RemoteProgress = void Function(String message);

/// Writes to stderr and flushes so GitHub Actions shows progress immediately
/// (stdout is often fully buffered when not attached to a TTY).
RemoteProgress stderrRemoteProgress({String prefix = '[ensemble_test remote] '}) {
  return (message) {
    stderr.writeln('$prefix$message');
    stderr.flush();
  };
}

/// Firebase / Cloud console URLs for a Test Lab matrix (best-effort).
class FtlConsoleLinks {
  final String projectId;
  final String matrixId;
  final String? historyId;

  const FtlConsoleLinks({
    required this.projectId,
    required this.matrixId,
    this.historyId,
  });

  /// Direct matrix page when [historyId] is known from the Testing API.
  String get matrixUrl {
    if (historyId != null && historyId!.isNotEmpty) {
      return 'https://console.firebase.google.com/project/$projectId/'
          'testlab/histories/$historyId/matrices/$matrixId';
    }
    return historiesUrl;
  }

  String get historiesUrl =>
      'https://console.firebase.google.com/project/$projectId/testlab/histories/';

  String get cloudHistoriesUrl =>
      'https://console.cloud.google.com/test-lab/histories?project=$projectId';

  Map<String, String> toMetadata() => {
        'consoleUrl': matrixUrl,
        'historiesUrl': historiesUrl,
        'cloudHistoriesUrl': cloudHistoriesUrl,
        if (historyId != null && historyId!.isNotEmpty) 'historyId': historyId!,
      };
}

String? historyIdFromTestMatrixJson(Map<String, dynamic> decoded) {
  final storage = decoded['resultStorage'];
  if (storage is! Map) return null;
  final hist = storage['toolResultsHistory'];
  if (hist is Map) {
    final id = hist['historyId']?.toString();
    if (id != null && id.isNotEmpty) return id;
  }
  final exec = storage['toolResultsExecution'];
  if (exec is Map) {
    final id = exec['historyId']?.toString();
    if (id != null && id.isNotEmpty) return id;
  }
  return null;
}

String? matrixIdFromTestMatrixJson(Map<String, dynamic> decoded) {
  final id = decoded['testMatrixId']?.toString();
  if (id != null && id.isNotEmpty) return id;
  final name = decoded['name']?.toString();
  if (name == null || name.isEmpty) return null;
  // projects/{project}/testMatrices/{matrixId}
  final parts = name.split('/');
  return parts.isNotEmpty ? parts.last : name;
}
