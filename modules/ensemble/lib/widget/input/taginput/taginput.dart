import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/layout/form.dart';
import 'package:ensemble/model/item_template.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/debouncer.dart';
import 'package:ensemble/util/input_formatter.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/form_helper.dart';
import 'package:ensemble/widget/helpers/input_wrapper.dart';
import 'package:ensemble/widget/helpers/input_field_helper.dart'; // Import the helper class
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ensemble/layout/templated.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/services.dart';
import 'package:input_tagger/input_tagger.dart';

/// TagInput
class TagInput extends BaseTextInput {
  static const type = 'TagInput';

  TagInput({Key? key}) : super(key: key);

  @override
  Map<String, Function> setters() {
    Map<String, Function> setters = super.setters();
    setters.addAll({
      'value': (newValue) {
        if (newValue == null) {
          _controller.taggerControllerValue = '';
          return;
        }
        _controller.taggerControllerValue = Utils.optionalString(newValue)!;
      },
      'inputType': (type) => _controller.inputType = Utils.optionalString(type),
      'mask': (type) => _controller.mask = Utils.optionalString(type),
      'onDelayedKeyPress': (function) => _controller.onDelayedKeyPress =
          EnsembleAction.from(function, initiator: this),
      'delayedKeyPressDuration': (value) =>
          _controller.delayedKeyPressDuration =
              Utils.getDurationMs(value) ?? _controller.delayedKeyPressDuration,
    });
    return setters;
  }

  @override
  TextInputType? get keyboardType => InputFieldHelper.getKeyboardType('text');

  @override
  void setItemTemplate(Map? maybeTemplate) {
    _controller.itemTemplate = LabelValueItemTemplate.from(maybeTemplate);
  }
}

/// Base StatefulWidget for both TextInput and Password
abstract class BaseTextInput extends StatefulWidget
    with
        Invokable,
        HasItemTemplate,
        HasController<TagInputController, TagInputState> {
  BaseTextInput({Key? key}) : super(key: key);

  final TagInputController _controller = TagInputController();

  @override
  TagInputController get controller => _controller;

  @override
  Map<String, Function> getters() {
    var getters = _controller.textPlaceholderGetters;
    getters.addAll({
      'value': () => _controller.taggerController.formattedText ?? '',
      'currentTriggerChar': () => _controller
          .currentTriggerChar, // Getter for current trigger character
    });
    return getters;
  }

  @override
  Map<String, Function> setters() {
    var setters = _controller.textPlaceholderSetters;

    // Use the common setters from the helper
    setters.addAll(InputFieldHelper.getCommonSetters(this, _controller));

    // Add TagInput specific setters
    setters.addAll({
      'triggers': (items) => buildTagTriggers(items),
      'initialTag': (tag) {
        if (tag is Map) {
          Map<String, String> newTag = {
            'id': tag['id']?.toString() ?? '',
            'label': tag['label']?.toString() ?? '',
            'key': tag['key']?.toString() ?? '',
          };
          _controller.initialTag = newTag;
        } else if (tag == null) {
          _controller.initialTag = null;
        }
      },
      'maxOverlayHeight': (value) =>
          _controller.maxOverlayHeight = Utils.optionalDouble(value),
      'minOverlayHeight': (value) =>
          _controller.minOverlayHeight = Utils.optionalDouble(value),
      'tagStyle': (style) => _controller.tagStyle = Utils.getTextStyle(style),
      'tagSelectionStyle': (style) =>
          _controller.tagSelectionStyle = Utils.getTextStyle(style),
      'overlayStyle': (style) =>
          _controller.overlayStyle = Utils.getBoxDecoration(style),
      'mentionStyle': (style) =>
          _controller.mentionStyle = Utils.getTextStyle(style),
      'onSearch': (function) =>
          _controller.onSearch = EnsembleAction.from(function, initiator: this),
    });
    return setters;
  }

  @override
  Map<String, Function> methods() {
    return {
      'focus': () => _controller.inputFieldAction?.focusInputField(),
      'unfocus': () => _controller.inputFieldAction?.unfocusInputField(),
      'clear': () => _controller.taggerController.clear(),
    };
  }

  Map<String, TextStyle?> buildTagTriggers(List<dynamic>? triggers) {
    Map<String, TextStyle?> results = {};

    if (triggers != null && triggers.isNotEmpty) {
      for (var item in triggers) {
        if (item is Map) {
          String? character = item['character']?.toString();
          if (character != null) {
            // Parse the tagStyle map to create TextStyle
            if (item['tagStyle'] is Map) {
              results[character] = Utils.getTextStyle(item['tagStyle']);
            } else {
              results[character] = const TextStyle(color: Colors.blue);
            }
          }
        }
      }
    }

    // If no triggers were defined, add a default @ trigger
    if (results.isEmpty) {
      results['@'] = const TextStyle(color: Colors.blue);
    }

    _controller.triggers = results;
    _controller.setupTriggerTypes(triggers);
    return results;
  }

  @override
  TagInputState createState() => TagInputState();

  TextInputType? get keyboardType;
}

