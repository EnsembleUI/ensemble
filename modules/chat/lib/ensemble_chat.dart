/// Ensemble chat widget implementation and controller.
library ensemble_chat;

import 'dart:convert';

import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/ensemble_widget.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/stub/ensemble_chat.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_chat/chat_page.dart';
import 'package:ensemble_chat/helpers/openai.dart';
import 'package:flutter/material.dart';

import 'helpers/models.dart';

/// Ensemble widget implementation for chat experiences.
class EnsembleChatImpl extends EnsembleWidget<EnsembleChatController>
    implements EnsembleChat {
  /// Creates an Ensemble chat widget with an existing controller.
  const EnsembleChatImpl._(super.controller);

  /// Builds an [EnsembleChatImpl] from an Ensemble controller payload.
  factory EnsembleChatImpl.build(dynamic controller) => EnsembleChatImpl._(
        controller is EnsembleChatController
            ? controller
            : EnsembleChatController(),
      );

  @override
  State<StatefulWidget> createState() => EnsembleChatState();
}

/// State object for [EnsembleChatImpl].
class EnsembleChatState extends EnsembleWidgetState<EnsembleChatImpl> {
  @override
  void initState() {
    widget.controller.sendMessage = sendMessage;
    super.initState();
  }

  @override
  void dispose() {
    for (var message in widget.controller.messages.value) {
      message.widget = null;
    }
    super.dispose();
  }

  @override
  Widget buildWidget(BuildContext context) {
    return ValueListenableBuilder<List<InternalMessage>>(
      valueListenable: widget.controller.messages,
      builder: (context, messages, child) {
        return ChatPage(
          messages: messages.map((message) {
            if (message.inlineWidget != null && message.widget == null) {
              message.widget =
                  buildWidgetsFromTemplate(context, message.inlineWidget);
            }
            return message;
          }).toList(),
          onMessageSend: sendMessage,
          controller: widget.controller,
        );
      },
    );
  }

  Future<void> sendMessage(String newMessage, {bool visible = true}) async {
    if (widget.controller.isLocalChat) {
      widget.controller.addMessage({
        widget.controller.getMessageKey: newMessage,
        "role": MessageRole.user.name,
        "visible": visible,
      });

      // Execute onMessageSend first
      final ScopeManager? scope = getScopeManager();
      final ScopeManager? newScope = scope?.createChildScope();
      if (newScope != null &&
          widget.controller.onMessageSend != null &&
          mounted) {
        newScope.dataContext.addDataContextById('message', newMessage);
        await ScreenController().executeActionWithScope(
            context, newScope, widget.controller.onMessageSend!);
      }

      widget.controller.isLoading.value = true;
      try {
        final Completion? response =
            await widget.controller.client?.complete(newMessage);
        if (response == null) {
          return;
        }
        final Choice? choice = response.choices.firstOrNull;
        handleMessageIntent(choice);
      } on Exception catch (e) {
        print("EnsembleChat: $e");
      } finally {
        widget.controller.isLoading.value = false;
      }
    } else {
      final ScopeManager? scope = getScopeManager();
      final ScopeManager? newScope = scope?.createChildScope();
      if (newScope == null || widget.controller.onMessageSend == null) {
        return;
      }
      newScope.dataContext.addDataContextById('message', newMessage);
      if (!mounted) {
        return;
      }

      ScreenController().executeActionWithScope(
          context, newScope, widget.controller.onMessageSend!);
    }
  }

  /// Handles an AI completion choice returned by the configured client.
  void handleMessageIntent(Choice? choice) {
    switch (choice?.messageType) {
      case MessageType.message:
        widget.controller.addMessage({
          widget.controller.getMessageKey: choice?.getMessage,
          "role": MessageRole.assistant.name,
          "choice": choice?.toMap(),
        });
        _dispatchMessageReceived(
            choice?.getMessage, MessageRole.assistant.name, choice);
        break;

      case MessageType.inlineWidget:
        final Map? inLineWidget = choice?.inlineWidget;
        if (!mounted) {
          return;
        }
        widget.controller.addMessage({
          widget.controller.getInlineKey: inLineWidget,
          "widget": buildWidgetsFromTemplate(context, inLineWidget),
          "role": MessageRole.assistant.name,
          "choice": choice?.toMap(),
        });
        _dispatchMessageReceived(choice?.tool['function']['name'],
            MessageRole.assistant.name, choice);

      case MessageType.action:
        if (!mounted) {
          return;
        }
        widget.controller.addMessage({
          widget.controller.getMessageKey:
              "Executing action: ${choice?.tool['function']['name']}",
          "role": MessageRole.system.name,
          "choice": choice?.toMap(),
        });
        _dispatchMessageReceived(
            choice?.tool['function']['name'], MessageRole.system.name, choice);

        final EnsembleAction? action =
            EnsembleAction.from(choice?.tool['function']['tool']);
        if (action == null) {
          return;
        }
        ScreenController().executeAction(context, action);
      default:
    }
  }

