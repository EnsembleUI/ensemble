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
