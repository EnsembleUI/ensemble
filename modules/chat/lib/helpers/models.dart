class Message {
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

  final String? id;
  final User user;
  final int userId;
  final String flow;
  final String role;
  final int? createdAt;
  final int? updatedAt;
  late String content;
  final dynamic widgetDefination;
  final int threadId;

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

class User {
  const User({required this.id, this.username});

  final int id;
  final String? username;

  factory User.fromJson(Map<String, dynamic>? json) {
    return User(
      id: parseId(json),
      username: json?['username'],
    );
  }

  static int parseId(Map<String, dynamic>? json) {
    if (json?['id'] == null || (json?['id'] is String)) {
      return 0;
    }
    return json?['id'] ?? 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
    };
  }
}
