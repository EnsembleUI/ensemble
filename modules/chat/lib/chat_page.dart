// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';

import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_chat/ensemble_chat.dart';
import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart';

import 'helpers/bubble_container.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.messages,
    required this.onMessageSend,
    required this.controller,
  });

  final List<InternalMessage> messages;
  final Function(String value) onMessageSend;
  final EnsembleChatController controller;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class BubbleStyleComposite extends WidgetCompositeProperty {
  BubbleStyleComposite(ChangeNotifier widgetController) : super(widgetController);

  Color? backgroundColor;
  Color? textColor;
  double borderRadius = 20.0;
  TextStyle? textStyle;
  EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
  EdgeInsets margin = const EdgeInsets.symmetric(vertical: 4);

  factory BubbleStyleComposite.from(
      ChangeNotifier widgetController, dynamic payload) {
    BubbleStyleComposite composite = BubbleStyleComposite(widgetController);
    if (payload is Map) {
      composite.backgroundColor = Utils.getColor(payload['backgroundColor']);
      composite.textColor = Utils.getColor(payload['textColor']);
      composite.borderRadius =
          Utils.getDouble(payload['borderRadius'], fallback: 20.0);
      composite.textStyle = Utils.getTextStyle(payload['textStyle']);
      composite.padding = Utils.getInsets(payload['padding'],
          fallback: const EdgeInsets.symmetric(horizontal: 16, vertical: 12));
      composite.margin = Utils.getInsets(payload['margin'],
          fallback: const EdgeInsets.symmetric(vertical: 4));
    }
    return composite;
  }

  @override
  Map<String, Function> setters() => {
        'backgroundColor': (value) => backgroundColor = Utils.getColor(value),
        'textColor': (value) => textColor = Utils.getColor(value),
        'borderRadius': (value) =>
            borderRadius = Utils.getDouble(value, fallback: 20.0),
        'textStyle': (value) => textStyle = Utils.getTextStyle(value),
        'padding': (value) => padding = Utils.getInsets(value,
            fallback: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
        'margin': (value) => margin = Utils.getInsets(value,
            fallback: const EdgeInsets.symmetric(vertical: 4)),
      };

  @override
  Map<String, Function> getters() => {
        'backgroundColor': () => backgroundColor,
        'textColor': () => textColor,
        'borderRadius': () => borderRadius,
        'textStyle': () => textStyle,
        'padding': () => padding,
        'margin': () => margin,
      };

  @override
  Map<String, Function> methods() => {};
}

class _ChatPageState extends State<ChatPage> {
  final ScrollController scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: widget.controller.backgroundColor ?? Colors.black,
        body: Column(
          children: [
            Flexible(
              child: ListView.builder(
                reverse: true,
                itemCount: widget.messages.length,
                itemBuilder: (context, index) {
                  final effectiveIndex = widget.messages.length - 1 - index;
                  final message = widget.messages.elementAt(effectiveIndex);
                  return Container(
                    margin: const EdgeInsets.only(top: 8.0),
                    child: MessageWidget(
                      key: ValueKey(message.id),
                      message: message,
                      controller: widget.controller,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.fromLTRB(
                MediaQuery.of(context).padding.left + 16,
                0,
                MediaQuery.of(context).padding.right + 16,
                MediaQuery.of(context).viewInsets.bottom +
                    MediaQuery.of(context).padding.bottom +
                    8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: widget.controller.textFieldBackgroundColor ??
                            Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TextFormField(
                        controller: _textController,
                        style: widget.controller.textFieldTextStyle ??
                            const TextStyle(color: Colors.white),
                        maxLines: 5,
                        minLines: 1,
                        onFieldSubmitted: _handleSubmit,
                        decoration: InputDecoration(
                          hintText: 'Send a message',
                          filled: true,
                          fillColor: Colors.transparent,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16.0),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16.0),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16.0),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    constraints: const BoxConstraints(
                      minHeight: 24,
                      minWidth: 24,
                    ),
                    icon: Icon(
                      Icons.send,
                      color: widget.controller.iconColor ?? Colors.white,
                    ),
                    onPressed: () => _handleSubmit(),
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    splashRadius: 24,
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSubmit([String? value]) {
    if (_textController.text.trim().isEmpty) return;
    widget.onMessageSend.call(_textController.text);
    _textController.clear();
  }
}

class MessageWidget extends StatelessWidget {
  const MessageWidget({
    super.key,
    required this.message,
    required this.controller,
  });

  final InternalMessage message;
  final EnsembleChatController controller;

  BubbleStyleComposite _getStyleForRole() {
    switch (message.role) {
      case MessageRole.user:
        return controller.userBubbleStyle;
      case MessageRole.assistant:
        return controller.assistantBubbleStyle;
      case MessageRole.system:
        return controller.assistantBubbleStyle; // Fallback to assistant style
    }
  }

  @override
  Widget build(BuildContext context) {
    final bubbleStyle = _getStyleForRole();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: message.role == MessageRole.system
          ? Align(
              alignment: Alignment.center,
              child: Text(
                message.content ?? '',
                style: const TextStyle(color: Colors.white),
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: message.role == MessageRole.user
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                if (message.content != null)
                  BubbleContainer(
                    text: message.content ?? '',
                    bubbleAlignment: message.role == MessageRole.user
                        ? BubbleAlignment.right
                        : BubbleAlignment.left,
                    color: bubbleStyle.backgroundColor ??
                        Colors.white.withOpacity(0.15),
                    textStyle: bubbleStyle.textStyle?.copyWith(
                          color: bubbleStyle.textColor,
                        ) ??
                        TextStyle(color: bubbleStyle.textColor ?? Colors.white),
                    padding: bubbleStyle.padding,
                    margin: bubbleStyle.margin,
                    bubbleRadius: bubbleStyle.borderRadius,
                  ),
                if (message.widget != null)
                  Container(
                    margin: const EdgeInsets.only(top: 8.0),
                    child: Theme(
                      data: ThemeData.dark(useMaterial3: true),
                      child: message.widget ?? const SizedBox.shrink(),
                    ),
                  ),
              ],
            ),
    );
  }
}

Widget? buildWidgetsFromTemplate(
    BuildContext context, dynamic widgetDefinition) {
  if (widgetDefinition is! Map || widgetDefinition.isEmpty) return null;
  try {
    final definition = YamlMap.wrap({
      widgetDefinition.keys.last: {
        "inputs": jsonDecode(widgetDefinition.values.last)
      },
    });

    ScopeManager? parentScope = DataScopeWidget.getScope(context);
    final widget = parentScope?.buildWidgetFromDefinition(definition);
    return widget;
  } on Exception catch (e) {
    print("EnsembleChat: error while building inline widget:\n$e");
  }
  return null;
}

class TimeElapsedWidget extends StatefulWidget {
  const TimeElapsedWidget({super.key, required this.startTime});

  final DateTime startTime;

  @override
  State<TimeElapsedWidget> createState() => _TimeElapsedWidgetState();
}

class _TimeElapsedWidgetState extends State<TimeElapsedWidget> {
  late DateTime currentTime;
  late Duration elapsedTime;
  late String formattedElapsedTime;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    currentTime = DateTime.now();
    _calculateElapsedTime();
    _startTimer();
  }

  void _calculateElapsedTime() {
    elapsedTime = currentTime.difference(widget.startTime);
    formattedElapsedTime =
        '${elapsedTime.inSeconds}.${(elapsedTime.inMilliseconds % 1000).toString().padLeft(3, '0')}s';
  }

  void _startTimer() {
    timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      setState(() {
        currentTime = DateTime.now();
        _calculateElapsedTime();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      formattedElapsedTime,
      style: const TextStyle(fontSize: 12, color: Colors.white),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }
}
