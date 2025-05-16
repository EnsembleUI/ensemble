// lib/src/tagger.dart
import 'package:flutter/material.dart';
import 'package:ensemble/widget/input/taginput/tag.dart';
import 'package:ensemble/widget/input/taginput/tagged_text.dart';
import 'package:ensemble/widget/input/taginput/trie.dart';

/// {@macro builder}
typedef InputTaggerWidgetBuilder = Widget Function(
  BuildContext context,
  GlobalKey key,
);

/// Formatter for tags in the [TextField] associated
/// with [InputTagger].
typedef TagTextFormatter = String Function(
  String id,
  String tag,
  String triggerCharacter,
);

///{@macro searchCallback}
typedef InputTaggerSearchCallback = void Function(
  String query,
  String triggerCharacter,
);

/// Indicates where the overlay should be positioned.
enum OverlayPosition { top, bottom }

/// {@template triggerStrategy}
/// Strategy to adopt when a trigger character is detected.
///
/// [eager] will cause the search callback to be invoked immediately
/// a trigger character is detected.
///
/// [deferred] will cause the search callback to be invoked only when
/// a searchable character is entered after the trigger
/// character is detected. This is the default.
/// {@endtemplate}
enum TriggerStrategy { eager, deferred }

/// Provides tagging capabilities (e.g user mentions and adding hashtags)
/// to a [TextField] returned from [builder].
///
/// Listens to [controller] and activates search context when
/// any trigger character from [triggerCharacterAndStyles]
/// is detected; sending subsequent text as search query using [onSearch].
///
/// Search results should be shown in [overlay] which is
/// animated if [animationController] is provided.
///
/// [InputTagger] maintains tag positions during text editing and allows
/// for formatting of the tags in [TextField]'s text value with [tagTextFormatter].
///
/// Tags in the [TextField] are styled with [TextStyle]
/// for their associated trigger character defined in [triggerCharacterAndStyles].
class InputTagger extends StatefulWidget {
  /// Creates a InputTagger widget.
  ///
  /// A listener is attached to [controller] which activates
  /// the search context when any trigger character from [triggerCharacterAndStyles]
  /// is detected. When the search context is active, [onSearch] is called
  /// with the trigger character and the text typed after it.
  ///
  /// [overlay] is shown when the search context is activated.
  ///
  /// The [overlayPosition] property indicates where the [overlay] should be positioned:
  /// above or below the [TextField].
  ///
  /// If [animationController] is provided and [overlay] has a connected [Animation],
  /// [overlay] is shown and dismissed with that animation.
  ///
  /// The [padding] is used to position the [overlay] relative to the [TextField] vertically.
  ///
  /// The tags in the [TextField] are styled with [TextStyle]
  /// for their associated trigger character defined in [triggerCharacterAndStyles].
  const InputTagger({
    Key? key,
    required this.overlay,
    required this.controller,
    required this.onSearch,
    required this.builder,
    this.padding = EdgeInsets.zero,
    this.overlayHeight = 380,
    this.triggerCharacterAndStyles = const {},
    this.overlayPosition = OverlayPosition.top,
    this.triggerStrategy = TriggerStrategy.deferred,
    this.onFormattedTextChanged,
    this.searchRegex,
    this.triggerCharactersRegex,
    this.tagTextFormatter,
    this.animationController,
  })  : assert(
          triggerCharacterAndStyles != const {},
          "triggerCharacterAndStyles cannot be empty",
        ),
        super(key: key);

  /// Widget shown in the overlay when search context is active.
  final Widget overlay;

  /// Padding applied to [overlay].
  final EdgeInsetsGeometry padding;

  /// The [overlay]'s height.
  final double overlayHeight;

  /// Formats and replaces tags for raw text retrieval.
  /// By default, tags are replaced in this format:
  /// ```dart
  /// "@Lucky Ebere"
  /// ```
  /// becomes
  ///
  /// ```dart
  /// "@6zo22531b866ce0016f9e5tt#Lucky Ebere#"
  /// ```
  /// assuming that `Lucky Ebere`'s id is `6zo22531b866ce0016f9e5tt`.
  ///
  /// Specify this parameter to use a different format.
  final TagTextFormatter? tagTextFormatter;

  /// {@macro InputTaggerController}
  final InputTaggerController controller;

  /// Callback to dispatch updated formatted text.
  final void Function(String)? onFormattedTextChanged;

  /// {@template searchCallback}
  /// Called with the search query and character that triggered the search
  /// whenever [InputTagger] enters the search context.
  /// {@endtemplate}
  final InputTaggerSearchCallback onSearch;

  /// {@template builder}
  /// Widget builder for [InputTagger]'s associated TextField.
  ///  {@endtemplate}
  /// Returned widget should be the [TextField] with the [GlobalKey] as its key.
  final InputTaggerWidgetBuilder builder;

  /// {@macro searchRegex}
  final RegExp? searchRegex;

  /// Regex to match allowed trigger characters.
  /// Trigger characters activate the search context.
  /// If null, a Regex pattern is constructed from the
  /// trigger characters in [triggerCharacterAndStyles].
  final RegExp? triggerCharactersRegex;

