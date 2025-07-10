import 'package:json_annotation/json_annotation.dart';

part 'wc_session_update_response.g.dart';

@JsonSerializable()
class WCSessionUpdateResponse {
  @JsonKey(name: 'approved', defaultValue: false)
  final bool approved;

  @JsonKey(name: 'chainId', defaultValue: 0)
  final int chainId;

  @JsonKey(name: 'accounts', defaultValue: [])
  final List<String> accounts;

  @JsonKey(name: 'networkId', defaultValue: 0)
  final int networkId;

  @JsonKey(name: 'rpcUrl', defaultValue: '')
  final String rpcUrl;

  WCSessionUpdateResponse({
    required this.approved,
    required this.chainId,
    required this.accounts,
    required this.networkId,
    required this.rpcUrl,
  });

  factory WCSessionUpdateResponse.fromJson(Map<String, dynamic> json) =>
      _$WCSessionUpdateResponseFromJson(json);

  Map<String, dynamic> toJson() => _$WCSessionUpdateResponseToJson(this);

  @override
  String toString() {
    return 'WCSessionUpdateResponse{approved: $approved, chainId: $chainId, accounts: $accounts, networkId: $networkId, rpcUrl: $rpcUrl}';
  }
}
