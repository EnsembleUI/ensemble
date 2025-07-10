// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'json_rpc_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

JsonRpcRequest _$JsonRpcRequestFromJson(Map<String, dynamic> json) =>
    JsonRpcRequest(
      id: json['id'] as int,
      method: json['method'] as String,
      params: json['params'] as List<dynamic>?,
      rpc: json['jsonrpc'] as String? ?? '2.0',
    );

Map<String, dynamic> _$JsonRpcRequestToJson(JsonRpcRequest instance) =>
    <String, dynamic>{
      'id': instance.id,
      'jsonrpc': instance.rpc,
      'method': instance.method,
      'params': instance.params,
    };
