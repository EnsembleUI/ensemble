// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'peer_meta.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PeerMeta _$PeerMetaFromJson(Map<String, dynamic> json) => PeerMeta(
      url: json['url'] as String?,
      name: json['name'] as String?,
      description: json['description'] as String?,
      icons:
          (json['icons'] as List<dynamic>?)?.map((e) => e as String).toList(),
    );

Map<String, dynamic> _$PeerMetaToJson(PeerMeta instance) => <String, dynamic>{
      'url': instance.url,
      'name': instance.name,
      'description': instance.description,
      'icons': instance.icons,
    };
