// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'encrypted_payload.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EncryptedPayload _$EncryptedPayloadFromJson(Map<String, dynamic> json) =>
    EncryptedPayload(
      data: json['data'] as String,
      hmac: json['hmac'] as String,
      iv: json['iv'] as String,
    );

Map<String, dynamic> _$EncryptedPayloadToJson(EncryptedPayload instance) =>
    <String, dynamic>{
      'data': instance.data,
      'hmac': instance.hmac,
      'iv': instance.iv,
    };
