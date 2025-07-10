// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'json_rpc_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

JsonRpcResponse _$JsonRpcResponseFromJson(Map<String, dynamic> json) =>
    JsonRpcResponse(
      id: json['id'] as int,
      jsonrpc: json['jsonrpc'] as String? ?? '2.0',
      result: json['result'],
      error: json['error'],
    );

Map<String, dynamic> _$JsonRpcResponseToJson(JsonRpcResponse instance) {
  final val = <String, dynamic>{
    'id': instance.id,
    'jsonrpc': instance.jsonrpc,
  };

  void writeNotNull(String key, dynamic value) {
    if (value != null) {
      val[key] = value;
    }
  }

  writeNotNull('result', instance.result);
  writeNotNull('error', instance.error);
  return val;
}
