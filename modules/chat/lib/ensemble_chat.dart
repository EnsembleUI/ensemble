/// Ensemble chat widget implementation and controller.
library ensemble_chat;

import 'dart:async';
import 'dart:convert';

import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/ensemble_widget.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/stub/ensemble_chat.dart';
import 'package:ensemble/framework/tool_response.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_chat/chat_page.dart';
import 'package:ensemble_chat/helpers/openai.dart';
import 'package:flutter/material.dart';

import 'helpers/models.dart';
import 'helpers/chat_tools.dart';

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
    widget.controller.activeState = this;
    widget.controller.sendMessage = sendMessage;
    widget.controller.canSendMessage.value =
        !widget.controller.conversationRunning;
    super.initState();
  }

  @override
  void dispose() {
    if (identical(widget.controller.activeState, this)) {
      widget.controller.activeState = null;
      widget.controller.sendMessage = null;
    }
    for (var message in widget.controller.messages.value) {
      message.widget = null;
    }
    super.dispose();
  }

  @override
  Widget buildWidget(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.controller.canSendMessage,
      builder: (context, canSendMessage, child) => ValueListenableBuilder<bool>(
        valueListenable: widget.controller.isLoading,
        builder: (context, isLoading, child) =>
            ValueListenableBuilder<List<InternalMessage>>(
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
        ),
      ),
    );
  }

  Future<void> sendMessage(String newMessage, {bool visible = true}) async {
    if (widget.controller.isLocalChat) {
      if (widget.controller.conversationRunning) return;
      widget.controller.conversationRunning = true;
      widget.controller.canSendMessage.value = false;
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
        await _runLocalConversation();
      } on Exception catch (e) {
        print("EnsembleChat: $e");
      } finally {
        widget.controller.isLoading.value = false;
        widget.controller.conversationRunning = false;
        widget.controller.canSendMessage.value = true;
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

  Future<void> _runLocalConversation() async {
    for (var step = 0; step < widget.controller.maxToolSteps; step++) {
      final response = await widget.controller.client?.complete('');
      final choice = response?.choices.firstOrNull;
      if (choice == null) return;

      final toolCalls = choice.toolCalls;
      if (toolCalls.isEmpty) {
        handleMessageIntent(choice);
        return;
      }

      final protocolMessage = InternalMessage(
        content: choice.getMessage,
        role: MessageRole.assistant,
        visible: choice.getMessage?.trim().isNotEmpty == true,
      )..rawResponse = choice.toMap();
      widget.controller.addInternalMessage(protocolMessage);

      var shouldContinue = false;
      final executor = widget.controller.activeState ?? this;
      for (final call in toolCalls) {
        final definition = widget.controller.toolDefinitions[call.name];
        if (definition == null) {
          protocolMessage.toolResults.add(ChatToolResult(
            callId: call.id,
            name: call.name,
            status: 'error',
            error: {
              'code': 'unknown_tool',
              'message': "Tool '${call.name}' is not registered."
            },
          ));
          shouldContinue = true;
          continue;
        }

        Map<String, dynamic> inputs;
        try {
          inputs = definition.prepareInputs(call.inputs);
        } on FormatException catch (error) {
          protocolMessage.toolResults.add(ChatToolResult(
            callId: call.id,
            name: call.name,
            status: 'error',
            error: {
              'code': 'invalid_tool_inputs',
              'message': error.message,
            },
          ));
          shouldContinue = true;
          continue;
        }

        switch (definition.kind) {
          case ChatToolKind.inlineWidget:
            final inlineWidget = {call.name: jsonEncode(inputs)};
            widget.controller.addMessage({
              widget.controller.getInlineKey: inlineWidget,
              'role': MessageRole.assistant.name,
            });
            protocolMessage.toolResults.add(ChatToolResult(
              callId: call.id,
              name: call.name,
              status: 'success',
              data: {'rendered': true},
            ));
            _dispatchMessageReceived(
                call.name, MessageRole.assistant.name, choice);
            break;
          case ChatToolKind.legacyAction:
            await executor._executeLegacyAction(definition, call, inputs);
            protocolMessage.toolResults.add(ChatToolResult(
              callId: call.id,
              name: call.name,
              status: 'success',
              data: {'executed': true},
            ));
            break;
          case ChatToolKind.appTool:
            protocolMessage.toolResults
                .add(await executor._executeAppTool(definition, call, inputs));
            shouldContinue = true;
            break;
        }
      }

      if (!shouldContinue) return;
    }
    throw Exception(
        'The chat exceeded the maximum number of tool steps (${widget.controller.maxToolSteps}).');
  }

  Future<void> _executeLegacyAction(ChatToolDefinition definition,
      ChatToolCall call, Map<String, dynamic> inputs) async {
    final scope = getScopeManager()?.createChildScope();
    if (scope == null || definition.action == null || !mounted) return;
    scope.dataContext.addInvokableContext(
      'tool',
      EnsembleToolCallContext(callId: call.id, name: call.name, inputs: inputs),
    );
    await ScreenController()
        .executeActionWithScope(context, scope, definition.action!);
  }

  Future<ChatToolResult> _executeAppTool(ChatToolDefinition definition,
      ChatToolCall call, Map<String, dynamic> inputs) async {
    final toolContext = EnsembleToolCallContext(
        callId: call.id, name: call.name, inputs: inputs);
    final confirmation = definition.confirmation;
    final access = Utils.optionalString(definition.options['access']);
    final needsConfirmation = confirmation == true ||
        confirmation is Map ||
        ((access == 'write' || access == 'destructive') &&
            confirmation != false);

    if (needsConfirmation) {
      EnsembleToolResponse decision;
      try {
        decision = await _requestToolConfirmation(
            definition, toolContext, confirmation);
      } catch (error) {
        return ChatToolResult(
          callId: call.id,
          name: call.name,
          status: 'error',
          error: {
            'code': error is TimeoutException
                ? 'tool_confirmation_timeout'
                : 'tool_confirmation_failed',
            'message': error.toString(),
            'retryable': error is TimeoutException,
          },
        );
      }
      if (decision.status == 'success' ||
          decision.status == 'error' ||
          decision.status == 'cancelled') {
        return ChatToolResult(
          callId: call.id,
          name: call.name,
          status: decision.status,
          data: decision.data,
          error: decision.error,
        );
      }
      if (decision.status != 'approved') {
        return ChatToolResult(
          callId: call.id,
          name: call.name,
          status: 'error',
          error: {
            'code': 'invalid_confirmation_result',
            'message':
                "Confirmation for '${call.name}' returned an unsupported status."
          },
        );
      }
    }

    final scope = getScopeManager()?.createChildScope();
    if (scope == null || definition.action == null || !mounted) {
      return ChatToolResult(
        callId: call.id,
        name: call.name,
        status: 'error',
        error: {
          'code': 'tool_scope_unavailable',
          'message': 'The tool could not access the current application scope.'
        },
      );
    }
    scope.dataContext.addInvokableContext('tool', toolContext);

    try {
      final responseFuture = widget.controller.waitForToolResponse(call.id);
      await ScreenController()
          .executeActionWithScope(context, scope, definition.action!);
      final response = await responseFuture
          .timeout(Duration(seconds: definition.timeoutSeconds));
      if (response.status != 'success' &&
          response.status != 'error' &&
          response.status != 'cancelled') {
        throw LanguageError(
            "Tool '${call.name}' must finish with success, error, or cancelled.");
      }
      return ChatToolResult(
        callId: call.id,
        name: call.name,
        status: response.status,
        data: response.data,
        error: response.error,
      );
    } catch (error) {
      final response = EnsembleToolResponse(
        callId: call.id,
        status: 'error',
        error: {
          'code': error is TimeoutException
              ? 'tool_timeout'
              : 'tool_execution_failed',
          'message': error.toString(),
          'retryable': error is TimeoutException,
        },
      );
      return ChatToolResult(
        callId: call.id,
        name: call.name,
        status: 'error',
        error: response.error,
      );
    } finally {
      widget.controller.removePendingToolResponse(call.id);
    }
  }

  Future<EnsembleToolResponse> _requestToolConfirmation(
      ChatToolDefinition definition,
      EnsembleToolCallContext toolContext,
      dynamic confirmation) async {
    final confirmationMap = Utils.getMap(confirmation);
    final widgetName = Utils.optionalString(confirmationMap?['widget']);
    if (widgetName != null) {
      // The model is no longer loading while an interactive confirmation is
      // waiting for the user. Loading resumes after the decision so the next
      // tool/model step can still show progress.
      widget.controller.isLoading.value = false;
      final responseFuture = widget.controller.waitForToolResponse(
        toolContext.callId,
      );
      final message = InternalMessage(
        inlineWidget: {
          widgetName: jsonEncode({'tool': toolContext.toMap()})
        },
        role: MessageRole.assistant,
      );
      widget.controller.addInternalMessage(message);
      try {
        return await responseFuture
            .timeout(Duration(seconds: definition.timeoutSeconds));
      } finally {
        widget.controller.removeMessage(message.id);
        widget.controller.removePendingToolResponse(toolContext.callId);
        widget.controller.isLoading.value = true;
      }
    }

    if (!mounted) {
      return EnsembleToolResponse(
        callId: toolContext.callId,
        status: 'cancelled',
        error: {
          'code': 'tool_confirmation_unavailable',
          'message': 'The confirmation UI is no longer available.',
          'retryable': false,
        },
      );
    }

    widget.controller.isLoading.value = false;
    final bool approved;
    try {
      approved = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Confirm action'),
              content: Text('Allow ${toolContext.name}?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Continue'),
                ),
              ],
            ),
          ) ??
          false;
    } finally {
      if (mounted) widget.controller.isLoading.value = true;
    }
    return EnsembleToolResponse(
      callId: toolContext.callId,
      status: approved ? 'approved' : 'cancelled',
    );
  }

  /// Handles an AI completion choice returned by the configured client.
  void handleMessageIntent(Choice? choice) {
    switch (choice?.messageType) {
      case MessageType.message:
        final message = choice?.getMessage;
        if (message == null || message.trim().isEmpty) {
          return;
        }
        widget.controller.addMessage({
          widget.controller.getMessageKey: message,
          "role": MessageRole.assistant.name,
          "choice": choice?.toMap(),
        });
        _dispatchMessageReceived(message, MessageRole.assistant.name, choice);
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
  @override
  List<String> passthroughSetters() => const ['tools'];

  final Map<String, Completer<EnsembleToolResponse>> _pendingToolResponses = {};

  /// Currently mounted state, used to execute a resumed tool in a valid scope.
  EnsembleChatState? activeState;

  /// Whether this controller has an unfinished local conversation turn.
  bool conversationRunning = false;

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

  /// App tool definitions kept raw until their actions are invoked.
  dynamic tools;

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

  /// Whether the composer takes focus when the chat is first shown.
  bool autoFocus = false;

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

  /// Model-callable widgets, legacy actions, and app-executed tools.
  final Map<String, ChatToolDefinition> toolDefinitions = {};

  /// Whether to show the loading indicator while awaiting a response.
  bool showLoading = true;

  /// Maximum model/tool continuation steps for one user message.
  int maxToolSteps = 8;

  /// Optional custom loading widget definition.
  dynamic loadingWidget;

  /// Loading state notifier.
  ValueNotifier<bool> isLoading = ValueNotifier(false);

  /// Whether the composer may start another conversation turn.
  ValueNotifier<bool> canSendMessage = ValueNotifier(true);

  /// Waits for an app action or confirmation widget to finish a tool call.
  Future<EnsembleToolResponse> waitForToolResponse(String callId) {
    final existing = _pendingToolResponses[callId];
    if (existing != null) return existing.future;
    final completer = Completer<EnsembleToolResponse>();
    _pendingToolResponses[callId] = completer;
    EnsembleToolResponseDispatcher.instance.register(callId, (response) {
      if (!completer.isCompleted) completer.complete(response);
    });
    return completer.future;
  }

  /// Stops routing responses for a completed or expired tool call.
  void removePendingToolResponse(String callId) {
    EnsembleToolResponseDispatcher.instance.unregister(callId);
    _pendingToolResponses.remove(callId);
  }

  /// Whether a tool call is still awaiting an app-side result.
  bool hasPendingToolResponse(String callId) =>
      _pendingToolResponses.containsKey(callId);

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

  void addInternalMessage(InternalMessage message) {
    messages.value.add(message);
    messages.notifyListeners();
  }

  void removeMessage(String id) {
    messages.value.removeWhere((message) => message.id == id);
    messages.notifyListeners();
  }

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
      "tools": (value) {
        tools = value;
        if (config != null) {
          _createClient(config!);
        }
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
      'autoFocus': (value) => autoFocus = Utils.getBool(value, fallback: false),
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
    final String? reasoningEffort = Utils.optionalString(
        config['reasoningEffort'] ?? config['reasoning_effort']);
    final String systemPrompt =
        config['systemPrompt'] ?? 'You are a helpful assistant';
    final configuredMaxSteps = config['maxToolSteps'];
    maxToolSteps = configuredMaxSteps is num && configuredMaxSteps > 0
        ? configuredMaxSteps.toInt()
        : 8;
    toolDefinitions.clear();
    _parseLegacyTools(config['inlineWidgets'], ChatToolKind.inlineWidget);
    _parseLegacyTools(config['actions'], ChatToolKind.legacyAction);
    _parseAppTools(config['tools']);
    _parseAppTools(tools);
    final openAITools = toolDefinitions.values
        .map((definition) => definition.toOpenAITool())
        .toList();

    client = OpenAIClient(
      model: model,
      apiKey: apiKey,
      temperature: temperature,
      reasoningEffort: reasoningEffort,
      systemPrompt: systemPrompt,
      tools: openAITools.isEmpty ? null : openAITools,
      getMessages: getMessages,
    );
  }

  void _registerTool(ChatToolDefinition definition) {
    if (definition.name.isEmpty) {
      throw LanguageError('Chat tool name cannot be empty.');
    }
    if (toolDefinitions.containsKey(definition.name)) {
      throw LanguageError('Duplicate Chat tool name: ${definition.name}.');
    }
    toolDefinitions[definition.name] = definition;
  }

  void _parseLegacyTools(dynamic config, ChatToolKind kind) {
    if (config is! List) return;
    for (final item in config) {
      final tool = Utils.getMap(item);
      if (tool == null || tool.isEmpty) continue;
      final name = tool.keys.first;
      final details = Utils.getMap(tool[name]) ?? {};
      final rawInputs = Utils.getMap(details['inputs']) ?? {};
      final inputs = <String, dynamic>{};
      for (final entry in rawInputs.entries) {
        final schema = entry.value is Map
            ? Map<String, dynamic>.from(entry.value as Map)
            : <String, dynamic>{'type': entry.value};
        schema.putIfAbsent('required', () => true);
        inputs[entry.key] = schema;
      }
      _registerTool(ChatToolDefinition(
        name: name,
        description: Utils.optionalString(details['description']) ?? '',
        inputs: inputs,
        kind: kind,
        action: kind == ChatToolKind.legacyAction
            ? EnsembleAction.from(tool)
            : null,
      ));
    }
  }

  void _parseAppTools(dynamic config) {
    if (config is! List) return;
    for (final item in config) {
      final tool = Utils.getMap(item);
      if (tool == null) continue;
      final name = Utils.optionalString(tool['name'])?.trim() ?? '';
      final options = Utils.getMap(tool['options']) ?? {};
      final action = EnsembleAction.from(tool['action']);
      final confirmation = Utils.getMap(options['confirmation']);
      final hasConfirmationWidget =
          Utils.optionalString(confirmation?['widget']) != null;
      if (action == null && !hasConfirmationWidget) {
        throw LanguageError(
            "Chat tool '$name' requires an action or a confirmation widget.");
      }
      _registerTool(ChatToolDefinition(
        name: name,
        description: Utils.optionalString(tool['description']) ?? '',
        inputs: Utils.getMap(tool['inputs']) ?? {},
        kind: ChatToolKind.appTool,
        action: action,
        options: options,
      ));
    }
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

  /// Results associated with tool calls in [rawResponse].
  final List<ChatToolResult> toolResults = [];

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
