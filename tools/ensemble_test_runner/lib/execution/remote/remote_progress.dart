import 'dart:io';

/// Progress callback for remote orchestration (build → submit → poll → collect).
typedef RemoteProgress = void Function(String message);

/// Writes progress to stderr. Prefer stderr over stdout so GitHub Actions
/// surfaces lines even when stdout is fully buffered.
///
/// Do **not** call [IOSink.flush] here: `flush()` binds the sink to an
/// `addStream` internally, and a following `writeln` throws
/// `Bad state: StreamSink is bound to a stream`.
RemoteProgress stderrRemoteProgress({String prefix = '[ensemble_test remote] '}) {
  return (message) {
    stderr.writeln('$prefix$message');
  };
}

/// Safe error/status print for the remote CLI (never calls [IOSink.flush]).
void remoteCliWrite(Object? message, {bool toStderr = true}) {
  final line = '$message';
  if (toStderr) {
    stderr.writeln(line);
  } else {
    stdout.writeln(line);
  }
}

/// Firebase / Cloud console URLs for a Test Lab matrix (best-effort).
///
/// Prefer [resultsUrl] from the Testing API (`resultStorage.resultsUrl`) — that
/// is the console link Google itself publishes (numeric matrix id). Do not
/// invent `/matrices/{testMatrixId}` URLs; `matrix-*` ids are not console ids.
class FtlConsoleLinks {
  final String projectId;
  final String matrixId;
  final String? historyId;
  final String? resultsUrl;

  const FtlConsoleLinks({
    required this.projectId,
    required this.matrixId,
    this.historyId,
    this.resultsUrl,
  });

  bool get hasOfficialResultsUrl =>
      resultsUrl != null && resultsUrl!.trim().isNotEmpty;

  /// Cloud Console Test Lab list for this project (browse fallback).
  String get cloudBrowseUrl =>
      'https://console.cloud.google.com/test-lab/histories?project=$projectId';

  /// Best single URL to print (official results only — never invent a link).
  String? get bestUrl {
    if (hasOfficialResultsUrl) return resultsUrl!.trim();
    return null;
  }

  /// One-line log text for operators. Omits URLs until resultsUrl exists.
  String get logLine {
    if (hasOfficialResultsUrl) {
      return 'Open results: ${resultsUrl!.trim()}';
    }
    return 'FTL matrix accepted: $matrixId (results URL pending)';
  }

  Map<String, String> toMetadata() => {
        if (hasOfficialResultsUrl) 'consoleUrl': resultsUrl!.trim(),
        if (hasOfficialResultsUrl) 'resultsUrl': resultsUrl!.trim(),
        'cloudBrowseUrl': cloudBrowseUrl,
        if (historyId != null && historyId!.isNotEmpty) 'historyId': historyId!,
      };
}

String? historyIdFromTestMatrixJson(Map<String, dynamic> decoded) {
  final storage = decoded['resultStorage'];
  if (storage is Map) {
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
  }
  final topExec = decoded['toolResultsExecution'];
  if (topExec is Map) {
    final id = topExec['historyId']?.toString();
    if (id != null && id.isNotEmpty) return id;
  }
  return null;
}

/// Official Firebase console URL from Testing API `resultStorage.resultsUrl`.
String? resultsUrlFromTestMatrixJson(Map<String, dynamic> decoded) {
  final storage = decoded['resultStorage'];
  if (storage is! Map) return null;
  final url = storage['resultsUrl']?.toString().trim();
  if (url == null || url.isEmpty) return null;
  return url;
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
