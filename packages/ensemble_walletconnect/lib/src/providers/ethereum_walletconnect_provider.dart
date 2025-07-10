import 'dart:convert';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:ensemble_walletconnect/ensemble_walletconnect.dart';

extension HexToBytes on String {
  Uint8List toUint8List() => Uint8List.fromList(hex.decode(this));
}

/// A provider implementation to easily support the Ethereum blockchain.
class EthereumWalletConnectProvider extends WalletConnectProvider {
  final int _chainId;

  EthereumWalletConnectProvider(WalletConnect connector, {int chainId = 0})
      : _chainId = chainId,
        super(connector: connector);

  /// Signs method calculates an Ethereum specific signature.
  /// [address] - 20B address
  /// [message] - message to sign
  ///
  /// Returns signature.
  Future<String> sign({
    required String message,
    required String address,
  }) async {
    final result = await connector.sendCustomRequest(
      method: 'eth_sign',
      params: [address, message],
    );

    return result;
  }

  /// Signs method calculates an Ethereum specific signature.
  /// [address] - 20B address
  /// [message] - message to sign
  /// [password] - The password of the account to sign data with
  ///
  /// Returns signature.
  Future<String> personalSign({
    required String message,
    required String address,
    required String password,
  }) async {
    final result = await connector.sendCustomRequest(
      method: 'personal_sign',
      params: [address, message, password],
    );

    return result;
  }

  /// Calculates an Ethereum-specific signature.
  /// [address] - 20B address
  /// [typedData] - message to sign containing type information, a domain separator, and data
  ///
  /// Returns a signature.
  Future<String> signTypeData({
    required String address,
    required Map<String, dynamic> typedData,
  }) async {
    final encodedTypedData = jsonEncode(typedData);

    final result = await connector.sendCustomRequest(
      method: 'eth_signTypedData',
      params: [address, encodedTypedData],
    );

    return result;
  }

  /// Creates new message call transaction or a contract creation, if the data field contains code
  /// [from] - The address the transaction is send from.
  /// [to] - The address the transaction is directed to.
  /// [data] - The compiled code of a contract OR the hash of the invoked method signature and encoded parameters. For details see Ethereum Contract ABI
  /// [gas] - (default: 90000) Integer of the gas provided for the transaction execution. It will return unused gas.
  /// [gasPrice] - Integer of the gasPrice used for each paid gas (in Wei).
  /// [value] - Integer of the value sent with this transaction (in Wei).
  /// [nonce] - Integer of a nonce. This allows to overwrite your own pending transactions that use the same nonce.
  ///
  /// Returns the transaction hash, or the zero hash if the transaction is not yet available.
  Future<String> sendTransaction({
    required String from,
    String? to,
    Uint8List? data,
    int? gas,
    BigInt? gasPrice,
    BigInt? value,
    int? nonce,
  }) async {
    final result = await connector.sendCustomRequest(
      method: 'eth_sendTransaction',
      params: [
        {
          'from': from,
          if (data != null) 'data': hex.encode(List<int>.from(data)),
          if (to != null) 'to': to,
          if (gas != null) 'gas': '0x${gas.toRadixString(16)}',
          if (gasPrice != null) 'gasPrice': '0x${gasPrice.toRadixString(16)}',
          if (value != null) 'value': '0x${value.toRadixString(16)}',
          if (nonce != null) 'nonce': '0x${nonce.toRadixString(16)}',
        }
      ],
    );

    return result;
  }

  /// Signs a transaction that can be submitted to the network at a later time using with [eth_sendRawTransaction].
  /// [from] - The address the transaction is send from.
  /// [to] - The address the transaction is directed to.
  /// [data] - The compiled code of a contract OR the hash of the invoked method signature and encoded parameters. For details see Ethereum Contract ABI.
  /// [gas] - (default: 90000) Integer of the gas provided for the transaction execution. It will return unused gas.
  /// [gasPrice] - Integer of the gasPrice used for each paid gas (in Wei).
  /// [value] - Integer of the value sent with this transaction (in Wei).
  /// [nonce] - Integer of a nonce. This allows to overwrite your own pending transactions that use the same nonce.
  ///
  /// Returns the signed transaction data.
  Future<String> signTransaction({
    required String from,
    String? to,
    Uint8List? data,
    int? gas,
    BigInt? gasPrice,
    BigInt? value,
    int? nonce,
  }) async {
    final result = await connector.sendCustomRequest(
      method: 'eth_signTransaction',
      params: [
        {
          'from': from,
          if (data != null) 'data': hex.encode(List<int>.from(data)),
          if (to != null) 'to': to,
          if (gas != null) 'gas': '0x${gas.toRadixString(16)}',
          if (gasPrice != null) 'gasPrice': '0x${gasPrice.toRadixString(16)}',
          if (value != null) 'value': '0x${value.toRadixString(16)}',
          if (nonce != null) 'nonce': '0x${nonce.toRadixString(16)}',
        }
      ],
    );

    return result;
  }

  /// Creates new message call transaction or a contract creation for signed transactions.
  /// [data] - The signed transaction data.
  ///
  /// Returns the transaction hash, or the zero hash if the transaction is not yet available.
  Future<String> sendRawTransaction({
    required Uint8List data,
  }) async {
    final result = await connector.sendCustomRequest(
      method: 'eth_sendRawTransaction',
      params: ['${hex.encode(data.toList())}'],
    );

    return result;
  }

  @override
  int get chainId => _chainId;
}
