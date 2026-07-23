/// Data models used by Ensemble chat.
library models;

/// A chat message returned by a server-backed chat flow.
class Message {
  /// Creates a chat message model.
  Message({
    this.id,
    required this.user,
    required this.userId,
    required this.content,
    required this.flow,
    required this.role,
    required this.threadId,
    this.widgetDefination,
    this.createdAt,
    this.updatedAt,
  });

  /// Message identifier.
  final String? id;

  /// User that authored the message.
  final User user;

  /// Numeric user identifier.
  final int userId;

  /// Flow identifier associated with this message.
  final String flow;

  /// Role associated with this message.
  final String role;

  /// Creation timestamp.
  final int? createdAt;

  /// Last updated timestamp.
  final int? updatedAt;

  /// Message body.
  late String content;

  /// Optional inline widget definition.
  final dynamic widgetDefination;

  /// Thread identifier for the message.
  final int threadId;

  /// Creates a [Message] from JSON-like map data.
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      user: User.fromJson(json['user']),
      userId: json['user_id'],
      content: json['content'],
      role: json['role'],
      flow: json['flow'],
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
      widgetDefination: json['widget_defination'],
      threadId: json['thread_id'],
    );
  }

  /// Converts this message to JSON-like map data.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user': user.toJson(),
      'user_id': userId,
      'content': content,
      'flow': flow,
      'role': role,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'widget_defination': widgetDefination ?? "{}",
      'thread_id': threadId,
    };
  }
}

/// User metadata attached to chat messages.
class User {
  /// Creates a chat user.
  const User({required this.id, this.username});

  /// Numeric user identifier.
  final int id;

  /// Optional display name.
  final String? username;

  /// Creates a [User] from JSON-like map data.
  factory User.fromJson(Map<String, dynamic>? json) {
    return User(
      id: parseId(json),
      username: json?['username'],
    );
  }

  /// Parses a user id, returning `0` when the payload is missing or invalid.
  static int parseId(Map<String, dynamic>? json) {
    if (json?['id'] == null || (json?['id'] is String)) {
      return 0;
    }
    return json?['id'] ?? 0;
  }

  /// Converts this user to JSON-like map data.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
    };
  }
}
