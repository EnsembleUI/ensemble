// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wallet_connect_session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WalletConnectSession _$WalletConnectSessionFromJson(
        Map<String, dynamic> json) =>
    WalletConnectSession(
      accounts:
          (json['accounts'] as List<dynamic>).map((e) => e as String).toList(),
      protocol: json['protocol'] as String? ?? 'wc',
      version: json['version'] as int? ?? 1,
      connected: json['connected'] as bool? ?? false,
      chainId: json['chainId'] as int? ?? 0,
      bridge: json['bridge'] as String? ?? '',
      key: const KeyConverter().fromJson(json['key'] as String?),
      clientId: json['clientId'] as String? ?? '',
      clientMeta: json['clientMeta'] == null
          ? null
          : PeerMeta.fromJson(json['clientMeta'] as Map<String, dynamic>),
      peerId: json['peerId'] as String? ?? '',
      peerMeta: json['peerMeta'] == null
          ? null
          : PeerMeta.fromJson(json['peerMeta'] as Map<String, dynamic>),
      handshakeId: json['handshakeId'] as int? ?? 0,
      handshakeTopic: json['handshakeTopic'] as String? ?? '',
      networkId: json['networkId'] as int? ?? 0,
      rpcUrl: json['rpcUrl'] as String? ?? '',
    );

Map<String, dynamic> _$WalletConnectSessionToJson(
        WalletConnectSession instance) =>
    <String, dynamic>{
      'protocol': instance.protocol,
      'version': instance.version,
      'connected': instance.connected,
      'accounts': instance.accounts,
      'chainId': instance.chainId,
      'bridge': instance.bridge,
      'key': const KeyConverter().toJson(instance.key),
      'clientId': instance.clientId,
      'clientMeta': instance.clientMeta,
      'peerId': instance.peerId,
      'peerMeta': instance.peerMeta,
      'handshakeId': instance.handshakeId,
      'handshakeTopic': instance.handshakeTopic,
      'networkId': instance.networkId,
      'rpcUrl': instance.rpcUrl,
    };