  void _dispatchMessageReceived(dynamic content, String role, Choice? choice) {
    if (!mounted || widget.controller.onMessageReceived == null) {
      return;
    }

    ScreenController().executeAction(
        context, widget.controller.onMessageReceived!,
        event: EnsembleEvent(widget.controller, data: {
          'content': content,
          'role': role,
          'response': choice?.toMap()
        }));
  }
}

/// Controller for Ensemble chat widget configuration and state.
class EnsembleChatController extends EnsembleBoxController {
  /// Current chat user.
  User? user;

  /// Initial message payload passed from Ensemble.
  dynamic initialMessage;

  /// Action invoked when a user sends a message.
  EnsembleAction? onMessageSend;

  /// Action invoked when a response message is received.
  EnsembleAction? onMessageReceived;

  /// Conversation messages.
  ValueNotifier<List<InternalMessage>> messages = ValueNotifier([]);

  /// Payload key used to read inline widget definitions.
  String? inlineWidgetKey;

  /// Payload key used to read message text.
  String? messageKey;

  /// Raw chat configuration.
  Map<String, dynamic>? config;

  /// Chat execution mode.
  ChatType type = ChatType.local;

  /// Chat page background color.
  Color? backgroundColor;

  /// Composer text-field background color.
  Color? textFieldBackgroundColor;

  /// Send icon color.
  Color? iconColor;

  /// Composer text style.
  TextStyle? textFieldTextStyle;

  BubbleStyleComposite? _userBubbleStyle;

  /// Bubble style used for user messages.
  BubbleStyleComposite get userBubbleStyle =>
      _userBubbleStyle ??= BubbleStyleComposite(this);

  /// Updates the bubble style used for user messages.
  set userBubbleStyle(BubbleStyleComposite value) => _userBubbleStyle = value;

  BubbleStyleComposite? _assistantBubbleStyle;

  /// Bubble style used for assistant and system messages.
  BubbleStyleComposite get assistantBubbleStyle =>
      _assistantBubbleStyle ??= BubbleStyleComposite(this);

  /// Updates the bubble style used for assistant and system messages.
  set assistantBubbleStyle(BubbleStyleComposite value) =>
      _assistantBubbleStyle = value;

  /// Function used to send a message from external callers.
  Future<void> Function(String newMessage, {bool visible})? sendMessage;

  /// Whether this chat should call the local AI client.
  bool get isLocalChat => type == ChatType.local;

  /// AI client used for local chat mode.
  AIClient? client;

  /// Whether to show the loading indicator while awaiting a response.
  bool showLoading = true;

  /// Optional custom loading widget definition.
  dynamic loadingWidget;

  /// Loading state notifier.
  ValueNotifier<bool> isLoading = ValueNotifier(false);

  @override
  Map<String, Function> getters() {
    return {};
  }

  @override
  Map<String, Function> methods() {
    return {
      'addMessage': addMessage,
      'sendMessage': (String message, [Map<dynamic, dynamic>? options]) {
        final String? msg = Utils.optionalString(message);
        final bool visible = Utils.getBool(options?['visible'], fallback: true);
        if (msg == null) {
          return;
        }
        sendMessage?.call(msg, visible: visible);
      },
      'getMessages': () => messages.value.map((e) => e.toMap()).toList(),
    };
  }

  /// Returns the current messages.
  List<InternalMessage> getMessages() => messages.value;

  /// Adds a message from a string or map payload.
  void addMessage(dynamic message) {
    if (message is String) {
      final String? rawMessage = Utils.optionalString(message);
      if (rawMessage == null) {
        return;
      }
      final dynamic data = jsonDecode(rawMessage);
      messages.value.add(data);
    }
    if (message is Map) {
      messages.value.add(InternalMessage.fromMap(message, this));
    }
    messages.notifyListeners();
  }

  /// Payload key used for message text.
  String get getMessageKey => messageKey ?? 'content';

  /// Payload key used for inline widget content.
  String get getInlineKey => inlineWidgetKey ?? 'widget';

  @override
  Map<String, Function> setters() {
    return {
      'initialMessages': (value) {
        if (value is! List || messages.value.isNotEmpty) {
          return;
        }
        messages.value.addAll(value.map((data) {
          final InternalMessage message = InternalMessage.fromMap(data, this);
          return message;
        }));
        messages.notifyListeners();
      },
      "onMessageSend": (value) => onMessageSend = EnsembleAction.from(value),
      "onMessageReceived": (value) =>
          onMessageReceived = EnsembleAction.from(value),
      "inlineWidgetKey": (value) =>
          inlineWidgetKey = Utils.optionalString(value),
      "messageKey": (value) => messageKey = Utils.optionalString(value),
      "config": (value) {
        config = Utils.getMap(value);
        if (config == null) {
          return null;
        }
        _createClient(config!);
      },
      "type": (value) =>
          type = ChatType.values.from(value ?? 'local') ?? ChatType.local,
      'backgroundColor': (value) => backgroundColor = Utils.getColor(value),
      'padding': (value) =>
          padding = Utils.getInsets(value, fallback: const EdgeInsets.all(0)),
      'textFieldBackgroundColor': (value) =>
          textFieldBackgroundColor = Utils.getColor(value),
      'textFieldTextStyle': (value) =>
          textFieldTextStyle = Utils.getTextStyle(value),
      'iconColor': (value) => iconColor = Utils.getColor(value),
      'userBubbleStyle': (value) =>
          userBubbleStyle = BubbleStyleComposite.from(this, value),
      'assistantBubbleStyle': (value) =>
          assistantBubbleStyle = BubbleStyleComposite.from(this, value),
      'showLoading': (value) =>
          showLoading = Utils.getBool(value, fallback: true),
      'loadingWidget': (widget) => loadingWidget = widget,
    };
  }

