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
class FtlConsoleLinks {
  final String projectId;
  final String matrixId;
  final String? historyId;

  const FtlConsoleLinks({
    required this.projectId,
    required this.matrixId,
    this.historyId,
  });

  bool get hasDirectMatrixLink =>
      historyId != null && historyId!.isNotEmpty;

  /// Direct matrix page when [historyId] is known. Null otherwise — do not
  /// pretend the histories list is a matrix link.
  String? get directMatrixUrl {
    if (!hasDirectMatrixLink) return null;
    return 'https://console.firebase.google.com/project/$projectId/'
        'testlab/histories/$historyId/matrices/$matrixId';
  }

  /// Cloud Console Test Lab list for this project (browse / search by matrix id).
  String get cloudBrowseUrl =>
      'https://console.cloud.google.com/test-lab/histories?project=$projectId';

  /// Best single URL to print: direct matrix when available, else browse list.
  String get bestUrl => directMatrixUrl ?? cloudBrowseUrl;

  /// One-line log text for operators.
  String get logLine {
    if (hasDirectMatrixLink) {
      return 'Open matrix $matrixId: $directMatrixUrl';
    }
    return 'Open Test Lab (matrix $matrixId — direct link pending history id): '
        '$cloudBrowseUrl';
  }

  Map<String, String> toMetadata() => {
        'consoleUrl': bestUrl,
        'cloudBrowseUrl': cloudBrowseUrl,
        if (hasDirectMatrixLink) ...{
          'historyId': historyId!,
          'directMatrixUrl': directMatrixUrl!,
        },
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
  // Some responses nest history only under toolResultsExecution at top level.
  final topExec = decoded['toolResultsExecution'];
  if (topExec is Map) {
    final id = topExec['historyId']?.toString();
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
