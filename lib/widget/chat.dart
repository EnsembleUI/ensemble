import 'dart:convert';
import 'dart:math';

import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/view/page.dart';
import 'package:ensemble/framework/widget/widget.dart' as framework;
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/chat/bubble_container.dart';
import 'package:ensemble/widget/chat/models.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/input/slider.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:yaml/yaml.dart';

import 'chat/typing_indicator.dart';
import 'chat/utils.dart';

class EnsembleChatController extends WidgetController {
  String? url;
  String? userId;
}

class EnsembleChat extends StatefulWidget
    with Invokable, HasController<EnsembleChatController, EnsembleChatState> {
  static const type = 'Chat';

  @override
  EnsembleChatController get controller => EnsembleChatController();

  @override
  EnsembleChatState createState() => EnsembleChatState();

  @override
  Map<String, Function> getters() {
    return {};
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {
      'url': (value) => controller.url =
          Utils.getString(value, fallback: 'wc://localhost:8000/wc'),
      'userId': (newValue) =>
          controller.userId = Utils.getString(newValue, fallback: 'abc123'),
    };
  }
}

class EnsembleChatState extends framework.WidgetState<EnsembleChat> {
  List<Message> _messages = [];
  User? _user;
  User? _assistant;

  WebSocketChannel? channel;

  bool showIndicator = false;

  @override
  void initState() {
    super.initState();

    _user = const User(
      id: 'abc123',
    );

    _assistant = const User(id: '123');

    final uri = Uri.tryParse('ws://35.202.36.118:8000/ws');
    if (uri == null) return;
    channel = WebSocketChannel.connect(uri);

    channel?.stream.listen((event) {
      handleIncomingMessage(event);
    });
  }

  void handleIncomingMessage(dynamic event) {
    try {
      final data = jsonDecode(event);

      final textMessage = Message(
        author: _assistant!,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        id: generateRandomString(),
        text: data['content'],
        widgetDefinition: data['widgetDefinition'],
      );
      _addMessage(textMessage);
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  @override
  void dispose() {
    super.dispose();
    channel?.sink.close();
  }

  void _addMessage(Message message) {
    setState(() {
      showIndicator = !showIndicator;
      _messages.insert(0, message);
    });
  }

  Future<void> _handleSendPressed(String message) async {
    channel?.sink.add(message);

    final textMessage = Message(
      author: _user!,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: generateRandomString(),
      text: message,
    );
    _addMessage(textMessage);
  }

  @override
  Widget buildWidget(BuildContext context) {
    return ChatPage(
      items: _messages,
      onSendPressed: _handleSendPressed,
      showIndicator: showIndicator,
    );
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.items,
    required this.onSendPressed,
    required this.showIndicator,
  });
  final List<Object> items;
  final Function(String value) onSendPressed;
  final bool showIndicator;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final ScrollController scrollController = ScrollController();

  final TextEditingController _textController = TextEditingController();

  @override
  void didUpdateWidget(covariant ChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);

    // _scrollToBottomIfNeeded(oldWidget.items);
  }

  // void _scrollToBottomIfNeeded(List<Object> oldList) {
  //   try {
  //     final oldItem = oldList[1];
  //     final item = widget.items[1];

  //     final oldMessage = oldItem['message']! as Message;
  //     final message = item['message']! as Message;
  //     if (oldMessage.id != message.id) {
  //       // Run only for sent message.

  //       Future.delayed(const Duration(milliseconds: 100), () {
  //         if (scrollController.hasClients) {
  //           scrollController.animateTo(
  //             0,
  //             duration: const Duration(milliseconds: 200),
  //             curve: Curves.easeInQuad,
  //           );
  //         }
  //       });
  //     }
  //   } catch (e) {
  //     //ignore
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF5F5F5),
      child: Column(
        children: [
          Flexible(
            child: ListView.separated(
              itemCount: widget.items.length + 1,
              reverse: true,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return TypingIndicator(showIndicator: widget.showIndicator);
                }

                Widget? dynamicWidget;
                final message = widget.items.elementAt(index - 1) as Message;
                if (message.widgetDefinition != null) {
                  dynamicWidget = buildWidgetsFromTemplate(
                      context, message.widgetDefinition);
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BubbleContainer(
                      text: message.text,
                      color: message.author.id != '123'
                          ? const Color(0xFFEAEAEA)
                          : Colors.white,
                    ),
                    if (dynamicWidget != null)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12.0),
                            child: dynamicWidget,
                          ),
                          if (dynamicWidget is EnsembleSlider)
                            ElevatedButton(
                              onPressed: () {
                                widget.onSendPressed.call(
                                  (dynamicWidget as EnsembleSlider)
                                      .controller
                                      .value
                                      .toString(),
                                );
                              },
                              child: const Text('Submit'),
                            )
                        ],
                      ),
                  ],
                );
              },
              separatorBuilder: (BuildContext context, int index) {
                return const SizedBox(height: 8);
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
                  child: TextFormField(
                    controller: _textController,
                    maxLines: 5,
                    minLines: 1,
                    decoration: InputDecoration(
                      fillColor: Colors.grey[200],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.0),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.0),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.0),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  constraints: const BoxConstraints(
                    minHeight: 24,
                    minWidth: 24,
                  ),
                  icon: Image.asset(
                    'assets/icon-send.png',
                    package: 'flutter_chat_ui',
                    color: Colors.black,
                  ),
                  onPressed: () {
                    if (_textController.text.trim().isEmpty) return;
                    widget.onSendPressed.call(_textController.text);
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

Widget? buildWidgetsFromTemplate(
    BuildContext context, dynamic widgetDefinition) {
  if (widgetDefinition is! Map) return null;
  final definition = YamlMap.wrap({
    widgetDefinition.keys.last: widgetDefinition.values.last,
  });

  ScopeManager? parentScope = DataScopeWidget.getScope(context);
  final widget = parentScope?.buildWidgetFromDefinition(definition);
  return widget;
}