  /// Controller for the [overlay]'s animation.
  final AnimationController? animationController;

  /// Lookup table of trigger characters and their associated [TextStyle] styles.
  /// These styles are applied to the tags/mentions resulting from their associated
  /// trigger character.
  final Map<String, TextStyle> triggerCharacterAndStyles;

  /// Position of [overlay] relative to the [TextField].
  final OverlayPosition overlayPosition;

  /// {@macro triggerStrategy}
  final TriggerStrategy triggerStrategy;

  @override
  State<InputTagger> createState() => _InputTaggerState();
}

class _InputTaggerState extends State<InputTagger> {
  InputTaggerController get controller => widget.controller;

  late final _textFieldKey = GlobalKey(
    debugLabel: "InputTagger's child TextField key",
  );

  late bool _hideOverlay = true;

  final OverlayPortalController _overlayController = OverlayPortalController();

  /// Formats tag text to include id
  String _formatTagText(String id, String tag, String triggerCharacter) {
    return widget.tagTextFormatter?.call(id, tag, triggerCharacter) ??
        "@$id#$tag#";
  }

  /// Updates formatted text
  void _onFormattedTextChanged() {
    controller._onTextChanged(_formattedText);
    widget.onFormattedTextChanged?.call(_formattedText);
  }

  /// Hides overlay if [val] is true.
  /// Otherwise, this computes size, creates and inserts and OverlayEntry.
  void _shouldHideOverlay(bool val) {
    try {
      if (_hideOverlay == val) return;
      _hideOverlay = val;
      if (_hideOverlay) {
        widget.animationController?.reverse();
        if (widget.animationController == null) {
          _overlayController.hide();
        }
      } else {
        _overlayController.show();
        widget.animationController?.forward();
      }
    } catch (_) {}
  }

  void _animationControllerListener() {
    if (widget.animationController?.status == AnimationStatus.dismissed &&
        _overlayController.isShowing) {
      _overlayController.hide();
    }
  }

  /// Custom trie to hold all tags.
  /// This is quite useful for doing a precise position-based tag search.
  late Trie _tagTrie;

  /// Map of tagged texts and their ids
  late final Map<TaggedText, String> _tags = {};

  Iterable<String> get triggerCharacters =>
      widget.triggerCharacterAndStyles.keys;

  /// Regex to match trigger characters that should activate the search context.
  RegExp get _triggerCharactersPattern {
    if (widget.triggerCharactersRegex != null) {
      return widget.triggerCharactersRegex!;
    }
    String pattern = triggerCharacters.first;
    int count = triggerCharacters.length;

    if (count > 1) {
      for (int i = 1; i < count; i++) {
        pattern += "|${triggerCharacters.elementAt(i)}";
      }
    }

    return RegExp(pattern);
  }

  /// Extracts nested tags (if any) from [text] and formats them.
  String _parseAndFormatNestedTags(String text, int startIndex) {
    if (text.isEmpty) return "";
    List<String> result = [];
    int start = startIndex;

    print("Parsing text: $text");
    // Check if this entire text is a tag
    TaggedText? fullTag = _tagTrie.search(text, startIndex);
    if (fullTag != null && fullTag.startIndex == startIndex) {
      // This entire text is a tag, format it consistently
      String formattedTagText =
          fullTag.text.substring(1); // Remove trigger char
      String triggerChar = fullTag.text[0].toString();

      formattedTagText = _formatTagText(
        _tags[fullTag]!,
        formattedTagText,
        triggerChar,
      );
      print("Formatted tag text: $formattedTagText");
      return formattedTagText;
    }

    final nestedWords = text.splitWithDelim(_triggerCharactersPattern);
    bool startsWithTrigger =
        triggerCharacters.contains(text[0]) && nestedWords.first.isNotEmpty;

    String triggerChar = "";
    int triggerCharIndex = 0;

    for (int i = 0; i < nestedWords.length; i++) {
      final nestedWord = nestedWords[i];

      if (nestedWord.contains(_triggerCharactersPattern)) {
        if (triggerChar.isNotEmpty && triggerCharIndex == i - 2) {
          result.add(triggerChar);
          start += triggerChar.length;
          triggerChar = "";
          triggerCharIndex = i;
          continue;
        }
        triggerChar = nestedWord;
        triggerCharIndex = i;
        continue;
      }

      String word;
      if (i == 0) {
        word = startsWithTrigger ? "$triggerChar$nestedWord" : nestedWord;
      } else {
        word = "$triggerChar$nestedWord";
      }

      TaggedText? taggedText;

      if (word.isNotEmpty) {
        taggedText = _tagTrie.search(word, start);
      }

      if (taggedText == null) {
        result.add(word);
      } else if (taggedText.startIndex == start) {
        String suffix = word.substring(taggedText.text.length);
        String formattedTagText = taggedText.text.replaceAll(triggerChar, "");
        formattedTagText = _formatTagText(
          _tags[taggedText]!,
          formattedTagText,
          triggerChar,
        );

        result.add(formattedTagText);
        if (suffix.isNotEmpty) result.add(suffix);
      } else {
        result.add(word);
      }

      start += word.length;
      triggerChar = "";
    }

    return result.join("");
  }

