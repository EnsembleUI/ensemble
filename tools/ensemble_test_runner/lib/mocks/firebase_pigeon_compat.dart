import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore_platform_interface/src/method_channel/utils/firestore_message_codec.dart';
import 'package:flutter/services.dart';

/// Pigeon wire objects are versioned independently of Flutter. Keep the test
/// bridge on the wire contract so apps can use their own pinned Firebase SDKs.
class PigeonWireValue {
  const PigeonWireValue(this.type, this.value);

  final int type;
  final Object? value;
}

class PigeonCompatCodec implements MessageCodec<Object?> {
  PigeonCompatCodec(this.decoder, this.encoder);

  final MessageCodec<Object?> decoder;
  final StandardMessageCodec encoder;

  @override
  ByteData? encodeMessage(Object? message) => encoder.encodeMessage(message);

  @override
  Object? decodeMessage(ByteData? message) => decoder.decodeMessage(message);
}

class PigeonWireMessageCodec extends StandardMessageCodec {
  const PigeonWireMessageCodec();

  @override
  void writeValue(WriteBuffer buffer, Object? value) {
    if (value case PigeonWireValue(:final type, :final value)) {
      buffer.putUint8(type);
      writeValue(buffer, value);
      return;
    }
    super.writeValue(buffer, value);
  }
}

class FirestorePigeonWireMessageCodec extends FirestoreMessageCodec {
  const FirestorePigeonWireMessageCodec();

  @override
  void writeValue(WriteBuffer buffer, Object? value) {
    if (value case PigeonWireValue(:final type, :final value)) {
      buffer.putUint8(type);
      writeValue(buffer, value);
      return;
    }
    super.writeValue(buffer, value);
  }
}

/// Returns true for the pre-8 Firestore / pre-9 Auth Pigeon contracts.
///
/// package_config is produced by pub for each app/worker, so this follows the
/// version actually selected for that app rather than the runner's SDK.
bool usesLegacyFirebasePigeon(String packageName) {
  try {
    final config = File('.dart_tool/package_config.json');
    final packages =
        (jsonDecode(config.readAsStringSync()) as Map)['packages'] as List;
    final package = packages.cast<Map>().firstWhere(
          (entry) => entry['name'] == packageName,
        );
    final rootUri = Uri.parse(package['rootUri'] as String);
    final directory = rootUri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
    final packageDirectory = directory.last;
    final match = RegExp(r'-(\d+)\.').firstMatch(packageDirectory);
    return match != null &&
        int.parse(match.group(1)!) <
            (packageName.startsWith('firebase_auth') ? 9 : 8);
  } catch (_) {
    // Existing supported versions in both projects use the legacy API unless
    // package_config can prove the newer contract is selected.
    return true;
  }
}
