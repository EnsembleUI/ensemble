import 'package:json_annotation/json_annotation.dart';

part 'encrypted_payload.g.dart';

@JsonSerializable()
class EncryptedPayload {
  final String data;
  final String hmac;
  final String iv;

  EncryptedPayload({
    required this.data,
    required this.hmac,
    required this.iv,
  });

  factory EncryptedPayload.fromJson(Map<String, dynamic> json) =>
      _$EncryptedPayloadFromJson(json);

  Map<String, dynamic> toJson() => _$EncryptedPayloadToJson(this);

  @override
  String toString() {
    return 'EncryptedPayload{data: $data, hmac: $hmac, iv: $iv}';
  }
}