  /// Formatted text where tags are replaced with the result
  /// of calling [InputTagger.tagTextFormatter] if it's not null.
  /// Otherwise, tags are replaced in this format:
  /// ```dart
  /// "@Lucky Ebere"
  /// ```
  /// becomes
  ///
  /// ```dart
  /// "@6zo22531b866ce0016f9e5tt#Lucky Ebere#"
  /// ```
  /// assuming that `Lucky Ebere`'s id is `6zo22531b866ce0016f9e5tt`
  String get _formattedText {
    String controllerText = controller.text;

    if (controllerText.isEmpty) return "";

    // Create a copy of the text to work with
    String result = controllerText;

    // Sort tags by starting position (descending) to avoid position issues when replacing
    List<TaggedText> sortedTags = _tags.keys.toList()
      ..sort((a, b) => b.startIndex.compareTo(a.startIndex));

    // Replace each tag with its formatted version
    for (var tag in sortedTags) {
      String id = _tags[tag]!;
      String tagText = tag.text.substring(1); // Remove trigger char
      String triggerChar = tag.text[0].toString();

      String formattedTagText = _formatTagText(
        id,
        tagText,
        triggerChar,
      );

      result =
          result.replaceRange(tag.startIndex, tag.endIndex, formattedTagText);
    }
    return result;
  }

  /// Whether to not execute the [_tagListener] logic.
  bool _defer = false;

  /// Current tag selected in TextField.
  TaggedText? _selectedTag;

  /// Adds [tag] and [id] to [_tags] and
  /// updates TextField value with [tag].
  void _addTag(String id, String tag) {
    _shouldSearch = false;
    _shouldHideOverlay(true);

    tag = "$_currentTriggerChar${tag.trim()}";
    id = id.trim();

    final text = controller.text;
    late final position = controller.selection.base.offset - 1;
    int index = 0;
    int selectionOffset = 0;

    if (position != text.length - 1) {
      index = text.substring(0, position + 1).lastIndexOf(_currentTriggerChar);
    } else {
      index = text.lastIndexOf(_currentTriggerChar);
    }

    if (index >= 0) {
      _defer = true;

      String newText;

      if (index - 1 > 0 && text[index - 1] != " ") {
        newText = text.replaceRange(index, position + 1, " $tag");
        index++;
      } else {
        newText = text.replaceRange(index, position + 1, tag);
      }

      if (text.length - 1 == position) {
        newText += " ";
        selectionOffset++;
      }

      final oldCachedText = _lastCachedText;
      _lastCachedText = newText;
      controller.text = newText;
      _defer = true;

      int offset = index + tag.length;

      // Create TaggedText with the full tag text, including spaces
      final taggedText = TaggedText(
        startIndex: offset - tag.length,
        endIndex: offset,
        text: tag,
      );
      _tags[taggedText] = id;
      _tagTrie.insert(taggedText);

      controller.selection = TextSelection.fromPosition(
        TextPosition(
          offset: offset + selectionOffset,
        ),
      );

      _recomputeTags(
        oldCachedText,
        newText,
        taggedText.startIndex + 1,
      );

      _onFormattedTextChanged();
    }
  }

  /// Selects a tag from [_tags] when keyboard action attempts to remove it
  /// so as to prompt the user.
  ///
  /// The selected tag is removed from the TextField
  /// when [_removeEditedTags] is triggered.
  ///
  /// Does nothing when there is no tag or when there's no attempt
  /// to remove a tag from the TextField.
  ///
  /// Returns `true` if a tag is either selected or removed
  /// (if it was previously selected).
  /// Otherwise, returns `false`.
  bool _removeEditedTags() {
    try {
      final text = controller.text;
      if (_isTagSelected) {
        _removeSelection();
        return true;
      }
      if (text.isEmpty) {
        _tags.clear();
        _tagTrie.clear();
        _lastCachedText = text;
        return false;
      }
      final position = controller.selection.base.offset - 1;
      if (position >= 0 && triggerCharacters.contains(text[position])) {
        _shouldSearch = true;
        return false;
      }

      for (var tag in _tags.keys) {
        if (tag.endIndex - 1 == position + 1) {
          if (!_isTagSelected) {
            if (_backtrackAndSelect(tag)) return true;
          }
        }
      }
    } catch (_, trace) {
      debugPrint(trace.toString());
    }
    _lastCachedText = controller.text;
    _defer = false;
    return false;
  }

