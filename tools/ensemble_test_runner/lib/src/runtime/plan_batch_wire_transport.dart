import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../core/plan.dart';

/// Encodes the compiled plans assigned to one worker process.
///
/// Process compression and filesystem limits belong at this adapter boundary;
/// the pure execution core keeps only the plan graph contract.
final class ExecutionPlanBatchWireTransport {
  const ExecutionPlanBatchWireTransport._();

  static const int maxPayloadBytes = 32 * 1024 * 1024;
  static const int maxCompressedPayloadBytes = 8 * 1024 * 1024;

  static String encode(Map<String, ExecutionPlan> plans) {
    for (final entry in plans.entries) {
      if (entry.key != entry.value.id) {
        throw FormatException(
          'Execution plan key "${entry.key}" does not match plan id '
          '"${entry.value.id}".',
        );
      }
    }
    final bytes = utf8.encode(jsonEncode({
      'version': 1,
      'plans': {
        for (final entry in plans.entries) entry.key: entry.value.toWire(),
      },
    }));
    if (bytes.length > maxPayloadBytes) {
      throw FormatException(
          'Execution plan batch payload exceeds $maxPayloadBytes bytes.');
    }
    final compressed = gzip.encode(bytes);
    if (compressed.length > maxCompressedPayloadBytes) {
      throw FormatException(
        'Execution plan batch compressed payload exceeds '
        '$maxCompressedPayloadBytes bytes.',
      );
    }
    return base64Url.encode(compressed).replaceAll('=', '');
  }

  static Map<String, ExecutionPlan> decode(String payload) {
    if (payload.isEmpty ||
        payload.length > (maxCompressedPayloadBytes * 4 ~/ 3) + 4) {
      throw const FormatException('Invalid execution plan batch payload.');
    }
    final padded = '$payload${'=' * ((4 - payload.length % 4) % 4)}';
    late final List<int> bytes;
    try {
      bytes = base64Url.decode(padded);
    } on FormatException {
      throw const FormatException('Invalid execution plan batch payload.');
    }

    final isGzip = bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b;
    if (!isGzip) {
      throw const FormatException(
          'Execution plan batch payload must be compressed.');
    }
    if (bytes.length > maxCompressedPayloadBytes) {
      throw const FormatException(
          'Execution plan batch compressed payload is too large.');
    }
    late final List<int> jsonBytes;
    try {
      final bounded = _BoundedBytes(maxPayloadBytes);
      gzip.decoder.startChunkedConversion(bounded)
        ..add(bytes)
        ..close();
      jsonBytes = bounded.takeBytes();
    } on Object catch (error) {
      throw FormatException('Invalid compressed execution plan batch: $error');
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(jsonBytes));
    } on Object catch (error) {
      throw FormatException('Invalid execution plan batch JSON: $error');
    }
    if (decoded is! Map) {
      throw const FormatException(
          'Execution plan batch root must be an object.');
    }
    final version = decoded['version'];
    if (version is! int || version != 1) {
      throw FormatException(
        'Execution plan batch has unsupported version "$version".',
      );
    }
    final encodedPlans = decoded['plans'];
    if (encodedPlans is! Map) {
      throw const FormatException(
          'Execution plan batch plans must be an object.');
    }
    final result = <String, ExecutionPlan>{};
    for (final entry in encodedPlans.entries) {
      final id = entry.key.toString();
      if (entry.value is! Map) {
        throw FormatException(
            'Execution plan batch entry "$id" must be an object.');
      }
      final plan = ExecutionPlan.fromWire(
        (entry.value as Map).map(
          (key, value) => MapEntry(key.toString(), value),
        ),
      );
      if (plan.id != id) {
        throw FormatException(
          'Execution plan batch key "$id" does not match plan id "${plan.id}".',
        );
      }
      result[id] = plan;
    }
    return Map.unmodifiable(result);
  }
}

/// Stops decompression once a batch exceeds its decoded size limit.
final class _BoundedBytes with ByteConversionSink {
  _BoundedBytes(this.maxBytes);

  final int maxBytes;
  final BytesBuilder _builder = BytesBuilder(copy: false);
  int _length = 0;

  @override
  void add(List<int> chunk) {
    _length += chunk.length;
    if (_length > maxBytes) {
      throw const FormatException(
          'Compressed execution plan batch is too large.');
    }
    _builder.add(chunk);
  }

  @override
  void close() {}

  List<int> takeBytes() => _builder.takeBytes();
}
