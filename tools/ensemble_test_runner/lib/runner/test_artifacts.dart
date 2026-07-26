import 'dart:io';

import 'package:path/path.dart' as p;

const _artifactRoot = String.fromEnvironment('ensembleTestArtifactRoot');
const _artifactDisplayRoot = String.fromEnvironment(
  'ensembleTestArtifactDisplayRoot',
  defaultValue: 'build/ensemble_test_runner',
);

String get ensembleTestArtifactRoot =>
    _artifactRoot.isEmpty ? _artifactDisplayRoot : _artifactRoot;

Directory ensembleTestArtifactDirectory(String name) {
  return Directory(p.join(ensembleTestArtifactRoot, name));
}

File ensembleTestArtifactFile(String directoryName, String fileName) {
  return File(p.join(ensembleTestArtifactRoot, directoryName, fileName));
}

String ensembleTestArtifactDisplayPath(String directoryName, String fileName) {
  return p
      .join(_artifactDisplayRoot, directoryName, fileName)
      .replaceAll('\\', '/');
}

/// Sidecar / primary manifest path for per-step screenshot PNGs.
///
/// Accepts either a legacy sheet PNG path (`…/foo.png` → `…/foo_frames.json`)
/// or an existing frames manifest path (returned unchanged).
String screenshotFramesManifestDisplayPath(String sheetOrFramesDisplayPath) {
  final normalized = sheetOrFramesDisplayPath.replaceAll('\\', '/');
  if (normalized.toLowerCase().endsWith('_frames.json')) {
    return normalized;
  }
  if (normalized.toLowerCase().endsWith('.png')) {
    return '${normalized.substring(0, normalized.length - 4)}_frames.json';
  }
  if (normalized.toLowerCase().endsWith('.json')) {
    return normalized;
  }
  return '${normalized}_frames.json';
}

/// Labels for sidecars folded into `results.json.gz` then deleted from disk.
///
/// CLI summaries should not print these — the paths no longer exist after
/// [TestReportDocument.cleanTransientArtifacts].
bool isTransientArtifactLog(String log) {
  final separator = log.indexOf(':');
  if (separator <= 0) return false;
  final label = log.substring(0, separator).trim();
  if (label.startsWith('storage[')) return true;
  if (label.endsWith('Error')) return true;
  switch (label) {
    case 'apiCalls':
    case 'storage':
    case 'appLogs':
    case 'screenshots':
    case 'screenshotFrames':
    case 'dumpTree':
    case 'appPerformance':
      return true;
    default:
      return false;
  }
}

/// Durable suite/report links kept after transient cleanup.
Iterable<String> durableArtifactLogs(Iterable<String> logs) =>
    logs.where((log) => !isTransientArtifactLog(log));