  /// Back tracks from current cursor position to find and select
  /// a tag, if any.
  ///
  /// Returns `true` if a tag is found and selected.
  /// Otherwise, returns `false`.
  bool _backtrackAndSelect(TaggedText tag) {
    String text = controller.text;
    if (!text.contains(_triggerCharactersPattern)) return false;

    final length = controller.selection.base.offset;

    if (tag.startIndex > length || tag.endIndex - 1 > length) {
      return false;
    }
    _defer = true;
    controller.text = _lastCachedText;
    text = _lastCachedText;
    _defer = true;
    controller.selection = TextSelection.fromPosition(
      TextPosition(offset: length),
    );

    late String temp = "";

    for (int i = length; i >= 0; i--) {
      if (i == length && triggerCharacters.contains(text[i])) return false;

      temp = text[i] + temp;
      if (triggerCharacters.contains(text[i]) &&
          temp.length > 1 &&
          temp == tag.text &&
          i == tag.startIndex) {
        _selectedTag = TaggedText(
          startIndex: i,
          endIndex: length + 1,
          text: tag.text,
        );
        _isTagSelected = true;
        _startOffset = i;
        _endOffset = length + 1;
        _defer = true;
        controller.selection = TextSelection(
          baseOffset: _startOffset!,
          extentOffset: _endOffset!,
        );
        return true;
      }
    }

    return false;
  }

  /// Updates offsets after [_selectedTag] set in [_backtrackAndSelect]
  /// has been removed.
  void _removeSelection() {
    _tags.remove(_selectedTag);
    _tagTrie.clear();
    _tagTrie.insertAll(_tags.keys);
    _selectedTag = null;
    final oldCachedText = _lastCachedText;
    _lastCachedText = controller.text;

    final pos = _startOffset!;
    _startOffset = null;
    _endOffset = null;
    _isTagSelected = false;

    _recomputeTags(oldCachedText, _lastCachedText, pos);
    _onFormattedTextChanged();
  }

  /// Whether a tag is selected in the TextField.
  bool _isTagSelected = false;

  /// Start offset for selection in the TextField.
  int? _startOffset;

  /// End offset for selection in the TextField.
  int? _endOffset;

  /// Text from the TextField in it's previous state before a new update
  /// (new text input from keyboard or deletion).
  ///
  /// This is necessary to compare and see if changes have occured and to restore
  /// the text field content when user attempts to remove a tag
  /// so that the tag can be selected and with further action, be removed.
  String _lastCachedText = "";

  /// Whether the search context is active.
  bool _shouldSearch = false;

  /// {@template searchRegex}
  /// Regex to match allowed search characters.
  /// Non-conforming characters terminate the search context.
  /// {@endtemplate}
  late final _searchRegexPattern =
      widget.searchRegex ?? RegExp(r'^[a-zA-Z\s-]*$');

  int _lastCursorPosition = 0;
  bool _isBacktrackingToSearch = false;

  /// Last trigger character which activated the search context.
  String _currentTriggerChar = "";

