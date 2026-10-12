import 'dart:convert';

import 'plan.dart';

/// Encodes a compiled execution plan for a process boundary.
///
/// The transport keeps the wire format independent from command-line quoting
/// and environment encoding. The receiver still gets the full graph
/// validation performed by [ExecutionPlan.fromWire].
final class ExecutionPlanWireTransport {
  const ExecutionPlanWireTransport._();

  static const int maxPayloadBytes = 1024 * 1024;

  /// Returns a URL-safe, padding-free payload suitable for a dart-define or
  /// a small worker hand-off message.
  static String encode(ExecutionPlan plan) {
    return _WireCodec.encode(
      plan.toWire(),
      maxBytes: maxPayloadBytes,
      label: 'execution plan wire',
    );
  }

  /// Decodes and validates a payload produced by [encode].
  static ExecutionPlan decode(String payload) {
    final decoded = _WireCodec.decode(
      payload,
      maxBytes: maxPayloadBytes,
      label: 'execution plan wire',
    );
    if (decoded is! Map) {
      throw const FormatException(
          'Execution plan wire root must be an object.');
    }
    return ExecutionPlan.fromWire(
      decoded.map((key, value) => MapEntry(key.toString(), value)),
    );
  }
}

/// Shared JSON and URL-safe base64 framing for plan transports.
///
/// The envelope validators remain in their transport classes because their
/// wire schemas differ. This helper owns only byte framing and malformed
/// payload handling, so the two paths cannot drift in those mechanics.
final class _WireCodec {
  const _WireCodec._();

  static String encode(
    Object value, {
    required int maxBytes,
    required String label,
  }) {
    final bytes = utf8.encode(jsonEncode(value));
    if (bytes.length > maxBytes) {
      throw FormatException('$label payload exceeds $maxBytes bytes.');
    }
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  static Object decode(
    String payload, {
    required int maxBytes,
    required String label,
  }) {
    if (payload.isEmpty) {
      throw FormatException('$label payload is empty.');
    }
    final padded = '$payload${'=' * ((4 - payload.length % 4) % 4)}';
    final bytes = tryDecode(padded);
    if (bytes == null || bytes.length > maxBytes) {
      throw FormatException('Invalid $label payload.');
    }
    try {
      return jsonDecode(utf8.decode(bytes));
    } on FormatException {
      rethrow;
    } catch (error) {
      throw FormatException('Invalid $label payload: $error');
    }
  }

  static List<int>? tryDecode(String value) {
    try {
      return base64Url.decode(value);
    } on FormatException {
      return null;
    }
  }
}