mixin TextInputFieldAction on FormFieldWidgetState<BaseTextInput>
    implements InputFieldAction {
  @override
  void focusInputField();

  @override
  void unfocusInputField();
}

/// Controller for TagInput extending BaseInputController
class TagInputController extends BaseInputController {
  // Private properties
  String _taggerControllerValue = '';
  String _currentTriggerChar = '@';
  Map<String, String> _triggerTypeMap = {};
  InputTaggerController? _taggerController;
  bool _initialTagApplied = false;
  bool _applyingInitialTag = false;
  Map<String, String>? _initialTag;

  // Configurable properties
  Map<String, TextStyle?> triggers = {'@': const TextStyle(color: Colors.blue)};
  LabelValueItemTemplate? itemTemplate;
  TextStyle? mentionStyle;
  EnsembleAction? onSearch;
  BoxDecoration? overlayStyle;
  double? maxOverlayHeight;
  double? minOverlayHeight;
  TextStyle? tagStyle;
  TextStyle? tagSelectionStyle;

  // Getters and Setters
  String get currentTriggerChar => _currentTriggerChar;

  String get taggerControllerValue => _taggerControllerValue;
  set taggerControllerValue(String value) {
    _taggerControllerValue = value;
    if (_taggerController != null) {
      _taggerController!.text = value;
    }
  }

  Map<String, String>? get initialTag => _initialTag;
  set initialTag(Map<String, String>? value) {
    if (_initialTag != value) {
      _initialTag = value;
      if (_taggerController != null) {
        applyInitialTag();
      }
    }
  }

  InputTaggerController get taggerController {
    if (_taggerController == null) {
      _taggerController = InputTaggerController(text: _taggerControllerValue);
    }
    return _taggerController!;
  }

  // Setup Trigger Types
  void setupTriggerTypes(List<dynamic>? triggers) {
    _triggerTypeMap.clear();

    if (triggers != null) {
      for (var item in triggers) {
        if (item is Map) {
          String? character = item['character']?.toString();
          String? triggerType = item['triggerType']?.toString();

          if (character != null && triggerType != null) {
            _triggerTypeMap[character] = triggerType;
          }
        }
      }
    }
  }

  // Apply Initial Tag
  void applyInitialTag() {
    if (initialTag == null) return;

    _initialTagApplied = false;
    _applyingInitialTag = true;

    if (initialTag == null) return;
    if (_initialTagApplied) return;

    final tag = initialTag!;
    final triggerChar = triggers.keys.first;

    _initialTagApplied = true;

    if (tag.containsKey('id') &&
        (tag.containsKey('key') || tag.containsKey('label'))) {
      String displayText = tag['label'] ?? tag['key'] ?? '';

      taggerController.clear();
      taggerController.selection =
          TextSelection.collapsed(offset: taggerController.text.length);

      taggerController.addTag(id: tag['id']!, name: '$triggerChar$displayText');

      final text = taggerController.text;
      if (!text.endsWith(' ')) {
        taggerController.text = '$text ';
        taggerController.selection =
            TextSelection.collapsed(offset: taggerController.text.length);
      }

      _taggerControllerValue = taggerController.text;
      _applyingInitialTag = false;
    }
  }

  @override
  void dispose() {
    _taggerController?.dispose();
    _taggerController = null;
    super.dispose();
  }
}