  /// This is triggered when deleting text from TextField that isn't
  /// a tag. Useful for continuing search without having to
  /// type a trigger character first.
  ///
  /// E.g, assuming trigger character is '@', if you typed
  /// ```dart
  /// @lucky|
  /// ```
  /// the search context is activated and `lucky` is sent as the search query.
  ///
  /// But if you continue with a terminating character like so:
  /// ```dart
  /// @lucky |
  /// ```
  /// the search context is exited and the overlay is dismissed.
  ///
  /// However, if the text is edited to bring the cursor back to
  ///
  /// ```dart
  /// @luck|
  /// ```
  /// the search context is entered again and the text after the
  /// trigger character is sent as the search query.
  ///
  /// Returns `true` if a search query is found from back tracking.
  /// Otherwise, returns `false`.
  bool _backtrackAndSearch() {
    String text = controller.text;
    if (!text.contains(_triggerCharactersPattern)) return false;

    _lastCachedText = text;
    final length = controller.selection.base.offset - 1;

    for (int i = length; i >= 0; i--) {
      if ((i == length && triggerCharacters.contains(text[i])) ||
          !triggerCharacters.contains(text[i]) &&
              !_searchRegexPattern.hasMatch(text[i])) {
        return false;
      }

      if (triggerCharacters.contains(text[i])) {
        final doesTagExistInRange = _tags.keys.any(
          (tag) => tag.startIndex == i && tag.endIndex == length + 1,
        );

        if (doesTagExistInRange) return false;

        _currentTriggerChar = text[i];
        _shouldSearch = true;
        _isTagSelected = false;
        _isBacktrackingToSearch = true;
        if (text.isNotEmpty) {
          _extractAndSearch(text, length);
        }

        return true;
      }
    }

    _isBacktrackingToSearch = false;
    return false;
  }
  bool _isCursorInsideTag() {
    final cursorPosition = controller.selection.baseOffset;
    final text = controller.text;

    if (cursorPosition == null || text.isEmpty) return false;

    for (var tag in _tags.keys) {
      if (cursorPosition > tag.startIndex && cursorPosition <= tag.endIndex) {
        return true;
      }
    }
    return false;
  }
  /// Listener attached to [controller] to listen for change in
  /// search context and tag selection.
  ///
  /// Triggers search:
  /// Activates the search context when last entered character is a trigger character.
  ///
  /// Ends Search:
  /// Exits search context and hides overlay when a terminating character
  /// not matched by [_searchRegexPattern] is entered.
  void _tagListener() {
    final currentCursorPosition = controller.selection.baseOffset;
    final text = controller.text;
    if (_isCursorInsideTag() || controller.isInitialTag) {
      _shouldHideOverlay(true);
    }
    // Fix: Improved handling of deletion near adjacent tags
    if (_lastCachedText.length != text.length) { // Deletion occurred
      final tagsToRemove = _tags.keys.where((tag) {
        // More careful range checking to prevent out-of-range errors
        return tag.startIndex < text.length &&  // Make sure not out of range
            currentCursorPosition <= tag.endIndex-1 &&
            currentCursorPosition >= tag.startIndex+2;
      }).toList();

      if (tagsToRemove.isNotEmpty) {
        for (var tag in tagsToRemove) {
          _tags.remove(tag);
        }
        _shouldSearch = false;
      }

    }
    // Check for backtracking search behavior
    if (_shouldSearch &&
        _isBacktrackingToSearch &&
        ((text.trim().length < _lastCachedText.trim().length &&
                _lastCursorPosition - 1 != currentCursorPosition) ||
            _lastCursorPosition + 1 != currentCursorPosition)) {
      _shouldSearch = false;
      _isBacktrackingToSearch = false;
      _shouldHideOverlay(true);
    }

    if (_defer) {
      _lastCachedText = text;
      _defer = false;

      // After adding a tag and immediately trying to activate the search context
      // by typing in a trigger character, the call to _tagListener is deffered.
      // So this check to activate the search context is repeated here
      // as the later part of this listener which does that is unreachable
      // when the call to _tagListener is deffered.
      int position = currentCursorPosition - 1;
      if (position >= 0 && triggerCharacters.contains(text[position])) {
        if (!_isCursorInsideTag() && !controller.isInitialTag) {
          _shouldSearch = true;
          _currentTriggerChar = text[position];
          if (widget.triggerStrategy == TriggerStrategy.eager) {
            _extractAndSearch(text, position);
          }
        }
      }
      _onFormattedTextChanged();
      return;
    }

    _lastCursorPosition = currentCursorPosition;

    if (text.isEmpty && _selectedTag != null) {
      _removeSelection();
    }

    // When a previously selected tag is unselected without removing,
    // reset tag selection state variables.
    if (_startOffset != null && currentCursorPosition != _startOffset) {
      _selectedTag = null;
      _startOffset = null;
      _endOffset = null;
      _isTagSelected = false;
    }

    final position = currentCursorPosition - 1;
    final oldCachedText = _lastCachedText;

    if (_shouldSearch && position >= 0) {
      if (!_searchRegexPattern.hasMatch(text[position])) {
        // Check if we're inside an existing tag before ending search
        bool insideTag = false;
        for (var tag in _tags.keys) {
          if (position >= tag.startIndex && position < tag.endIndex) {
            insideTag = true;
            break;
          }
        }

        if (!insideTag) {
          _shouldSearch = false;
          _shouldHideOverlay(true);
        }
      } else {
        _extractAndSearch(text, position);
        _recomputeTags(oldCachedText, text, position);
        widget.controller._onTextChanged(_formattedText);
        _lastCachedText = text;
        return;
      }
    }

    if (_lastCachedText == text) {
      if (position >= 0 && triggerCharacters.contains(text[position])) {
        _shouldSearch = true;
        _currentTriggerChar = text[position];
        if (widget.triggerStrategy == TriggerStrategy.eager) {
          _extractAndSearch(text, position);
        }
      }
      _recomputeTags(oldCachedText, text, position);
      _onFormattedTextChanged();
      return;
    }

    if (_lastCachedText.length > text.length ||
        currentCursorPosition < text.length) {
      if (_removeEditedTags()) {
        _shouldHideOverlay(true);
        _onFormattedTextChanged();
        return;
      }

      final hideOverlay = !_backtrackAndSearch();
      if (hideOverlay) _shouldHideOverlay(true);

      if (position < 0 || !triggerCharacters.contains(text[position])) {
        _recomputeTags(oldCachedText, text, position);
        _onFormattedTextChanged();
        return;
      }
    }

    _lastCachedText = text;

    if (position >= 0 && triggerCharacters.contains(text[position])) {
      _shouldSearch = true;
      _currentTriggerChar = text[position];
      if (widget.triggerStrategy == TriggerStrategy.eager) {
        _extractAndSearch(text, position);
      }
      _recomputeTags(oldCachedText, text, position);
      _onFormattedTextChanged();
      return;
    }

    if (position >= 0 && !_searchRegexPattern.hasMatch(text[position])) {
      _shouldSearch = false;
    }

    if (_shouldSearch && text.isNotEmpty) {
      _extractAndSearch(text, position);
    } else {
      _shouldHideOverlay(true);
    }

    _recomputeTags(oldCachedText, text, position);
    _onFormattedTextChanged();
  }

