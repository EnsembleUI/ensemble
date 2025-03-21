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
import 'package:ensemble/widget/helpers/HasTextPlaceholder.dart';
import 'package:ensemble/widget/helpers/form_helper.dart';
import 'package:ensemble/widget/helpers/input_wrapper.dart';
import 'package:ensemble/widget/helpers/input_field_helper.dart'; // Import the helper class
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ensemble/layout/templated.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/services.dart';
import 'package:fluttertagger/fluttertagger.dart';

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
          _taggerController.text = '';
          return;
        }
        _taggerController.text = Utils.optionalString(newValue)!;
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

  // textController manages 'value', while _controller manages the rest
  final FlutterTaggerController _taggerController = FlutterTaggerController();
  final TagInputController _controller = TagInputController();

  @override
  TagInputController get controller => _controller;

  @override
  Map<String, Function> getters() {
    var getters = _controller.textPlaceholderGetters;
    getters.addAll({
      'value': () => _taggerController.formattedText ?? '',
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
    };
  }

  Map<String, TextStyle?> buildTagTriggers(List<dynamic>? triggers) {
    // Initialize with default @ trigger
    Map<String, TextStyle?> results = {
      '@': const TextStyle(color: Colors.blue),
    };

    if (triggers != null) {
      for (var item in triggers) {
        if (item is Map) {
          String? character = item['character']?.toString();
          if (character != null) {
            // Parse the tagStyle map to create TextStyle
            if (item['tagStyle'] is Map) {
              results[character] = Utils.getTextStyle(item['tagStyle']);
            }
          }
        }
      }
    }

    _controller.triggers = results;

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
class TagInputController extends BaseInputController with HasTextPlaceholder {
  // TextInputFieldAction? inputFieldAction;

  late Map<String, TextStyle?> triggers; // Optional additional triggers like #
  LabelValueItemTemplate? itemTemplate;
  TextStyle? mentionStyle;

  EnsembleAction? onSearch;

  // overlay styles
  BoxDecoration? overlayStyle;
  double? maxOverlayHeight;
  double? minOverlayHeight;

  TextStyle? tagStyle;
  TextStyle? tagSelectionStyle;
}

class MentionItem {
  final String id;
  final String key;
  final String label;
  final String? image;

  MentionItem({
    required this.id,
    required this.key,
    required this.label,
    this.image,
  });
}

class TagInputState extends FormFieldWidgetState<BaseTextInput>
    with TickerProviderStateMixin, TextInputFieldAction, TemplatedWidgetState {
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

  late List<TextInputFormatter> _inputFormatter;
  late AnimationController _animationController;
  late Animation<Offset> _animation;

  bool get toolbarDoneStatus {
    return widget.controller.toolbarDoneButton ?? false;
  }

  void evaluateChanges() {
    if (didItChange) {
      // trigger binding
      widget.setProperty('value', widget._taggerController.text);

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
      widget._taggerController.dismissOverlay();
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  @override
  void initState() {
    _inputFormatter = InputFormatter.getFormatter(
        widget._controller.inputType, widget._controller.mask);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _animation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
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
    // Check for readOnly from parent widget
    if (widget._controller.readOnly == null) {
      final formController =
          context.findAncestorWidgetOfExactType<EnsembleForm>()?.controller;

      if (formController != null) {
        widget._controller.readOnly = formController.readOnly == true;
      }
    }

    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.controller.inputFieldAction = this;

    if (widget._controller.itemTemplate != null) {
      registerItemTemplate(context, widget._controller.itemTemplate!,
          onDataChanged: (data) {
        setState(() {
          dataList = data;
        });
      });
    }
  }

  @override
  void didUpdateWidget(covariant BaseTextInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.controller.inputFieldAction = this;

    // Making sure to move cursor to end when widget rebuild
    if (focusNode.hasFocus) {
      int oldCursorPosition = oldWidget._taggerController.selection.baseOffset;
      int textLength = widget._taggerController.text.length;

      widget._taggerController.selection = TextSelection.fromPosition(
        TextPosition(offset: oldCursorPosition),
      );
      int cursorPosition = widget._taggerController.selection.baseOffset;

      if (textLength > cursorPosition) {
        widget._taggerController.selection = TextSelection.fromPosition(
          TextPosition(offset: textLength),
        );
      }
    }
  }

  @override
  void dispose() {
    focusNode.dispose();
    _animationController.dispose();
    widget._taggerController.dispose();
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
    InputDecoration decoration = inputDecoration;
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

    if (widget._taggerController.text.isNotEmpty &&
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
        widget: FlutterTagger(
          controller: widget._taggerController,
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
                event: EnsembleEvent(widget, data: {'query': query}),
              );
            }
            setState(() {
              tagQuery = query;
            });
          },
          triggerCharacterAndStyles: {
            ...widget.controller.triggers
                .map((key, value) => MapEntry(key, value!)),
            "@": widget._controller.mentionStyle!,
          },
          triggerStrategy: TriggerStrategy.eager,
          overlayHeight: _calculatedOverlayHeight,
          overlay: Material(
              child: SlideTransition(
            position: _animation,
            child: Container(
              decoration: widget._controller.overlayStyle,
              child: buildItems(
                  widget.controller.itemTemplate, dataList, tagQuery),
            ),
          )),
          builder: (context, containerKey) {
            // Use the helper to create a TextFormField with common configuration
            return InputFieldHelper.createTextFormField(
              key: containerKey,
              autofillHints: widget._controller.autofillHints,
              controller: widget._taggerController,
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
                  didItChange = false;

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
    if (message[message.length - 1] == " ") {
      return false;
    }
    // Trim any spaces at the end
    message = message.trim();

    // Split the message into words
    List<String> words = message.split(" ");

    // Check if the last word exists and starts with '@'
    if (words.isNotEmpty &&
        (words.last.startsWith("@") ||
            widget._controller.triggers.entries
                .any((trigger) => words.last.startsWith(trigger.key)))) {
      return true; // It is a tag
    }
    return false; // Not a tag
  }

  /// multi-line if specified or if maxLine is more than 1
  bool isMultiline() => InputFieldHelper.isMultiline(
      widget._controller.multiline, widget._controller.maxLines);

  void _clearSelection() {
    widget._taggerController.clear();
    focusNode.unfocus();
  }

  void executeDelayedAction(EnsembleAction action) {
    InputFieldHelper.executeDelayedAction(
        context, action, widget, getKeyPressDebouncer());
  }

  ListView? buildItems(
      LabelValueItemTemplate? itemTemplate, List? dataList, String? tagQuery) {
    List<ListTile> results = [];

    // Normalize the query
    String query = tagQuery?.toLowerCase() ?? '';

    // Filter the templated list
    if (itemTemplate != null && dataList != null) {
      ScopeManager? parentScope = DataScopeWidget.getScope(context);
      if (parentScope != null) {
        for (var itemData in dataList) {
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
              if (labelWidgetKey.currentContext != null) {
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
                widget._taggerController.addTag(
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
