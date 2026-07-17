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
