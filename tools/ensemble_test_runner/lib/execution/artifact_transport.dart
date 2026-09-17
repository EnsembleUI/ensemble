import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:ensemble_test_runner/reporters/atomic_file.dart';
import 'package:path/path.dart' as p;

const ensembleTestArtifactProtocolPrefix = 'ENSEMBLE_TEST_ARTIFACT_V1:';

/// Maximum bytes for a single transported artifact (50 MiB).
const maxEnsembleTestArtifactBytes = 50 * 1024 * 1024;

/// Maximum concurrent incomplete artifact transfers.
const maxPendingEnsembleTestArtifacts = 64;

/// Raw payload bytes per stdout/logcat chunk.
///
/// Android logcat drops lines over ~4 KiB, so encoded records must stay under
/// that after JSON/base64 wrapping and the `I/flutter:` prefix.
const ensembleTestArtifactRawChunkSize = 2048;

/// Soft ceiling for a single protocol JSON line (prefix + payload), leaving
/// headroom under Android's ~4 KiB logcat limit.
const ensembleTestArtifactMaxRecordBytes = 3000;

/// Canonical SHA-256 of a completed artifact manifest (JSON array).
String ensembleTestArtifactManifestSha256(
  List<Map<String, dynamic>> artifacts,
) =>
    sha256.convert(utf8.encode(json.encode(artifacts))).toString();

/// Tracks artifact ids emitted during an integration run for the complete record.
class EnsembleTestArtifactEmitter {
  EnsembleTestArtifactEmitter._();

  static final EnsembleTestArtifactEmitter instance =
      EnsembleTestArtifactEmitter._();

  String? _runId;
  int _nextArtifactId = 0;
  final List<Map<String, dynamic>> _emitted = [];
  bool _begun = false;
  bool _completed = false;

  /// Emits a run-level begin record. Safe to call more than once.
  void begin({String? runId}) {
    if (_begun) return;
    _begun = true;
    _runId = runId ?? DateTime.now().toUtc().toIso8601String();
    _nextArtifactId = 0;
    _emitRecord({
      'event': 'begin',
      'runId': _runId,
    });
  }

  /// Emits one artifact as start/chunk/end records.
  void emitArtifact(
    String relativePath,
    List<int> bytes, {
    required String mimeType,
  }) {
    begin();
    if (_completed) {
      throw StateError('Cannot emit artifacts after transport complete.');
    }
    final normalized = p.posix.normalize(relativePath.replaceAll('\\', '/'));
    if (p.posix.isAbsolute(normalized) ||
        normalized == '..' ||
        normalized.startsWith('../')) {
      throw StateError('Unsafe test artifact path: $relativePath');
    }
    if (bytes.length > maxEnsembleTestArtifactBytes) {
      throw StateError(
        'Artifact $normalized is ${bytes.length} bytes; limit is '
        '$maxEnsembleTestArtifactBytes.',
      );
    }
    final payload = Uint8List.fromList(bytes);
    final digest = sha256.convert(payload).toString();
    // Transfer id is unique per emit, not content-derived, so identical
    // screenshots under different paths do not collide.
    final id = '$_runId-${_nextArtifactId++}';
    _emitRecord({
      'event': 'start',
      'id': id,
      'path': normalized,
      'mime': mimeType,
      'size': payload.length,
      'sha256': digest,
    });
    for (var offset = 0;
        offset < payload.length;
        offset += ensembleTestArtifactRawChunkSize) {
      final end = offset + ensembleTestArtifactRawChunkSize < payload.length
          ? offset + ensembleTestArtifactRawChunkSize
          : payload.length;
      _emitRecord({
        'event': 'chunk',
        'id': id,
        'data': base64Encode(payload.sublist(offset, end)),
      });
    }
    _emitRecord({'event': 'end', 'id': id});
    _emitted.add({
      'id': id,
      'path': normalized,
      'size': payload.length,
      'sha256': digest,
    });
  }

