import 'dart:developer';

import 'package:ensemble/ensemble_theme.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/theme/theme_manager.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/framework/widget/icon.dart' as framework;
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/layout/form.dart';
import 'package:ensemble/model/item_template.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/debouncer.dart';
import 'package:ensemble/util/input_formatter.dart';
import 'package:ensemble/util/input_validator.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/HasTextPlaceholder.dart';
import 'package:ensemble/widget/helpers/form_helper.dart';
import 'package:ensemble/widget/helpers/input_wrapper.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:ensemble_ts_interpreter/invokables/invokablecontroller.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ensemble/layout/templated.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:email_validator/email_validator.dart';
import 'package:ensemble/framework/model.dart' as model;
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:form_validator/form_validator.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:fluttertagger/fluttertagger.dart';

/// TextInput
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
      'obscureText': (obscure) =>
          _controller.obscureText = Utils.optionalBool(obscure),
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
  bool isPassword() {
    return false;
  }

  @override
  TextInputType? get keyboardType {
    // set the best keyboard type based on the input type
    if (_controller.inputType == InputType.email.name) {
      return TextInputType.emailAddress;
    } else if (_controller.inputType == InputType.phone.name) {
      return TextInputType.phone;
    } else if (_controller.inputType == InputType.number.name) {
      return TextInputType.number;
    } else if (_controller.inputType == InputType.text.name) {
      return TextInputType.text;
    } else if (_controller.inputType == InputType.url.name) {
      return TextInputType.url;
    } else if (_controller.inputType == InputType.datetime.name) {
      return TextInputType.datetime;
    }
    return null;
  }
  
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
  final FlutterTaggerController _taggerController = FlutterTaggerController(
    //Initial text value with tag is formatted internally
    //following the construction of FlutterTaggerController.
    //After this controller is constructed, if you
    //wish to update its text value with raw tag string,
    //call (_controller.formatTags) after that.
    text:
        "Hey @11a27531b866ce0016f9e582#brad#. It's time to #93f27531f294jp0016f9k013#Flutter#!",
  );
  final TagInputController _controller = TagInputController();

  @override
  TagInputController get controller => _controller;

  @override
  Map<String, Function> getters() {
    var getters = _controller.textPlaceholderGetters;
    getters.addAll({
      'value': () => _taggerController.formattedText ?? '',
      'obscured': () => _controller.obscured,
    });
    return getters;
  }

  @override
  Map<String, Function> setters() {
    var setters = _controller.textPlaceholderSetters;
    // set value is not specified here for safety in case of PasswordInput
    setters.addAll({
      'validateOnUserInteraction': (value) => _controller
              .validateOnUserInteraction =
          Utils.getBool(value, fallback: _controller.validateOnUserInteraction),
      'onKeyPress': (function) => _controller.onKeyPress =
          EnsembleAction.from(function, initiator: this),
      'onChange': (definition) => _controller.onChange =
          EnsembleAction.from(definition, initiator: this),
      'onFocusReceived': (definition) => _controller.onFocusReceived =
          EnsembleAction.from(definition, initiator: this),
      'onFocusLost': (definition) => _controller.onFocusLost =
          EnsembleAction.from(definition, initiator: this),
      'validator': (value) => _controller.validator = Utils.getValidator(value),
      'enableClearText': (value) =>
          _controller.enableClearText = Utils.optionalBool(value),
      'obscureToggle': (value) =>
          _controller.obscureToggle = Utils.optionalBool(value),
      'allowMention': (value) =>
          _controller.allowMention = Utils.optionalBool(value),
      'tags': (items) => buildTagItems(items),
      'triggers': (items) => buildTagTriggers(items),
      'obscured': (widget) => _controller.obscureText == true,
      'obscureTextWidget': (widget) => _controller.obscureTextWidget = widget,
      'readOnly': (value) => _controller.readOnly = Utils.optionalBool(value),
      'selectable': (value) =>
          _controller.selectable = Utils.getBool(value, fallback: true),
      'toolbarDone': (value) =>
          _controller.toolbarDoneButton = Utils.optionalBool(value),
      'keyboardAction': (value) =>
          _controller.keyboardAction = _getKeyboardAction(value),
      'multiline': (value) => _controller.multiline = Utils.optionalBool(value),
      'minLines': (value) =>
          _controller.minLines = Utils.optionalInt(value, min: 1),
      'maxLines': (value) =>
          _controller.maxLines = Utils.optionalInt(value, min: 1),
      'overlayHeight': (value) =>
          _controller.overlayHeight = Utils.optionalDouble(value),
      'textStyle': (style) => _controller.textStyle = Utils.getTextStyle(style),
      'tagStyle': (style) => _controller.tagStyle = Utils.getTextStyle(style),
      'tagSelectionStyle': (style) =>
          _controller.tagSelectionStyle = Utils.getTextStyle(style),
      'overlayStyle': (style) =>
          _controller.overlayStyle = Utils.getBoxDecoration(style),
      'autofillHints': (value) =>
          _controller.autofillHints = Utils.getListOfStrings(value),
      'maxLength': (value) => _controller.maxLength = Utils.optionalInt(value),
      'maxLengthEnforcement': (value) =>
          _controller.maxLengthEnforcement = _getMaxLengthEnforcement(value),
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

  TextInputAction? _getKeyboardAction(dynamic value) {
    switch (value) {
      case 'done':
        return TextInputAction.done;
      case 'go':
        return TextInputAction.go;
      case 'search':
        return TextInputAction.search;
      case 'send':
        return TextInputAction.send;
      case 'next':
        return TextInputAction.next;
      case 'previous':
        return TextInputAction.previous;
    }
    return null;
  }

  List<MentionItem> buildTagItems(List<dynamic>? items) {
    List<MentionItem> results = [];

    if (items != null) {
      for (var item in items) {
        if (item is Map) {
          results.add(MentionItem(
            id: item['id']?.toString() ?? '',
            key: item['key']?.toString() ?? '',
            label: item['label'] ?? '',
            image: item['image'],
          ));
        }
        // For simple string items
        else if (item is String) {
          results
              .add(MentionItem(id: item, key: item, label: item, image: null));
        }
      }
    }
    _controller.tags = results;

    return results;
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

mixin TextInputFieldAction on FormFieldWidgetState<BaseTextInput> {
  void focusInputField();

  void unfocusInputField();
}

/// controller for both TextField and Password
class TagInputController extends FormFieldController with HasTextPlaceholder {
  TextInputFieldAction? inputFieldAction;
  EnsembleAction? onChange;
  EnsembleAction? onKeyPress;
  TextInputAction? keyboardAction;

  EnsembleAction? onDelayedKeyPress;
  Duration delayedKeyPressDuration = const Duration(milliseconds: 300);

  EnsembleAction? onFocusReceived;
  EnsembleAction? onFocusLost;
  bool? enableClearText;

  // applicable only for TextInput
  bool? obscureText;

  // applicable only for Password or obscure TextInput, to toggle between plain and secure text
  bool? obscured;
  bool? obscureToggle;
  bool? allowMention;
  List<MentionItem>? tags; // Tag items List for FlutterTagger
  late Map<String, TextStyle?> triggers; // Optional additional triggers  like #
  LabelValueItemTemplate? itemTemplate;

  // overlay styles
  BoxDecoration? overlayStyle;
  double? overlayHeight;

  dynamic obscureTextWidget;
  bool? readOnly;
  bool selectable = true;
  bool? toolbarDoneButton;

  model.InputValidator? validator;
  bool validateOnUserInteraction = false;
  String? inputType;
  String? mask;
  TextStyle? textStyle;
  TextStyle? tagStyle;
  TextStyle? tagSelectionStyle;

  bool? multiline;
  int? minLines;
  int? maxLines;
  int? maxLength;
  MaxLengthEnforcement? maxLengthEnforcement;

  List<String>? autofillHints;
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

class TriggerItem {
  final String character;
  final TextStyle? textStyle;

  TriggerItem({
    required this.character,
    this.textStyle,
  });
}

class TagInputState extends FormFieldWidgetState<BaseTextInput>
    with TickerProviderStateMixin, TextInputFieldAction, TemplatedWidgetState {
  final focusNode = FocusNode();
  List? dataList;

  // for this widget we will implement onChange if the text changes AND:
  // 1. the field loses focus next (tabbing out, ...)
  // 2. upon onEditingComplete (e.g click Done on keyboard)
  // This is so we can be consistent with the other input widgets' onChange
  String previousText = '';
  bool didItChange = false;

  // password is obscure by default
  late List<TextInputFormatter> _inputFormatter;

  late AnimationController _animationController;
  late Animation<Offset> _animation;

  OverlayEntry? overlayEntry;

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

  void showOverlay(BuildContext context) {
    if (overlayEntry != null || !toolbarDoneStatus) return;
    OverlayState overlayState = Overlay.of(context);
    overlayEntry = OverlayEntry(builder: (context) {
      return Positioned(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        right: 0.0,
        left: 0.0,
        child: const _InputDoneButton(),
      );
    });

    overlayState.insert(overlayEntry!);
  }

  void removeOverlayAndUnfocus() {
    if (overlayEntry != null) {
      overlayEntry!.remove();
      overlayEntry = null;
    }
    FocusManager.instance.primaryFocus?.unfocus();
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
    // Checking for readOnly from parent widget and assign the value to TextInput and PasswordInput if it's readOnly property is null
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
    // issue: https://github.com/EnsembleUI/ensemble/issues/1527

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

    return InputWrapper(
        type: TagInput.type,
        controller: widget._controller,
        widget: FlutterTagger(
          controller: widget._taggerController,
          animationController: _animationController,
          tagTextFormatter: (originalText, tagId, tagText) {
            // Format the tag using a custom format
            final formattedTag = '$tagText$originalText';
            return formattedTag;
          },
          onSearch: (query, triggerCharacter) async {
            final results = widget.controller.tags!
                .where((item) =>
                    item.label.toLowerCase().contains(query.toLowerCase()))
                .map(
                    (item) => item.label) // Return full titles including spaces
                .toList();
            return Future.value(results);
          },
          triggerCharacterAndStyles: const {
            "@": TextStyle(color: Colors.pinkAccent),
            "#": TextStyle(color: Colors.blueAccent),
          },
          // triggerCharacterAndStyles: widget.controller.triggers.map((key, value) => MapEntry(key, value ?? const TextStyle())),
          triggerStrategy: TriggerStrategy.eager,
          overlayHeight: widget._controller.overlayHeight ?? 200.0,
          overlay:
              Material(
                  child: SlideTransition(
            position: _animation,
            child: Container(
              decoration: widget._controller.overlayStyle,
              child: buildItems(widget.controller.tags,
                  widget.controller.itemTemplate, dataList),
            ),
          )),
          builder: (context, containerKey) {
            return TextFormField(
              key: containerKey,
              autofillHints: widget._controller.autofillHints,
              autovalidateMode: widget._controller.validateOnUserInteraction
                  ? AutovalidateMode.onUserInteraction
                  : AutovalidateMode.disabled,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return widget._controller.required
                      ? Utils.translateWithFallback(
                          'ensemble.input.required',
                          widget._controller.requiredMessage ??
                              'This field is required')
                      : null;
                }

                if (widget._controller.validator != null) {
                  ValidationBuilder? builder;
                  if (widget._controller.validator?.minLength != null) {
                    builder = ValidationBuilder().minLength(
                        widget._controller.validator!.minLength!,
                        Utils.translateOrNull(
                            'ensemble.input.validation.minimumLength'));
                  }
                  if (widget._controller.validator?.maxLength != null) {
                    builder = (builder ?? ValidationBuilder()).maxLength(
                        widget._controller.validator!.maxLength!,
                        Utils.translateOrNull(
                            'ensemble.input.validation.maximumLength'));
                  }
                  if (widget._controller.validator?.regex != null) {
                    builder = (builder ?? ValidationBuilder()).regExp(
                        RegExp(widget._controller.validator!.regex!),
                        widget._controller.validator!.regexError ??
                            Utils.translateWithFallback(
                                'ensemble.input.validation.invalidInput',
                                'This field has invalid value'));
                  }
                  if (builder != null) {
                    return builder.build().call(value);
                  }
                }
                return null;
              },
              textInputAction: widget._controller.keyboardAction,
              keyboardType: widget.keyboardType,
              inputFormatters: _inputFormatter,
              minLines: isMultiline() ? widget._controller.minLines : null,
              maxLines: isMultiline() ? widget._controller.maxLines : 1,
              maxLength: widget._controller.maxLength,
              maxLengthEnforcement: widget._controller.maxLengthEnforcement ??
                  MaxLengthEnforcement.enforced,
              enableSuggestions: true,
              autocorrect: true,
              controller: widget._taggerController,
              focusNode: focusNode,
              enabled: isEnabled(),
              readOnly: widget._controller.readOnly == true,
              enableInteractiveSelection: widget._controller.selectable,
              onTapOutside: (_) => removeOverlayAndUnfocus(),
              onFieldSubmitted: (value) {
                widget.controller.submitForm(context);
              },
              onChanged: (String txt) {
                if (txt != previousText) {
                  previousText = txt;
                  if (widget._controller.onKeyPress != null) {
                    ScreenController().executeAction(
                        context, widget._controller.onKeyPress!,
                        event: EnsembleEvent(widget));
                  }

                  if (widget._controller.onDelayedKeyPress != null) {
                    executeDelayedAction(widget._controller.onDelayedKeyPress!);
                  }
                }
                setState(() {});
              },
              style: isEnabled()
                  ? widget._controller.textStyle
                  : widget._controller.textStyle?.copyWith(
                      color: Theme.of(context).disabledColor,
                    ),
              decoration: decoration,
            );
          },
        ));
  }

  /// multi-line if specified or if maxLine is more than 1
  bool isMultiline() =>
      widget._controller.multiline ??
      (widget._controller.maxLines != null && widget._controller.maxLines! > 1);

  void _clearSelection() {
    widget._taggerController.clear();
    focusNode.unfocus();
  }

  void executeDelayedAction(EnsembleAction action) {
    getKeyPressDebouncer().run(() async {
      ScreenController()
          .executeAction(context, action, event: EnsembleEvent(widget));
    });
  }

  ListView? buildItems(List<MentionItem>? items,
      LabelValueItemTemplate? itemTemplate, List? dataList) {
    List<ListTile>? results;
    // first add the static list
    if (items != null) {
      results = [];
      for (MentionItem item in items) {
        results.add(ListTile(
          leading: item.image != null
              ? CircleAvatar(
                  backgroundImage: NetworkImage(item.image!),
                )
              : const CircleAvatar(child: Icon(Icons.person)),
          title: Text(
            item.label,
            style: widget._controller.tagSelectionStyle,
          ),
          onTap: () {
            // Use insertMention instead of addTag to ensure styles are applied
            widget._taggerController.addTag(
              id: item.id.toString(),
              name: item.key,
            );
          },
        ));
      }
    }
    // then add the templated list
    if (itemTemplate != null && dataList != null) {
      ScopeManager? parentScope = DataScopeWidget.getScope(context);
      if (parentScope != null) {
        results ??= [];
        for (var itemData in dataList) {
          ScopeManager templatedScope = parentScope.createChildScope();
          templatedScope.dataContext
              .addDataContextById(itemTemplate.name, itemData);

          var labelWidget = DataScopeWidget(
              scopeManager: templatedScope,
              child: itemTemplate.label != null
                  ? Text(templatedScope.dataContext.eval(itemTemplate.label!))
                  : templatedScope
                      .buildWidgetFromDefinition(itemTemplate.labelWidget));
          results.add(ListTile(
            title: labelWidget,
            hoverColor: Colors.pink,
            // value: templatedScope.dataContext.eval(itemTemplate.value),
            onTap: () {
              // Use insertMention instead of addTag to ensure styles are applied
              widget._taggerController.addTag(
                  id: templatedScope.dataContext.eval(itemTemplate.value),
                  name: templatedScope.dataContext.eval(itemTemplate.label));

              focusNode.requestFocus();

              // WidgetsBinding.instance.addPostFrameCallback((_) {
              //   widget._taggerController.closeOverlay();
              // });
            },
          ));
        }
      }
    }

    ListView finalList = ListView.builder(
      itemCount: results!.length,
      itemBuilder: (context, index) {
        return results![index];
      },
    );

    return finalList;
  }

  Debouncer? _delayedKeyPressDebouncer;
  Duration? _lastDelayedKeyPressDuration;

  Debouncer getKeyPressDebouncer() {
    if (_delayedKeyPressDebouncer == null) {
      _delayedKeyPressDebouncer =
          Debouncer(widget._controller.delayedKeyPressDuration);
      _lastDelayedKeyPressDuration = widget._controller.delayedKeyPressDuration;
    }
    // debouncer exists, but has the duration changed?
    else {
      // re-create if anything changed, but need to cancel first
      if (_lastDelayedKeyPressDuration!
              .compareTo(widget._controller.delayedKeyPressDuration) !=
          0) {
        _delayedKeyPressDebouncer!.cancel();
        _delayedKeyPressDebouncer =
            Debouncer(widget._controller.delayedKeyPressDuration);
        _lastDelayedKeyPressDuration =
            widget._controller.delayedKeyPressDuration;
      }
    }

    // here debouncer is valid
    return _delayedKeyPressDebouncer!;
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

enum InputType { email, phone, ipAddress, number, text, url, datetime }

class _InputDoneButton extends StatelessWidget {
  const _InputDoneButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.grey[200],
      alignment: Alignment.topRight,
      padding: const EdgeInsets.only(top: 1.0, bottom: 1.0),
      child: CupertinoButton(
        padding: const EdgeInsets.only(right: 24.0, top: 2.0, bottom: 2.0),
        onPressed: () => FocusScope.of(context).requestFocus(FocusNode()),
        child: const Text(
          'Done',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.normal),
        ),
      ),
    );
  }
}

MaxLengthEnforcement? _getMaxLengthEnforcement(String? value) {
  switch (value) {
    case 'none':
      return MaxLengthEnforcement.none;
    case 'enforced':
      return MaxLengthEnforcement.enforced;
    case 'truncateAfterCompositionEnds':
      return MaxLengthEnforcement.truncateAfterCompositionEnds;
  }
  return null;
}
