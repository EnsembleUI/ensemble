import 'dart:convert';
import 'dart:io';

import 'package:ensemble_test_runner/execution/artifact_transport.dart';
import 'package:ensemble_test_runner/reporters/atomic_file.dart';
import 'package:path/path.dart' as p;

export 'package:ensemble_test_runner/execution/artifact_transport.dart'
    show ensembleTestArtifactProtocolPrefix;

const _artifactRoot = String.fromEnvironment('ensembleTestArtifactRoot');
const _artifactDisplayRoot = String.fromEnvironment(
  'ensembleTestArtifactDisplayRoot',
  defaultValue: 'build/ensemble_test_runner',
);
const _executionMode = String.fromEnvironment(
  'ensembleTestExecutionMode',
  defaultValue: 'widget',
);
const ensembleTestProgressProtocolPrefix = 'ENSEMBLE_TEST_PROGRESS_V1:';

/// Host path for the machine JSON report transported from an integration device.
const ensembleTestMachineResultRelativePath =
    'diagnostics/machine_result.json';

bool get usesDeviceArtifactTransport => _executionMode == 'integration';

/// Widget tests dress screenshots in a matching device bezel. Integration
/// captures already are the real simulator/emulator display, so a stock
/// iPhone frame would clip the UI and misplace highlights.
bool get framesScreenshotsWithDeviceBezel => !usesDeviceArtifactTransport;

abstract class EnsembleTestArtifactSink {
  const EnsembleTestArtifactSink();

  Future<void> write(
    String relativePath,
    List<int> bytes, {
    required String mimeType,
  });
}

class FileArtifactSink extends EnsembleTestArtifactSink {
  const FileArtifactSink();

  @override
  Future<void> write(
    String relativePath,
    List<int> bytes, {
    required String mimeType,
  }) async {
    final file = File(p.join(ensembleTestArtifactRoot, relativePath));
    AtomicFile.writeBytesSync(file, bytes);
  }
}

class DeviceTransportArtifactSink extends EnsembleTestArtifactSink {
  const DeviceTransportArtifactSink();

  @override
  Future<void> write(
    String relativePath,
    List<int> bytes, {
    required String mimeType,
  }) async {
    emitEnsembleTestArtifact(relativePath, bytes, mimeType: mimeType);
  }
}

EnsembleTestArtifactSink get ensembleTestArtifactSink =>
    usesDeviceArtifactTransport
        ? const DeviceTransportArtifactSink()
        : const FileArtifactSink();

String get ensembleTestArtifactRoot =>
    _artifactRoot.isEmpty ? _artifactDisplayRoot : _artifactRoot;

Directory ensembleTestArtifactDirectory(String name) {
  return Directory(p.join(ensembleTestArtifactRoot, name));
}

File ensembleTestArtifactFile(String directoryName, String fileName) {
  return File(p.join(ensembleTestArtifactRoot, directoryName, fileName));
}

/// Writes an artifact locally in widget mode or transports it to the host in
/// bounded stdout records when the suite runs on a mobile target.
Future<void> writeEnsembleTestArtifactBytes(
  String directoryName,
  String fileName,
  List<int> bytes, {
  String mimeType = 'application/octet-stream',
}) async {
  await ensembleTestArtifactSink.write(
    p.posix.join(directoryName.replaceAll('\\', '/'), fileName),
    bytes,
    mimeType: mimeType,
  );
}

Future<void> writeEnsembleTestArtifactString(
  String directoryName,
  String fileName,
  String contents, {
  String mimeType = 'text/plain; charset=utf-8',
}) =>
    writeEnsembleTestArtifactBytes(
      directoryName,
      fileName,
      utf8.encode(contents),
      mimeType: mimeType,
    );

void emitEnsembleTestArtifact(
  String relativePath,
  List<int> bytes, {
  required String mimeType,
}) {
  EnsembleTestArtifactEmitter.instance.emitArtifact(
    relativePath,
    bytes,
    mimeType: mimeType,
  );
}

/// Emits the run-level begin record for device→host transport.
void emitEnsembleTestArtifactTransportBegin() {
  EnsembleTestArtifactEmitter.instance.begin();
}

/// Emits the run-level complete record for device→host transport.
void emitEnsembleTestArtifactTransportComplete() {
  EnsembleTestArtifactEmitter.instance.complete();
}

/// Writes the suite JSON report through device→host transport.
///
/// Integration stdout cannot carry a multi-megabyte JSON line (syslog/logcat
/// truncates it, and Flutter prefixes `flutter:` so host parsers miss it).
void emitEnsembleTestMachineReport(String jsonReport) {
  if (!usesDeviceArtifactTransport) return;
  emitEnsembleTestArtifact(
    ensembleTestMachineResultRelativePath,
    utf8.encode(jsonReport),
    mimeType: 'application/json',
  );
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
