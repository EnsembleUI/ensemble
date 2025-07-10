// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wc_session_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WCSessionRequest _$WCSessionRequestFromJson(Map<String, dynamic> json) =>
    WCSessionRequest(
      chainId: json['chainId'] as int?,
      peerId: json['peerId'] as String?,
      peerMeta: json['peerMeta'] == null
          ? null
          : PeerMeta.fromJson(json['peerMeta'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$WCSessionRequestToJson(WCSessionRequest instance) =>
    <String, dynamic>{
      'chainId': instance.chainId,
      'peerId': instance.peerId,
      'peerMeta': instance.peerMeta,
    };
