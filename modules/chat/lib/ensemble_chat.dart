import 'dart:convert';

import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/ensemble_widget.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/stub/ensemble_chat.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_chat/chat_page.dart';
import 'package:ensemble_chat/helpers/openai.dart';
import 'package:flutter/material.dart';

import 'helpers/models.dart';

class EnsembleChatImpl extends EnsembleWidget<EnsembleChatController>
    implements EnsembleChat {
  const EnsembleChatImpl._(super.controller);

  factory EnsembleChatImpl.build(dynamic controller) => EnsembleChatImpl._(
        controller is EnsembleChatController
            ? controller
            : EnsembleChatController(),
      );

  @override
  State<StatefulWidget> createState() => EnsembleChatState();
}

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
      widget.controller.isLoading.value = true;
      try {
        final response = await widget.controller.client?.complete(newMessage);
        if (response == null) return;
        final choice = response.choices.firstOrNull;
        handleMessageIntent(choice);
      } on Exception catch (e) {
        print("EnsembleChat: $e");
      } finally {
        widget.controller.isLoading.value = false;
      }
    }
    final scope = getScopeManager();
    final newScope = scope?.createChildScope();
    if (newScope == null || widget.controller.onMessageSend == null) {
      return;
    }
    newScope.dataContext.addDataContextById('message', newMessage);
    if (!mounted) return;

    ScreenController().executeActionWithScope(
        context, newScope, widget.controller.onMessageSend!);
  }

  void handleMessageIntent(Choice? choice) {
    switch (choice?.messageType) {
      case MessageType.message:
        widget.controller.addMessage({
          widget.controller.getMessageKey: choice?.getMessage,
          "role": MessageRole.assistant.name,
          "choice": choice?.toMap(),
        });
        break;

      case MessageType.inlineWidget:
        final inLineWidget = choice?.inlineWidget;
        if (!mounted) return;
        widget.controller.addMessage({
          widget.controller.getInlineKey: inLineWidget,
          "widget": buildWidgetsFromTemplate(context, inLineWidget),
          "role": MessageRole.assistant.name,
          "choice": choice?.toMap(),
        });

      case MessageType.action:
        if (!mounted) return;
        widget.controller.addMessage({
          widget.controller.getMessageKey:
              "Executing action: ${choice?.tool['function']['name']}",
          "role": MessageRole.system.name,
          "choice": choice?.toMap(),
        });

        final action = EnsembleAction.from(choice?.tool['function']['tool']);
        if (action == null) return;
        ScreenController().executeAction(context, action);
      default:
    }
  }
}

class EnsembleChatController extends EnsembleBoxController {
  User? user;
  dynamic initialMessage;
  EnsembleAction? onMessageSend;
  ValueNotifier<List<InternalMessage>> messages = ValueNotifier([]);

  String? inlineWidgetKey;
  String? messageKey;

  Map<String, dynamic>? config;
  ChatType type = ChatType.local;

  Color? backgroundColor;
  Color? textFieldBackgroundColor;
  Color? iconColor;
  TextStyle? textFieldTextStyle;

  BubbleStyleComposite? _userBubbleStyle;
  BubbleStyleComposite get userBubbleStyle =>
      _userBubbleStyle ??= BubbleStyleComposite(this);
  set userBubbleStyle(BubbleStyleComposite value) => _userBubbleStyle = value;

  BubbleStyleComposite? _assistantBubbleStyle;
  BubbleStyleComposite get assistantBubbleStyle =>
      _assistantBubbleStyle ??= BubbleStyleComposite(this);
  set assistantBubbleStyle(BubbleStyleComposite value) =>
      _assistantBubbleStyle = value;

  Future<void> Function(String newMessage, {bool visible})? sendMessage;

  bool get isLocalChat => type == ChatType.local;

  AIClient? client;

  bool showLoading = true;
  dynamic loadingWidget;
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
        final msg = Utils.optionalString(message);
        final visible = Utils.getBool(options?['visible'], fallback: true);
        if (msg == null) return;
        sendMessage?.call(msg, visible: visible);
      },
      'getMessages': () => messages.value.map((e) => e.toMap()).toList(),
    };
  }

  List<InternalMessage> getMessages() => messages.value;

  addMessage(message) {
    if (message is String) {
      final rawMessage = Utils.optionalString(message);
      if (rawMessage == null) return;
      final data = jsonDecode(rawMessage);
      messages.value.add(data);
    }
    if (message is Map) {
      messages.value.add(InternalMessage.fromMap(message, this));
    }
    messages.notifyListeners();
  }

  String get getMessageKey => messageKey ?? 'content';

  String get getInlineKey => inlineWidgetKey ?? 'widget';

  @override
  Map<String, Function> setters() {
    return {
      'initialMessages': (value) {
        if (value is! List || messages.value.isNotEmpty) return;
        messages.value.addAll(value.map((data) {
          final message = InternalMessage.fromMap(data, this);
          return message;
        }));
        messages.notifyListeners();
      },
      "onMessageSend": (value) => onMessageSend = EnsembleAction.from(value),
      "inlineWidgetKey": (value) =>
          inlineWidgetKey = Utils.optionalString(value),
      "messageKey": (value) => messageKey = Utils.optionalString(value),
      "config": (value) {
        config = Utils.getMap(value);
        if (config == null) return null;
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
    final model = config['model'] ?? 'gpt-3.5-turbo';
    final apiKey = config['apiKey'];

    if (apiKey == null) {
      throw LanguageError("EnsembleChat: apiKey is required");
    }

    final temperature = config['temperature'] ?? 1.0;
    final systemPrompt =
        config['systemPrompt'] ?? 'You are a helpful assistant';
    final tools = _getTools(config['inlineWidgets'], "inlineWidget");
    final actionTools = _getTools(config['actions'], "action");
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
    if (config == null) return null;

    List<Map<String, dynamic>> tools = [];

    getFunction(dynamic tool) {
      Map<String, dynamic> toolMap = {};
      for (var key in tool.keys) {
        final properties = {};
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

    for (var c in config) {
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

enum ChatType { local, server }

class InternalMessage {
  late String id;
  String? content;
  dynamic inlineWidget;
  late DateTime createdAt;
  dynamic payload;
  Widget? widget;
  MessageRole role;
  dynamic rawResponse;
  final bool visible;

  InternalMessage({
    this.content,
    this.inlineWidget,
    required this.role,
    this.visible = true,
  })  : id = Utils.generateRandomId(8),
        createdAt = DateTime.now();

  static InternalMessage fromMap(Map data, dynamic controller) {
    final roleData = data.getOrNull("role");
    final role =
        MessageRole.values.firstWhere((element) => element.name == roleData);
    final message = InternalMessage(
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

  Map toMap() {
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

extension MapEnhance on Map {
  getOrNull(key) {
    if (containsKey(key)) {
      return this[key];
    }
    return null;
  }
}

enum MessageRole { user, assistant, system }
