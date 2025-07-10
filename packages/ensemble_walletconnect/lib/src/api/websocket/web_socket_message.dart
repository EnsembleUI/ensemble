import 'package:json_annotation/json_annotation.dart';

part 'web_socket_message.g.dart';

@JsonSerializable()
class WebSocketMessage {
  final String topic;
  final String type;
  final String payload;

  WebSocketMessage({
    required this.topic,
    required this.type,
    required this.payload,
  });

  factory WebSocketMessage.fromJson(Map<String, dynamic> json) =>
      _$WebSocketMessageFromJson(json);

  Map<String, dynamic> toJson() => _$WebSocketMessageToJson(this);

  @override
  String toString() {
    return 'WebSocketMessage{topic: $topic, type: $type, payload: $payload}';
  }
}
