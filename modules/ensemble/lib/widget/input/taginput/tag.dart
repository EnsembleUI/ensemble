/// Represents a tag.
class Tag {
  const Tag({
    required this.id,
    required this.text,
    required this.triggerCharacter,
  });

  final String id;
  final String text;
  final String triggerCharacter;

  @override
  bool operator ==(Object other) {
    return other is Tag &&
        other.id == id &&
        other.text == text &&
        other.triggerCharacter == triggerCharacter;
  }

  @override
  int get hashCode => Object.hashAll([id, text, triggerCharacter]);

  @override
  String toString() {
    return "Tag(id: $id, text: $text, triggerCharacter: $triggerCharacter)";
  }
}
