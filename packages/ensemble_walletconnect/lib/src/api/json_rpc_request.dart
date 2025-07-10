import 'package:json_annotation/json_annotation.dart';

part 'json_rpc_request.g.dart';

@JsonSerializable()
class JsonRpcRequest {
  final int id;
  @JsonKey(name: 'jsonrpc', defaultValue: '2.0')
  final String rpc;
  final String method;
  final List<dynamic>? params;

  JsonRpcRequest({
    required this.id,
    required this.method,
    this.params,
    this.rpc = '2.0',
  });

  factory JsonRpcRequest.fromJson(Map<String, dynamic> json) =>
      _$JsonRpcRequestFromJson(json);

  Map<String, dynamic> toJson() => _$JsonRpcRequestToJson(this);
}
