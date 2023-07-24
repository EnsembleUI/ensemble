class Message {
  const Message({
    required this.id,
    required this.author,
    required this.text,
    this.createdAt,
    this.updatedAt,
    this.metadata,
    this.widgetDefinition,
  });

  final String id;
  final User author;
  final int? createdAt;
  final Map<String, dynamic>? metadata;
  final int? updatedAt;
  final String text;
  final dynamic widgetDefinition;

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      author: User.fromJson(json['author']),
      text: json['text'],
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
      metadata: json['metadata'],
      widgetDefinition: json['widgetDefinition'],
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
      'widgetDefinition': widgetDefinition,
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

String generateRandomString({int length = 8}) {
  const randomChars =
      "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
  const charsLength = randomChars.length;

  final rand = Random();
  final codeUnits = List.generate(
    length,
    (index) => randomChars[rand.nextInt(charsLength)].codeUnitAt(0),
  );

  return String.fromCharCodes(codeUnits);
}