  /// Emits bounded `manifest` batches, then a compact `complete` with count +
  /// checksum so hundreds of screenshots never exceed the logcat line limit.
  void complete() {
    begin();
    if (_completed) return;
    _completed = true;
    final digest = ensembleTestArtifactManifestSha256(_emitted);
    for (final batch in ensembleTestArtifactManifestBatches(_emitted)) {
      _emitRecord({
        'event': 'manifest',
        'runId': _runId,
        'artifacts': batch,
      });
    }
    _emitRecord({
      'event': 'complete',
      'runId': _runId,
      'count': _emitted.length,
      'sha256': digest,
    });
  }

  /// Test hook to reset emitter state between unit tests.
  void resetForTest() {
    _runId = null;
    _nextArtifactId = 0;
    _emitted.clear();
    _begun = false;
    _completed = false;
  }

  /// Test hook: transfer ids assigned since the last [begin]/ [resetForTest].
  List<String> emittedIdsForTest() =>
      _emitted.map((e) => e['id']!.toString()).toList();

  void _emitRecord(Map<String, dynamic> record) {
    print('$ensembleTestArtifactProtocolPrefix${json.encode(record)}');
  }
}

/// Packs manifest entries into batches whose encoded protocol lines stay under
/// [ensembleTestArtifactMaxRecordBytes].
List<List<Map<String, dynamic>>> ensembleTestArtifactManifestBatches(
  List<Map<String, dynamic>> artifacts,
) {
  if (artifacts.isEmpty) return const [];
  final batches = <List<Map<String, dynamic>>>[];
  var current = <Map<String, dynamic>>[];
  for (final item in artifacts) {
    final candidate = [...current, item];
    final encodedLength = ensembleTestArtifactProtocolPrefix.length +
        json
            .encode({
              'event': 'manifest',
              // Budget for ISO-8601 run ids; packing must stay under logcat limits.
              'runId': '2026-01-01T00:00:00.000000Z',
              'artifacts': candidate,
            })
            .length;
    if (current.isNotEmpty &&
        encodedLength > ensembleTestArtifactMaxRecordBytes) {
      batches.add(current);
      current = [item];
    } else {
      current = candidate;
    }
  }
  if (current.isNotEmpty) {
    batches.add(current);
  }
  return batches;
}

/// Result of materializing a device→host artifact stream.
class ArtifactTransportResult {
  final bool complete;
  final List<String> receivedPaths;
  final String? error;

  const ArtifactTransportResult({
    required this.complete,
    this.receivedPaths = const [],
    this.error,
  });
}

class _IncomingArtifact {
  final String relativePath;
  final int expectedSize;
  final String expectedHash;
  final File tempFile;
  IOSink? _sink;
  int received = 0;

  _IncomingArtifact({
    required this.relativePath,
    required this.expectedSize,
    required this.expectedHash,
    required this.tempFile,
  });

  Future<void> open() async {
    tempFile.parent.createSync(recursive: true);
    _sink = tempFile.openWrite();
  }

  Future<void> addChunk(List<int> chunk) async {
    if (received + chunk.length > expectedSize) {
      throw StateError(
        'Artifact $relativePath exceeded declared size $expectedSize.',
      );
    }
    if (received + chunk.length > maxEnsembleTestArtifactBytes) {
      throw StateError(
        'Artifact $relativePath exceeded max size $maxEnsembleTestArtifactBytes.',
      );
    }
    _sink ??= tempFile.openWrite();
    _sink!.add(chunk);
    received += chunk.length;
  }

  Future<List<int>> finish() async {
    await _sink?.flush();
    await _sink?.close();
    _sink = null;
    return tempFile.readAsBytesSync();
  }

  Future<void> dispose() async {
    try {
      await _sink?.close();
    } catch (_) {}
    if (tempFile.existsSync()) {
      try {
        tempFile.deleteSync();
      } catch (_) {}
    }
  }
}

String _jsonRecordFromLine(String raw) {
  final end = raw.lastIndexOf('}');
  return end < 0 ? raw.trim() : raw.substring(0, end + 1);
}

