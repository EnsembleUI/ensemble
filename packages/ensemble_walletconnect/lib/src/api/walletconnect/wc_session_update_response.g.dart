// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wc_session_update_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WCSessionUpdateResponse _$WCSessionUpdateResponseFromJson(
        Map<String, dynamic> json) =>
    WCSessionUpdateResponse(
      approved: json['approved'] as bool? ?? false,
      chainId: json['chainId'] as int? ?? 0,
      accounts: (json['accounts'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      networkId: json['networkId'] as int? ?? 0,
      rpcUrl: json['rpcUrl'] as String? ?? '',
    );

Map<String, dynamic> _$WCSessionUpdateResponseToJson(
        WCSessionUpdateResponse instance) =>
    <String, dynamic>{
      'approved': instance.approved,
      'chainId': instance.chainId,
      'accounts': instance.accounts,
      'networkId': instance.networkId,
      'rpcUrl': instance.rpcUrl,
    };
