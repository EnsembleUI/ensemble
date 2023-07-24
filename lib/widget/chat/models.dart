class Message {
  const Message({
    required this.id,
    required this.author,
    required this.text,
    this.createdAt,
    this.updatedAt,
    this.metadata,
    this.widget,
  });

  final String id;
  final User author;
  final int? createdAt;
  final Map<String, dynamic>? metadata;
  final int? updatedAt;
  final String text;
  final dynamic widget;

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      author: User.fromJson(json['author']),
      text: json['text'],
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
      metadata: json['metadata'],
      widget: json['widget'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'author': author.toJson(),
      'text': text,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'metadata': metadata,
      'widget': widget,
    };
  }
}

class User {
  const User({required this.id, this.name});

  final String id;
  final String? name;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}