/// Parses stdout/stderr from an integration device process and writes artifacts
/// under [artifactRoot].
///
/// Requires a run-level `complete` event. Partial transfers keep any artifacts
/// that already passed size/hash checks and return [ArtifactTransportResult.complete]
/// false with an [ArtifactTransportResult.error].
Future<ArtifactTransportResult> materializeTransportedArtifacts({
  required String artifactRoot,
  required String output,
}) async {
  final pending = <String, _IncomingArtifact>{};
  final receivedPaths = <String>[];
  final receivedIds = <String>{};
  final expectedByComplete = <String, Map<String, dynamic>>{};
  final manifestOrder = <Map<String, dynamic>>[];
  var sawBegin = false;
  var sawComplete = false;
  int? completeCount;
  String? completeHash;
  String? error;
  final tempDir = Directory.systemTemp.createTempSync('ensemble_artifacts_');

  void ingestManifestEntries(List<dynamic> artifacts) {
    for (final item in artifacts) {
      if (item is! Map) continue;
      final entry = Map<String, dynamic>.from(item);
      final id = entry['id']?.toString();
      if (id == null || id.isEmpty) continue;
      expectedByComplete[id] = entry;
      manifestOrder.add(entry);
    }
  }

  try {
    for (final line in const LineSplitter().convert(output)) {
      final marker = line.indexOf(ensembleTestArtifactProtocolPrefix);
      if (marker < 0) continue;
      final raw = line.substring(
        marker + ensembleTestArtifactProtocolPrefix.length,
      );
      final dynamic decoded;
      try {
        decoded = json.decode(_jsonRecordFromLine(raw));
      } catch (e) {
        error ??= 'Invalid integration artifact record: $e';
        continue;
      }
      if (decoded is! Map) {
        error ??= 'Invalid integration artifact record payload.';
        continue;
      }
      final record = Map<String, dynamic>.from(decoded);
      final event = record['event']?.toString();

      switch (event) {
        case 'begin':
          sawBegin = true;
          break;
        case 'manifest':
          final artifacts = record['artifacts'];
          if (artifacts is List) {
            ingestManifestEntries(artifacts);
          } else {
            error ??= 'Invalid integration artifact manifest record.';
          }
          break;
        case 'complete':
          sawComplete = true;
          final artifacts = record['artifacts'];
          if (artifacts is List) {
            // Legacy single-line complete with full manifest.
            expectedByComplete.clear();
            manifestOrder.clear();
            ingestManifestEntries(artifacts);
            completeCount = manifestOrder.length;
            completeHash = ensembleTestArtifactManifestSha256(manifestOrder);
          } else {
            final count = record['count'];
            if (count is int) {
              completeCount = count;
            }
            completeHash = record['sha256']?.toString();
          }
          break;
        case 'start':
          final id = record['id']?.toString();
          if (id == null || id.isEmpty) {
            error ??= 'Integration artifact record is missing an id.';
            break;
          }
          if (pending.containsKey(id) || receivedIds.contains(id)) {
            error ??= 'Duplicate artifact transfer id: $id';
            break;
          }
          if (pending.length >= maxPendingEnsembleTestArtifacts) {
            error ??=
                'Too many pending artifact transfers (limit $maxPendingEnsembleTestArtifacts).';
            break;
          }
          final relativePath = record['path']?.toString() ?? '';
          final expectedSize = record['size'];
          final expectedHash = record['sha256']?.toString() ?? '';
          if (relativePath.isEmpty ||
              expectedSize is! int ||
              expectedSize < 0) {
            error ??= 'Invalid integration artifact start record.';
            break;
          }
          if (expectedSize > maxEnsembleTestArtifactBytes) {
            error ??=
                'Artifact $relativePath declared size $expectedSize exceeds limit.';
            break;
          }
          // Sanitize id for temp filename (run ids may contain ':').
          final safeTempName = id.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
          final incoming = _IncomingArtifact(
            relativePath: relativePath,
            expectedSize: expectedSize,
            expectedHash: expectedHash,
            tempFile: File(p.join(tempDir.path, safeTempName)),
          );
          await incoming.open();
          pending[id] = incoming;
          break;
        case 'chunk':
          final id = record['id']?.toString();
          if (id == null) {
            error ??= 'Artifact chunk missing id.';
            break;
          }
          final artifact = pending[id];
          if (artifact == null) {
            error ??= 'Artifact chunk arrived before start for $id.';
            break;
          }
          try {
            await artifact.addChunk(
              base64Decode(record['data']?.toString() ?? ''),
            );
          } catch (e) {
            error ??= 'Invalid artifact chunk for $id: $e';
            await artifact.dispose();
            pending.remove(id);
          }
          break;
        case 'end':
          final id = record['id']?.toString();
          if (id == null) {
            error ??= 'Artifact end missing id.';
            break;
          }
          final artifact = pending.remove(id);
          if (artifact == null) {
            error ??= 'Artifact end arrived before start for $id.';
            break;
          }
          try {
            final bytes = await artifact.finish();
            if (bytes.length != artifact.expectedSize) {
              throw StateError(
                'Integration artifact ${artifact.relativePath} has '
                '${bytes.length} bytes; expected ${artifact.expectedSize}.',
              );
            }
            final actualHash = sha256.convert(bytes).toString();
            if (actualHash != artifact.expectedHash) {
              throw StateError(
                'Integration artifact checksum failed: ${artifact.relativePath}',
              );
            }
            _writeArtifactBytes(
              artifactRoot: artifactRoot,
              relativePath: artifact.relativePath,
              bytes: bytes,
            );
            receivedPaths.add(artifact.relativePath);
            receivedIds.add(id);
          } catch (e) {
            error ??= e.toString();
          } finally {
            await artifact.dispose();
          }
          break;
        default:
          error ??= 'Unknown integration artifact event "$event".';
      }
    }

    for (final artifact in pending.values) {
      await artifact.dispose();
    }
    if (pending.isNotEmpty) {
      error ??=
          'Integration artifact transport ended with ${pending.length} incomplete artifact(s).';
    }

    if (!sawBegin && !sawComplete && receivedPaths.isEmpty) {
      return const ArtifactTransportResult(
        complete: false,
        error:
            'Integration artifact transport produced no records (missing begin/complete).',
      );
    }
    if (!sawComplete) {
      return ArtifactTransportResult(
        complete: false,
        receivedPaths: receivedPaths,
        error: error ??
            'Integration artifact transport finished without a complete record.',
      );
    }
    if (completeCount != null && completeCount != manifestOrder.length) {
      error ??=
          'Artifact complete count $completeCount does not match '
          'manifest entries (${manifestOrder.length}).';
    }
    if (completeHash != null && completeHash!.isNotEmpty) {
      final actual = ensembleTestArtifactManifestSha256(manifestOrder);
      if (actual != completeHash) {
        error ??= 'Artifact complete manifest checksum mismatch.';
      }
    }
    for (final entry in expectedByComplete.entries) {
      final id = entry.key;
      final path = entry.value['path']?.toString();
      if (!receivedIds.contains(id)) {
        error ??=
            'Missing transported artifact id $id${path != null ? ' ($path)' : ''}';
      }
    }
    if (error != null) {
      return ArtifactTransportResult(
        complete: false,
        receivedPaths: receivedPaths,
        error: error,
      );
    }
    return ArtifactTransportResult(
      complete: true,
      receivedPaths: receivedPaths,
    );
  } finally {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  }
}

void _writeArtifactBytes({
  required String artifactRoot,
  required String relativePath,
  required List<int> bytes,
}) {
  final normalized = p.posix.normalize(relativePath.replaceAll('\\', '/'));
  if (p.posix.isAbsolute(normalized) ||
      normalized == '..' ||
      normalized.startsWith('../')) {
    throw StateError('Unsafe integration artifact path: $normalized');
  }
  final root = p.normalize(artifactRoot);
  final target = p.normalize(p.join(root, p.fromUri(normalized)));
  if (!p.isWithin(root, target)) {
    throw StateError('Unsafe integration artifact path: $normalized');
  }
  AtomicFile.writeBytesSync(File(target), bytes);
}
