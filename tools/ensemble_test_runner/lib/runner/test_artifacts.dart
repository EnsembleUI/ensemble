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
const _executionTarget = String.fromEnvironment(
  'ensembleTestExecutionTarget',
  defaultValue: 'local',
);
const ensembleTestProgressProtocolPrefix = 'ENSEMBLE_TEST_PROGRESS_V1:';

bool get usesDeviceArtifactTransport => _executionMode == 'integration';

/// Remote FTL runs must persist artifacts on-device for `directoriesToPull`.
/// Dumping screenshot base64 into logcat overflows the circular buffer and
/// drops the envelope protocol lines (host then sees SUCCESS + incomplete).
bool get prefersOnDeviceFileArtifacts =>
    _executionTarget == 'remote' ||
    ensembleTestArtifactRoot.startsWith('/');

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

/// Writes on-device files and optionally mirrors to logcat (local USB only).
class FileThenTransportArtifactSink extends EnsembleTestArtifactSink {
  const FileThenTransportArtifactSink({this.emitLogcat = true});

  final bool emitLogcat;

  static const _altRemoteRoot = '/sdcard/Download/ensemble_test_remote';

  @override
  Future<void> write(
    String relativePath,
    List<int> bytes, {
    required String mimeType,
  }) async {
    await const FileArtifactSink().write(
      relativePath,
      bytes,
      mimeType: mimeType,
    );
    if (!emitLogcat) {
      // Best-effort mirror for FTL directoriesToPull redundancy.
      try {
        final alt = File(p.join(_altRemoteRoot, relativePath));
        AtomicFile.writeBytesSync(alt, bytes);
      } catch (_) {
        // /sdcard may be scoped-storage blocked; primary tmp path still used.
      }
    }
    if (emitLogcat) {
      emitEnsembleTestArtifact(relativePath, bytes, mimeType: mimeType);
    }
  }
}

EnsembleTestArtifactSink get ensembleTestArtifactSink {
  if (!usesDeviceArtifactTransport) {
    return const FileArtifactSink();
  }
  if (prefersOnDeviceFileArtifacts) {
    // Remote / absolute on-device root: disk only (FTL directoriesToPull).
    return const FileThenTransportArtifactSink(emitLogcat: false);
  }
  // Local integration over USB: logcat/stdout transport to the host CLI.
  return const DeviceTransportArtifactSink();
}

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