class TagInputState extends FormFieldWidgetState<BaseTextInput>
    with TickerProviderStateMixin, TextInputFieldAction, TemplatedWidgetState {
  // Core controller references
  InputTaggerController get _taggerController =>
      widget._controller.taggerController;

  // UI state
  final focusNode = FocusNode();
  List? dataList;
  String? tagQuery;
  // Track the filtered results count for dynamic height calculation
  int _filteredResultsCount = 0;
  double _listTileHeight = 60.0; // Default height for a list tile
  // For change tracking
  String previousText = '';
  bool didItChange = false;
  bool _isOverlayVisible = false;
  bool _initialized = false;

  // Initialize these fields immediately
  List<TextInputFormatter> _inputFormatter = [];
  AnimationController? _animationController;
  Animation<Offset>? _animation;

  void evaluateChanges() {
    if (didItChange) {
      // trigger binding
      widget.setProperty('value', _taggerController.text);

      // call onChange
      if (widget._controller.onChange != null) {
        ScreenController().executeAction(context, widget._controller.onChange!,
            event: EnsembleEvent(widget));
      }
      didItChange = false;
    }
  }

  void removeOverlayAndUnfocus() {
    if (!_isOverlayVisible) {
      _taggerController.dismissOverlay();
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  @override
  void initState() {
    super.initState();

    // Initialize input formatters
    _inputFormatter = InputFormatter.getFormatter(
        widget._controller.inputType, widget._controller.mask);

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _animation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController!,
        curve: Curves.easeInOut,
      ),
    );

    // Setup focus listeners
    focusNode.addListener(() {
      if (focusNode.hasFocus) {
        if (widget._controller.onFocusReceived != null) {
          ScreenController().executeAction(
              context, widget._controller.onFocusReceived!,
              event: EnsembleEvent(widget));
        }
      } else {
        evaluateChanges();

        if (widget._controller.onFocusLost != null) {
          ScreenController().executeAction(
              context, widget._controller.onFocusLost!,
              event: EnsembleEvent(widget));
        }
      }
    });

    // Defer initialization of the tagger to first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _initialized = true;
        });
        Future.delayed(Duration(milliseconds: 200), () {
          // Change from initialTags to initialTag
          if (mounted && widget._controller.initialTag != null) {
            widget._controller.applyInitialTag();
          }
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.controller.inputFieldAction = this;

    if (widget._controller.itemTemplate != null) {
      widget._controller.itemTemplate!.data = scopeManager!.dataContext.eval(widget._controller.itemTemplate!.data);
      registerItemTemplate(context, widget._controller.itemTemplate!,
          onDataChanged: (data) {
        if (mounted) {
          setState(() {
            dataList = data;
          });
        }
      });
    }

    // Check for readOnly from parent widget
    if (widget._controller.readOnly == null) {
      final formController =
          context.findAncestorWidgetOfExactType<EnsembleForm>()?.controller;

      if (formController != null) {
        widget._controller.readOnly = formController.readOnly == true;
      }
    }
  }

  @override
  void didUpdateWidget(covariant BaseTextInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.controller.inputFieldAction = this;
    widget._controller._taggerController = oldWidget._controller._taggerController;

    // Making sure to move cursor to end when widget rebuild
    if (focusNode.hasFocus) {
      int oldCursorPosition =
          oldWidget._controller.taggerController.selection.baseOffset;
      int textLength = widget._controller.taggerController.text.length;

      widget._controller.taggerController.selection =
          TextSelection.fromPosition(
        TextPosition(offset: oldCursorPosition),
      );
      int cursorPosition =
          widget._controller.taggerController.selection.baseOffset;

      if (textLength > cursorPosition) {
        widget._controller.taggerController.selection =
            TextSelection.fromPosition(
          TextPosition(offset: textLength),
        );
      }
    }
  }

  @override
  void dispose() {
    focusNode.dispose();
    _animationController?.dispose();
    super.dispose();
  }

  // Calculate the dynamic height based on results
  double get _calculatedOverlayHeight {
    if (_listTileHeight < 60.0) _listTileHeight = 60.0;
    // Calculate the height based on the number of results
    double height = _filteredResultsCount * _listTileHeight;
    // Set minimum and maximum height constraints
    if (widget._controller.minOverlayHeight != null) {
      if (height < widget._controller.minOverlayHeight!) {
        height = widget._controller.minOverlayHeight!;
      }
    } else {
      if (height < 60.0) height = 60.0;
    }
    if (widget._controller.maxOverlayHeight != null) {
      if (height > widget._controller.maxOverlayHeight!) {
        height = widget._controller.maxOverlayHeight!;
      }
    } else {
      if (height > 300.0) height = 300.0;
    }
    return height;
  }

  @override
  Widget buildWidget(BuildContext context) {
    if (!_initialized) {
      // Return a simple loading state or basic input until fully initialized
      return InputWrapper(
        type: TagInput.type,
        controller: widget._controller,
        widget: TextFormField(
          controller: TextEditingController(
              text: widget._controller.taggerControllerValue),
          decoration: inputDecoration,
          enabled: false,
        ),
      );
    }

    return _buildFullTagInput(context);
  }

  Widget _buildFullTagInput(BuildContext context) {
    InputDecoration decoration = inputDecoration;

    // Apply styles and configurations
    if (widget._controller.floatLabel == true) {
      decoration = decoration.copyWith(
        labelText: widget._controller.label,
      );
    }
    if (widget._controller.errorStyle != null) {
      decoration = decoration.copyWith(
        errorStyle: widget._controller.errorStyle,
      );
    }

    if (_taggerController.text.isNotEmpty &&
        widget._controller.enableClearText == true) {
      decoration = decoration.copyWith(
        suffixIcon: IconButton(
          onPressed: _clearSelection,
          icon: const Icon(Icons.close),
        ),
      );
    }
    if (widget.controller.endingWidget != null) {
      decoration = decoration.copyWith(
        suffixIcon: scopeManager!
            .buildWidgetFromDefinition(widget.controller.endingWidget),
      );
    }

    return InputWrapper(
        type: TagInput.type,
        controller: widget._controller,
        widget: InputTagger(
          controller: _taggerController,
          animationController: _animationController,
          tagTextFormatter: (id, tag, triggerCharacter) {
            return "$triggerCharacter$id";
          },
          onSearch: (query, triggerCharacter) async {
            _isOverlayVisible = true;
            if (widget._controller.onSearch != null) {
              ScreenController().executeAction(
                context,
                widget._controller.onSearch!,
                event: EnsembleEvent(widget, data: {
                  'query': query,
                  'triggerChar': triggerCharacter,
                  'triggerType': widget._controller._triggerTypeMap[
                      triggerCharacter]
                }),
              );
            }
            setState(() {
              tagQuery = query;
            });
          },
          triggerCharacterAndStyles: {
            for (var entry in widget._controller.triggers.entries)
              entry.key: entry.value ?? const TextStyle(color: Colors.blue),
          },
          triggerStrategy: widget._controller._applyingInitialTag
              ? TriggerStrategy.deferred
              : TriggerStrategy.eager,
          overlayHeight: _calculatedOverlayHeight,
          overlay: _isOverlayVisible ?
            Material(
              child: SlideTransition(
                position: _animation!,
                child: Container(
                  decoration: widget._controller.overlayStyle,
                  child: buildItems(
                      widget.controller.itemTemplate, dataList, tagQuery),
                ),
            )): Container(),
          builder: (context, containerKey) {
            // Use the helper to create a TextFormField with common configuration
            return InputFieldHelper.createTextFormField(
              key: containerKey,
              autofillHints: widget._controller.autofillHints,
              controller: _taggerController,
              focusNode: focusNode,
              validateOnUserInteraction:
                  widget._controller.validateOnUserInteraction,
              validator: (value) => InputFieldHelper.validateInput(
                  value,
                  widget._controller.required ?? false,
                  widget._controller.requiredMessage,
                  widget._controller.validator),
              inputFormatters: _inputFormatter,
              multiline: widget._controller.multiline,
              minLines: widget._controller.minLines,
              maxLines: widget._controller.maxLines,
              maxLength: widget._controller.maxLength,
              maxLengthEnforcement: widget._controller.maxLengthEnforcement,
              enabled: isEnabled(),
              readOnly: widget._controller.readOnly,
              selectable: widget._controller.selectable,
              onChanged: (String txt) {
                if (isLastWordATag(txt)) {
                  _isOverlayVisible = true;
                } else {
                  _isOverlayVisible = false;
                }
                if (txt != previousText) {
                  previousText = txt;
                  didItChange = true;
                  widget._controller._taggerControllerValue = txt;

                  if (widget._controller.onKeyPress != null) {
                    ScreenController().executeAction(
                        context, widget._controller.onKeyPress!,
                        event: EnsembleEvent(widget));
                  }

                  if (widget._controller.onDelayedKeyPress != null) {
                    InputFieldHelper.executeDelayedAction(
                        context,
                        widget._controller.onDelayedKeyPress!,
                        widget,
                        getKeyPressDebouncer());
                  }
                }
                setState(() {});
              },
              onFieldSubmitted: (value) {
                widget.controller.submitForm(context);
              },
              onTapOutside: (_) => removeOverlayAndUnfocus(),
              textStyle: widget._controller.textStyle,
              decoration: decoration,
              keyboardAction: widget._controller.keyboardAction,
              keyboardType: widget.keyboardType,
              enableSuggestions: true,
              autocorrect: true,
            );
          },
        ));
  }

  bool isLastWordATag(String message) {
    if (message.isEmpty) return false;

    if (message.length > 0 && message[message.length - 1] == " ") {
      return false;
    }

    // Trim any spaces at the end
    message = message.trim();

    // Split the message into words
    List<String> words = message.split(" ");

    // Check if the last word exists and starts with a trigger character
    if (words.isNotEmpty) {
      final lastWord = words.last;

      // Check each trigger character
      for (String trigger in widget._controller.triggers.keys) {
        if (lastWord.startsWith(trigger)) {
          // Update the current trigger character when found
          widget._controller._currentTriggerChar = trigger;
          return true; // It is a tag
        }
      }
    }

    return false; // Not a tag
  }

  void _clearSelection() {
    _taggerController.clear();
    widget._controller._initialTagApplied = false; // Reset flag when clearing
    focusNode.unfocus();
  }

  ListView? buildItems(
      LabelValueItemTemplate? itemTemplate, List? dataList, String? tagQuery) {
    List<ListTile> results = [];

    // Normalize the query
    String query = tagQuery?.toLowerCase() ?? '';

    // Get current trigger and its type
    String currentTrigger = widget._controller.currentTriggerChar;
    String? currentTriggerType =
        widget._controller._triggerTypeMap[currentTrigger];

    // Find the data group matching the current trigger type
    List? filteredDataList;
    if (currentTriggerType != null && dataList != null) {
      // Look for a group with matching triggerType
      for (var group in dataList) {
        if (group is Map &&
            group['triggerType'] == currentTriggerType &&
            group['data'] is List) {
          filteredDataList = group['data'];
          break;
        }
      }
    }

    // If no matching group found or no trigger type, use the full data list
    filteredDataList ??= dataList;

    // Filter the templated list - use filteredDataList instead of dataList
    if (itemTemplate != null && filteredDataList != null) {
      ScopeManager? parentScope = DataScopeWidget.getScope(context);
      if (parentScope != null) {
        for (var itemData in filteredDataList) {
          ScopeManager templatedScope = parentScope.createChildScope();
          templatedScope.dataContext
              .addDataContextById(itemTemplate.name, itemData);

          String label = templatedScope.dataContext.eval(itemTemplate.label!);
          String value = templatedScope.dataContext.eval(itemTemplate.value);

          if (label.toLowerCase().contains(query) ||
              value.toLowerCase().contains(query)) {
            final GlobalKey labelWidgetKey = GlobalKey();

            var labelWidget = DataScopeWidget(
                key: labelWidgetKey,
                scopeManager: templatedScope,
                child: templatedScope
                    .buildWidgetFromDefinition(itemTemplate.labelWidget));

            // Add a post-frame callback to get the height after rendering
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (labelWidgetKey.currentContext != null && mounted) {
                final RenderBox renderBox = labelWidgetKey.currentContext!
                    .findRenderObject() as RenderBox;
                if (mounted) {
                  setState(() {
                    _listTileHeight = renderBox.size.height > 0
                        ? renderBox.size.height
                        : _listTileHeight;
                  });
                }
              }
            });

            results.add(ListTile(
              title: labelWidget,
              hoverColor: Colors.pink,
              onTap: () {
                _taggerController.addTag(
                  id: value,
                  name: label,
                );
                // Change the overlay visibility flag to false to allow the focus of TextInput to be dismissed
                _isOverlayVisible = false;
              },
            ));
          }
        }
      }
    }
    // Update the results count to recalculate height
    if (_filteredResultsCount != results.length) {
      // Use Future.microtask to ensure we're not rebuilding during build
      Future.microtask(() {
        if (mounted) {
          setState(() {
            _filteredResultsCount = results.length;
          });
        }
      });
    }
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) => results[index],
    );
  }

  Debouncer? _delayedKeyPressDebouncer;
  Duration? _lastDelayedKeyPressDuration;

  Debouncer getKeyPressDebouncer() {
    return InputFieldHelper.getKeyPressDebouncer(
        _delayedKeyPressDebouncer,
        _lastDelayedKeyPressDuration,
        widget._controller.delayedKeyPressDuration);
  }

  @override
  void focusInputField() {
    if (!focusNode.hasFocus) {
      focusNode.requestFocus();
    }
  }

  @override
  void unfocusInputField() {
    if (focusNode.hasFocus) {
      focusNode.unfocus();
    }
  }
}
