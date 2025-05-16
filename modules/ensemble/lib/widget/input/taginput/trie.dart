// lib/src/trie.dart

import 'package:ensemble/widget/input/taginput/tagged_text.dart';

class _TrieNode {
  final Map<String, _TrieNode> children;
  late bool endOfWord;
  final Map<int, int> indices;

  _TrieNode({
    this.endOfWord = false,
  })  : children = {},
        indices = {};
}

/// A tree data structure for storing tags
/// and performing efficient tag searches.
class Trie {
  late _TrieNode _root;

  Trie() : _root = _TrieNode();

  void insertAll(Iterable<TaggedText> tags) {
    for (var tag in tags) {
      insert(tag);
    }
  }

  /// Inserts tag into trie.
  void insert(TaggedText tag) {
    int length = tag.text.length;
    _TrieNode node = _root;
    for (int i = 0; i < length; i++) {
      final char = tag.text[i];
      if (node.children[char] == null) {
        final newNode = _TrieNode(endOfWord: i == length - 1);
        node.children[char] = newNode;
        node = newNode;
      } else {
        node = node.children[char]!;
      }
    }
    node.endOfWord = true;
    node.indices.putIfAbsent(tag.startIndex, () => tag.endIndex);
  }

  /// If a [TaggedText] is a substring of [word],
  /// [TaggedText] is returned. Otherwise, `null` is returned.
  TaggedText? search(String word, int startIndex) {
    int length = word.length;
    _TrieNode node = _root;
    int lastIndex = 0;

    TaggedText? tag;

    // Check if this position is already part of a tag
    for (var index in node.indices.keys) {
      if (startIndex == index) {
        int endIndex = node.indices[index]!;
        return TaggedText(
          startIndex: startIndex,
          endIndex: endIndex,
          text: word,
        );
      }
    }

    // If not found directly, try character by character
    for (int i = 0; i < length; i++) {
      if (node.endOfWord) {
        final endIndex = node.indices[startIndex];
        if (endIndex != null) {
          tag = TaggedText(
            startIndex: startIndex,
            endIndex: endIndex,
            text: word.substring(0, lastIndex + 1),
          );
        }
      }

      final char = word[i];
      if (node.children[char] == null) {
        break;
      }
      lastIndex = i;
      node = node.children[char]!;
    }

    if (node.endOfWord) {
      final endIndex = node.indices[startIndex];
      if (endIndex != null) {
        tag = TaggedText(
          startIndex: startIndex,
          endIndex: endIndex,
          text: word.substring(0, lastIndex + 1),
        );
      }
    }

    return tag;
  }

  /// Clears trie.
  void clear() {
    _root = _TrieNode();
  }
}