  void _createClient(Map<String, dynamic> config) {
    final String model = config['model'] ?? 'gpt-3.5-turbo';
    final String? apiKey = config['apiKey'];

    if (apiKey == null) {
      throw LanguageError("EnsembleChat: apiKey is required");
    }

    final double temperature = config['temperature'] ?? 1.0;
    final String systemPrompt =
        config['systemPrompt'] ?? 'You are a helpful assistant';
    final List<Map<String, dynamic>>? tools =
        _getTools(config['inlineWidgets'], "inlineWidget");
    final List<Map<String, dynamic>>? actionTools =
        _getTools(config['actions'], "action");
    tools?.addAll(actionTools ?? []);

    client = OpenAIClient(
      model: model,
      apiKey: apiKey,
      temperature: temperature,
      systemPrompt: systemPrompt,
      tools: tools,
      getMessages: getMessages,
    );
  }

  List<Map<String, dynamic>>? _getTools(dynamic config, String toolType) {
    if (config == null) {
      return null;
    }

    final List<Map<String, dynamic>> tools = <Map<String, dynamic>>[];

    Map<String, dynamic> getFunction(dynamic tool) {
      final Map<String, dynamic> toolMap = <String, dynamic>{};
      for (final dynamic key in tool.keys) {
        final Map<dynamic, dynamic> properties = <dynamic, dynamic>{};
        tool[key]["inputs"]?.keys.forEach((inpKey) {
          properties[inpKey] = {"type": tool[key]["inputs"][inpKey]};
        });

        toolMap["name"] = key;
        toolMap["description"] = tool[key]["description"];
        toolMap["parameters"] = properties.isNotEmpty
            ? {
                "type": "object",
                "properties": properties,
                "required": tool[key]["inputs"].keys.toList()
              }
            : {};
      }
      toolMap['toolType'] = toolType;
      toolMap['tool'] = tool;
      return toolMap;
    }

    for (final dynamic c in config) {
      tools.add(
        {
          "type": "function",
          "function": getFunction(c),
        },
      );
    }
    return tools;
  }
}

/// Chat mode for the Ensemble chat widget.
enum ChatType { local, server }

/// Internal message model rendered by the chat widget.
class InternalMessage {
  /// Unique message identifier.
  late String id;

  /// Text content for this message.
  String? content;

  /// Inline widget definition for this message.
  dynamic inlineWidget;

  /// Creation timestamp.
  late DateTime createdAt;

  /// Raw message payload.
  dynamic payload;

  /// Built inline widget instance.
  Widget? widget;

  /// Role used to render this message.
  MessageRole role;

  /// Raw AI response payload.
  dynamic rawResponse;

  /// Whether this message should be visible in the chat UI.
  final bool visible;

  /// Creates an internal chat message.
  InternalMessage({
    this.content,
    this.inlineWidget,
    required this.role,
    this.visible = true,
  })  : id = Utils.generateRandomId(8),
        createdAt = DateTime.now();

  /// Creates an [InternalMessage] from an Ensemble payload.
  static InternalMessage fromMap(Map data, dynamic controller) {
    final dynamic roleData = data.getOrNull("role");
    final MessageRole role =
        MessageRole.values.firstWhere((element) => element.name == roleData);
    final InternalMessage message = InternalMessage(
      role: role,
      visible: data['visible'] ?? true,
    );

    message.content = data.getOrNull(controller.getMessageKey);
    message.inlineWidget = data.getOrNull(controller.getInlineKey);
    message.widget = data['widget'];
    message.rawResponse = data['choice'];
    message.payload = data;

    return message;
  }

  /// Converts this message to map data.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'inlineWidget': inlineWidget,
      'createdAt': createdAt,
      'payload': payload,
      'role': role.name,
      'visible': visible,
    };
  }
}

/// Convenience helpers for map payload reads.
extension MapEnhance on Map {
  /// Returns a value for [key], or `null` when the key is missing.
  dynamic getOrNull(dynamic key) {
    if (containsKey(key)) {
      return this[key];
    }
    return null;
  }
}

/// Role used to style and process chat messages.
enum MessageRole { user, assistant, system }