  /// Recomputes affected tag positions when text value is modified.
  void _recomputeTags(String oldCachedText, String currentText, int position) {
    final currentCursorPosition = controller.selection.baseOffset;
    if (currentCursorPosition != currentText.length) {
      Map<TaggedText, String> newTable = {};
      _tagTrie.clear();

      for (var tag in _tags.keys) {
        if (tag.startIndex >= position) {
          final newTag = TaggedText(
            startIndex:
                tag.startIndex + currentText.length - oldCachedText.length,
            endIndex: tag.endIndex + currentText.length - oldCachedText.length,
            text: tag.text,
          );

          _tagTrie.insert(newTag);
          newTable[newTag] = _tags[tag]!;
        } else {
          _tagTrie.insert(tag);
          newTable[tag] = _tags[tag]!;
        }
      }

      _tags.clear();
      _tags.addAll(newTable);
    }
  }

  /// Extracts text appended to the last [_currentTriggerChar] symbol
  /// found in the substring of [text] up until [endOffset]
  /// and calls [InputTagger.onSearch].
  void _extractAndSearch(String text, int endOffset) {
    try {
      if (_isCursorInsideTag() || controller.isInitialTag) {
          _shouldHideOverlay(true);
          return;
      }
      int index =
          text.substring(0, endOffset + 1).lastIndexOf(_currentTriggerChar);

      if (index < 0) return;

      final query = text.substring(
        index + 1,
        endOffset + 1,
      );

      _shouldHideOverlay(false);
      widget.onSearch(query, _currentTriggerChar);
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _tagTrie = controller._trie;
    controller._setDeferCallback(() => _defer = true);
    controller._setTags(_tags);
    controller._setTagStyles(widget.triggerCharacterAndStyles);
    // Initialize the pattern first
    final pattern = _triggerCharactersPattern;
    controller._setTriggerCharactersRegExpPattern(pattern);
    controller._registerFormatTagTextCallback(_formatTagText);
    controller.addListener(_tagListener);
    controller._onClear(() {
      _tags.clear();
      _tagTrie.clear();
    });
    controller._onDismissOverlay(() {
      _shouldHideOverlay(true);
    });
    controller._registerAddTagCallback(_addTag);
    widget.animationController?.addListener(_animationControllerListener);
  }

  @override
  void dispose() {
    controller.removeListener(_tagListener);
    widget.animationController?.removeListener(_animationControllerListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _overlayController,
      child: widget.builder(context, _textFieldKey),
      overlayChildBuilder: (context) {
        Offset offset = Offset.zero;
        double width = 0;

        try {
          final renderBox =
              _textFieldKey.currentContext!.findRenderObject() as RenderBox;
          width = renderBox.size.width;
          offset = renderBox.localToGlobal(Offset.zero);
        } catch (_) {}

        double? top;
        double? bottom;

        if (widget.overlayPosition == OverlayPosition.top) {
          top = offset.dy - (widget.overlayHeight + widget.padding.vertical);
        }

        if (widget.overlayPosition == OverlayPosition.bottom) {
          bottom = offset.dy - widget.overlayHeight - widget.padding.vertical;
        }

        return Positioned(
          left: offset.dx,
          width: width,
          height: widget.overlayHeight,
          top: top,
          bottom: bottom,
          child: widget.overlay,
        );
      },
    );
  }
}

/// {@template InputTaggerController}
/// Controller for [InputTagger].
/// This object exposes callback registration bindings to enable clearing
/// [InputTagger]'s tags, dismissing overlay and retrieving formatted text.
/// {@endtemplate}
class InputTaggerController extends TextEditingController {
  InputTaggerController({String? text}) : super(text: text);

  late final Trie _trie = Trie();
  late Map<TaggedText, String> _tags;

  late Map<String, TextStyle> _tagStyles;

  void _setTagStyles(Map<String, TextStyle> tagStyles) {
    _tagStyles = tagStyles;
  }

  RegExp? _triggerCharsPattern = RegExp(r'[@#]'); // Provide a sensible default;

  RegExp get _triggerCharactersPattern =>
      _triggerCharsPattern ?? RegExp(r'[@#]');

  void _setTriggerCharactersRegExpPattern(RegExp pattern) {
    _triggerCharsPattern = pattern;
    _formatTagsCallback ??= () => _formatTags(null, null);
    _formatTagsCallback?.call();
  }

  void _setTags(Map<TaggedText, String> tags) {
    _tags = tags;
  }

  void _setDeferCallback(Function callback) {
    _deferCallback = callback;
  }

  int _cursorposition = 0;

  /// Position of the cursor in [formattedText].
  int get cursorPosition => _cursorposition;

  /// Computes position of cursor in [formattedText] at [selectionOffset]
  /// in [text] by exploding tags in [text] to their formatted form (with ID).
  int _getCursorPosition(int selectionOffset) {
    String subText = text.substring(0, selectionOffset);
    int offset = 0;

    final pattern = _triggerCharsPattern;
    if (pattern == null) return subText.length; // or handle appropriately

    for (var tag in _tags.keys) {
      if (tag.startIndex < selectionOffset && tag.endIndex <= selectionOffset) {
        final id = _tags[tag]!;
        final tagText = tag.text.substring(1);
        final triggerCharacter = tag.text[0];

        final formattedTagText =
            _formatTagTextCallback?.call(id, tagText, triggerCharacter);

        if (formattedTagText != null) {
          final newText = subText.replaceRange(
            tag.startIndex + offset,
            tag.endIndex + offset,
            formattedTagText,
          );

          offset = newText.length - subText.length;
          subText = newText;
        }
      }
    }
    return subText.length;
  }

