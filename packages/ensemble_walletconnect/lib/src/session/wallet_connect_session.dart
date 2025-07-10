import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:ensemble_walletconnect/src/exceptions/exceptions.dart';
import 'package:ensemble_walletconnect/src/session/peer_meta.dart';
import 'package:ensemble_walletconnect/src/utils/key_converter.dart';
import 'package:json_annotation/json_annotation.dart';

part 'wallet_connect_session.g.dart';

@JsonSerializable()
class WalletConnectSession {
  String protocol;
  int version;
  bool connected;
  List<String> accounts;
  int chainId;
  String bridge = '';

  @KeyConverter()
  Uint8List? key;
  String clientId = '';
  PeerMeta? clientMeta;
  String peerId = '';
  PeerMeta? peerMeta;
  int handshakeId = 0;
  String handshakeTopic = '';
  int networkId = 0;
  String rpcUrl = '';

  WalletConnectSession({
    required this.accounts,
    this.protocol = 'wc',
    this.version = 1,
    this.connected = false,
    this.chainId = 0,
    this.bridge = '',
    this.key,
    this.clientId = '',
    this.clientMeta,
    this.peerId = '',
    this.peerMeta,
    this.handshakeId = 0,
    this.handshakeTopic = '',
    this.networkId = 0,
    this.rpcUrl = '',
  });

  factory WalletConnectSession.fromUri({
    required String uri,
    required String clientId,
    required PeerMeta clientMeta,
    List<String>? accounts,
  }) {
    final protocolSeparator = uri.indexOf(':');
    final topicSeparator = uri.indexOf('@', protocolSeparator);
    final versionSeparator = uri.indexOf('?');
    final protocol = uri.substring(0, protocolSeparator);
    final handshakeTopic = uri.substring(protocolSeparator + 1, topicSeparator);

    final version = uri.substring(topicSeparator + 1, versionSeparator);
    final params = Uri.dataFromString(uri).queryParameters;
    final bridge = params['bridge'] ??
        (throw WalletConnectException('Missing bridge param in URI'));

    final key = params['key'] ??
        (throw WalletConnectException('Missing key param in URI'));

    return WalletConnectSession(
      protocol: protocol,
      version: int.tryParse(version) ?? 1,
      handshakeTopic: handshakeTopic,
      bridge: Uri.decodeFull(bridge),
      key: Uint8List.fromList(hex.decode(key)),
      accounts: accounts ?? [],
      clientId: clientId,
      clientMeta: clientMeta,
    );
  }

  /// Approve the session.
  void approve(Map<String, dynamic> params) {
    connected = true;
    chainId = params['chainId'] ?? chainId;
    accounts = params['accounts']?.cast<String>() ?? accounts;
    peerId = params['peerId'] ?? peerId;
    peerMeta = params.containsKey('peerMeta')
        ? PeerMeta.fromJson(params['peerMeta'])
        : peerMeta;
  }

  /// Reset the session.
  void reset() {
    connected = false;
    accounts = [];
    handshakeId = 0;
    handshakeTopic = '';
  }

  /// Get the display uri.
  String toUri() {
    return '$protocol:$handshakeTopic@$version?bridge=${Uri.encodeComponent(bridge)}&key=${hex.encode(key ?? [])}';
  }

  factory WalletConnectSession.fromJson(Map<String, dynamic> json) =>
      _$WalletConnectSessionFromJson(json);

  Map<String, dynamic> toJson() => _$WalletConnectSessionToJson(this);
}
