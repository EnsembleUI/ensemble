import 'package:json_annotation/json_annotation.dart';

part 'json_rpc_response.g.dart';

@JsonSerializable()
class JsonRpcResponse {
  final int id;
  final String jsonrpc;
  @JsonKey(name: 'result', includeIfNull: false)
  final dynamic result;
  @JsonKey(name: 'error', includeIfNull: false)
  final dynamic error;

  JsonRpcResponse({
    required this.id,
    this.jsonrpc = '2.0',
    this.result,
    this.error,
  });

  factory JsonRpcResponse.fromJson(Map<String, dynamic> json) =>
      _$JsonRpcResponseFromJson(json);

  Map<String, dynamic> toJson() => _$JsonRpcResponseToJson(this);

  @override
  String toString() {
    return 'JsonRpcResponse{id: $id, jsonrpc: $jsonrpc, result: $result}';
  }
}
