import 'package:json_annotation/json_annotation.dart';

part 'peer_meta.g.dart';

/// Meta data information.
@JsonSerializable()
class PeerMeta {
  final String? url;
  final String? name;
  final String? description;
  final List<String>? icons;

  const PeerMeta({this.url, this.name, this.description, this.icons});

  factory PeerMeta.fromJson(Map<String, dynamic> json) =>
      _$PeerMetaFromJson(json);

  Map<String, dynamic> toJson() => _$PeerMetaToJson(this);

  @override
  String toString() {
    return 'PeerMeta{url: $url, name: $name, description: $description, icons: $icons}';
  }
}