  @override
  set selection(TextSelection newSelection) {
    if (newSelection.isValid) {
      _cursorposition = _getCursorPosition(newSelection.baseOffset);
    } else {
      _cursorposition = _text.length;
    }
    super.selection = newSelection;
  }

  Function? _deferCallback;
  Function? _clearCallback;
  Function? _dismissOverlayCallback;
  Function(String id, String name)? _addTagCallback;
  String Function(String id, String tag, String triggerCharacter)?
      _formatTagTextCallback;

  String _text = "";

  /// Formatted text from [InputTagger]
  String get formattedText => _text;

  Function? _formatTagsCallback;

  /// {@template formatTags}
  /// Extracts tags from [InputTaggerController]'s [text] and formats the textfield to display them as tags.
  /// This should be called after [InputTaggerController] is constructed with a non-null
  /// text value that contain unformatted tags.
  ///
  /// [pattern] -> Pattern to match tags.
  /// Specify this if you supply your own [InputTagger.tagTextFormatter].
  ///
  /// [parser] -> Parser to extract id and tag name for regex matches.
  /// Returned list should have this structure: `[id, tagName]`.
  /// {@endtemplate}
  void formatTags({
    RegExp? pattern,
    List<String> Function(String)? parser,
  }) {
    if (_triggerCharsPattern == null) {
      _formatTagsCallback = () => _formatTags(pattern, parser);
    } else {
      _formatTagsCallback?.call();
    }
  }

  /// {@macro formatTags}
  void _formatTags([
    RegExp? pattern,
    List<String> Function(String)? parser,
  ]) {
    _clearCallback?.call();
    _text = text;

    // If there are no tags yet, try to find them using the pattern
    if (_tags.isEmpty && text.isNotEmpty) {
      String newText = text;

      pattern ??= RegExp(r'([@#]\w+(?:\s+\w+)*\#.+?\#)');
      parser ??= (value) {
        final split = value.split("#");
        if (split.length == 4) {
          // Handle multi-word tags
          return [split[1].trim(), split[2].trim()];
        }
        // Handle user mentions with spaces
        final id = split.first.trim().replaceFirst("@", "");
        return [id, split[split.length - 2].trim()];
      };

      final matches = pattern.allMatches(text);
      int diff = 0;

      for (var match in matches) {
        try {
          final matchValue = match.group(1)!;

          final idAndTag = parser(matchValue);
          final triggerChar = text.substring(match.start, match.start + 1);

          // Preserve spaces in tags
          final tag = "$triggerChar${idAndTag.last.trim()}";
          final startIndex = match.start;
          final endIndex = startIndex + tag.length;

          newText = newText.replaceRange(
            startIndex - diff,
            startIndex + matchValue.length - diff,
            tag,
          );

          final taggedText = TaggedText(
            startIndex: startIndex - diff,
            endIndex: endIndex - diff,
            text: tag,
          );
          _tags[taggedText] = idAndTag.first;
          _trie.insert(taggedText);

          diff += matchValue.length - tag.length;
        } catch (_) {}
      }

      if (newText.isNotEmpty) {
        _runDeferedAction(() => text = newText);
        _runDeferedAction(
          () => selection = TextSelection.fromPosition(
            TextPosition(offset: newText.length),
          ),
        );
      }
    }

    // Now format the text based on existing tags
    String result = text;

    // Sort tags by starting position (descending) to avoid position issues when replacing
    List<TaggedText> sortedTags = _tags.keys.toList()
      ..sort((a, b) => b.startIndex.compareTo(a.startIndex));

    // Replace each tag with its formatted version
    for (var tag in sortedTags) {
      String id = _tags[tag]!;
      String tagText = tag.text.substring(1); // Remove trigger char
      String triggerChar = tag.text[0].toString();

      String formattedTagText =
          _formatTagTextCallback?.call(id, tagText, triggerChar) ??
              "$triggerChar$id#$tagText#";

      // Add this formatted text to our _text result
      result =
          result.replaceRange(tag.startIndex, tag.endIndex, formattedTagText);
    }

    _text = result;
  }

  /// Defers [InputTagger]'s listener attached to this controller.
  void _runDeferedAction(Function action) {
    _deferCallback?.call();
    action.call();
  }

  /// Clears [InputTagger] internal tag state.
  @override
  void clear() {
    _clearCallback?.call();
    _text = '';
    super.clear();
  }

  /// Dismisses overlay.
  void dismissOverlay() {
    _dismissOverlayCallback?.call();
  }
  ///if initialTag
  bool isInitialTag = false;

  /// Adds a tag.
  void addTag({required String id, required String name}) {
    _addTagCallback?.call(id, name);
  }

