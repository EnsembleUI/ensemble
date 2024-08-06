// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';

import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble_chat/ensemble_chat.dart';
import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart';

import 'helpers/bubble_container.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.messages,
    required this.onMessageSend,
  });

  final List<InternalMessage> messages;
  final Function(String value) onMessageSend;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final ScrollController scrollController = ScrollController();

  final TextEditingController _textController = TextEditingController();

  @override
  void didUpdateWidget(covariant ChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
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
                  ),
                );
              },
              findChildIndexCallback: (key) {
                // TODO: https://www.youtube.com/watch?v=2FjCg1IAeds
                return null;
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
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.5),
                          spreadRadius: 1,
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TextFormField(
                      controller: _textController,
                      maxLines: 5,
                      minLines: 1,
                      onFieldSubmitted: (value) {
                        if (_textController.text.trim().isEmpty) return;
                        widget.onMessageSend.call(_textController.text);
                        _textController.clear();
                      },
                      decoration: InputDecoration(
                        hintText: 'Send a message',
                        filled: true,
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
                  icon: const Icon(
                    Icons.send,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    if (_textController.text.trim().isEmpty) return;
                    widget.onMessageSend.call(_textController.text);
                    _textController.clear();
                  },
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  splashRadius: 24,
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MessageWidget extends StatelessWidget {
  const MessageWidget({super.key, required this.message});

  final InternalMessage message;

  @override
  Widget build(BuildContext context) {
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                if (message.content != null)
                  BubbleContainer(
                    text: message.content ?? '',
                    color: const Color(0xFFEAEAEA),
                    bubbleAlignment: BubbleAlignment.left,
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
    print("EnsembleChat: error while buidling inline widget:\n$e");
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
