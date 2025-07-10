import 'package:ensemble_walletconnect/src/session/peer_meta.dart';
import 'package:ensemble_walletconnect/src/session/session_status.dart';
import 'package:json_annotation/json_annotation.dart';

part 'wc_session_request_response.g.dart';

/// A response containing session information.
@JsonSerializable()
class WCSessionRequestResponse {
  @JsonKey(name: 'approved', defaultValue: false)
  final bool approved;

  @JsonKey(name: 'chainId')
  final int? chainId;

  @JsonKey(name: 'accounts', defaultValue: [])
  final List<String> accounts;

  @JsonKey(name: 'peerId')
  final String? peerId;

  @JsonKey(name: 'peerMeta')
  final PeerMeta? peerMeta;

  WCSessionRequestResponse({
    required this.approved,
    required this.chainId,
    required this.accounts,
    required this.peerId,
    required this.peerMeta,
  });

  factory WCSessionRequestResponse.fromJson(Map<String, dynamic> json) =>
      _$WCSessionRequestResponseFromJson(json);

  Map<String, dynamic> toJson() => _$WCSessionRequestResponseToJson(this);

  /// Get the status of the session;
  SessionStatus get status => SessionStatus(
        chainId: chainId ?? 0,
        accounts: accounts,
      );

  @override
  String toString() {
    return 'WCSessionRequestResponse{approved: $approved, chainId: $chainId, accounts: $accounts, peerId: $peerId, peerMeta: $peerMeta,}';
  }
}