  /// Registers callback for clearing [InputTagger]'s
  /// internal tags state.
  void _onClear(Function callback) {
    _clearCallback = callback;
  }

  /// Registers callback for dismissing [InputTagger]'s overlay.
  void _onDismissOverlay(Function callback) {
    _dismissOverlayCallback = callback;
  }

  /// Updates [_text] with updated and formatted text from [InputTagger].
  void _onTextChanged(String newText) {
    _text = newText;
  }

  /// Registers callback for adding tags.
  void _registerAddTagCallback(Function(String id, String name) callback) {
    _addTagCallback = callback;
  }

  /// Registers callback for formatting tag texts.
  void _registerFormatTagTextCallback(
    String Function(String id, String tag, String triggerCharacter) callback,
  ) {
    _formatTagTextCallback = callback;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    assert(!value.composing.isValid ||
        !withComposing ||
        value.isComposingRangeValid);

    return _buildTextSpan(style);
  }

  /// Builds text value with tagged texts styled using styles from [_tagStyles].
  TextSpan _buildTextSpan(TextStyle? style) {
    if (text.isEmpty) return const TextSpan();

    // Instead of splitting by spaces, we need to tokenize the text
    // while preserving tags
    List<TextSpan> spans = [];
    int position = 0;

    while (position < text.length) {
      // Check if the current position is part of a tag
      TaggedText? currentTag = null;
      for (var tag in _tags.keys) {
        if (position >= tag.startIndex && position < tag.endIndex) {
          currentTag = tag;
          break;
        }
      }

      if (currentTag != null) {
        // We're inside a tag, add it as a styled span
        spans.add(TextSpan(
          text: text.substring(currentTag.startIndex, currentTag.endIndex),
          style: _tagStyles[text[currentTag.startIndex]],
        ));
        position = currentTag.endIndex;
      } else {
        // Find the next tag or the end of text
        int nextTagStart = text.length;
        for (var tag in _tags.keys) {
          if (tag.startIndex > position && tag.startIndex < nextTagStart) {
            nextTagStart = tag.startIndex;
          }
        }

        // Add the text up to the next tag
        spans.add(TextSpan(
          text: text.substring(position, nextTagStart),
        ));
        position = nextTagStart;
      }
    }

    return TextSpan(children: spans, style: style);
  }

  /// Extracts nested tags (if any) from [text].
  List<Tag> _getTags(String text, int startIndex) {
    if (text.isEmpty) return [];
    List<Tag> result = [];
    int start = startIndex;

    final nestedWords = text.splitWithDelim(_triggerCharactersPattern);
    bool startsWithTrigger = text[0].contains(_triggerCharactersPattern) &&
        nestedWords.first.isNotEmpty;

    String triggerChar = "";
    int triggerCharIndex = 0;

    for (int i = 0; i < nestedWords.length; i++) {
      final nestedWord = nestedWords[i];

      if (nestedWord.contains(_triggerCharactersPattern)) {
        if (triggerChar.isNotEmpty && triggerCharIndex == i - 2) {
          start += triggerChar.length;
          triggerChar = "";
          triggerCharIndex = i;
          continue;
        }
        triggerChar = nestedWord;
        triggerCharIndex = i;
        continue;
      }

      String word;
      if (i == 0) {
        word = startsWithTrigger ? "$triggerChar$nestedWord" : nestedWord;
      } else {
        word = "$triggerChar$nestedWord";
      }

      TaggedText? taggedText;

      if (word.isNotEmpty) {
        taggedText = _trie.search(word, start);
      }

      if (taggedText != null && taggedText.startIndex == start) {
        final tag = Tag(
          id: _tags[taggedText]!,
          text: taggedText.text.replaceAll(triggerChar, ""),
          triggerCharacter: triggerChar,
        );
        result.add(tag);
      }

      start += word.length;
      triggerChar = "";
    }

    return result;
  }

  /// The tags that are currently applied.
  /// The tags that are currently applied.
  Iterable<Tag> get tags {
    if (text.isEmpty) return [];

    // Use the existing tags map instead of re-parsing the text
    List<Tag> result = [];

    // Simply iterate through the _tags map which already contains
    // the correct positions and text for all tags
    for (var taggedText in _tags.keys) {
      final id = _tags[taggedText]!;
      final tagText = taggedText.text;
      final triggerChar = tagText[0].toString();
      final content = tagText.substring(1); // Remove the trigger character

      result.add(Tag(
        id: id,
        text: content,
        triggerCharacter: triggerChar,
      ));
    }

    return result;
  }
}

extension _RegExpExtension on RegExp {
  List<String> allMatchesWithSep(String input, [int start = 0]) {
    var result = <String>[];
    for (var match in allMatches(input, start)) {
      result.add(input.substring(start, match.start));
      result.add(match[0]!);
      start = match.end;
    }
    result.add(input.substring(start));
    return result;
  }
}

extension _StringExtension on String {
  List<String> splitWithDelim(RegExp pattern) =>
      pattern.allMatchesWithSep(this);
}
