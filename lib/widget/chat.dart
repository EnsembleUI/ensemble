import 'dart:convert';
import 'dart:math';

import 'package:ensemble/framework/widget/widget.dart' as framework;
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';

import 'package:web_socket_channel/web_socket_channel.dart';

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

  WebSocketChannel? channel;

  @override
  void initState() {
    super.initState();

    _user = const User(
      id: 'abc123',
    );
    final uri = Uri.tryParse('ws://127.0.0.1:8000/ws');
    if (uri == null) return;
    channel = WebSocketChannel.connect(uri);

    channel?.stream.listen((event) {
      try {
        final data = jsonDecode(event);

        final textMessage = Message(
          author: _user!,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          id: generateRandomString(),
          text: data['content'],
          widgetDefinition: data['widget'],
        );
        _addMessage(textMessage);
      } catch (e) {
        //todo
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
    channel?.sink.close();
  }

  void _addMessage(Message message) {
    setState(() {
      _messages.insert(0, message);
    });
  }

  void _handleSendPressed(String message) {
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
    );
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key, required this.items, required this.onSendPressed});
  final List<Object> items;
  final Function(String value) onSendPressed;

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
              itemCount: widget.items.length,
              reverse: true,
              itemBuilder: (context, index) {
                final message = widget.items.elementAt(index) as Message;
                return BubbleNormal(
                  text: message.text,
                  color: Colors.white,
                );
              },
              separatorBuilder: (BuildContext context, int index) {
                return const SizedBox(height: 8);
              },
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _textController,
                  maxLines: 5,
                  minLines: 1,
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
                  widget.onSendPressed.call(_textController.text);
                  _textController.clear();
                },
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                splashRadius: 24,
              )
            ],
          ),
        ],
      ),
    );
  }
}

class BubbleNormal extends StatelessWidget {
  final double bubbleRadius;
  final Color color;
  final String text;
  final TextStyle textStyle;

  const BubbleNormal({
    Key? key,
    required this.text,
    this.bubbleRadius = 16,
    this.color = Colors.white70,
    this.textStyle = const TextStyle(
      color: Colors.black87,
      fontSize: 16,
    ),
  }) : super(key: key);

  ///chat bubble builder method
  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          color: Colors.transparent,
          constraints:
              BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(0),
                  topRight: Radius.circular(bubbleRadius),
                  bottomLeft: Radius.circular(bubbleRadius),
                  bottomRight: Radius.circular(bubbleRadius),
                ),
              ),
              child: Stack(
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                    child: Text(
                      text,
                      style: textStyle,
                      textAlign: TextAlign.left,
                    ),
                  ),
                  SizedBox(width: 1),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class Message {
  const Message({
    required this.id,
    required this.author,
    required this.text,
    this.createdAt,
    this.updatedAt,
    this.metadata,
    this.widgetDefinition,
  });

  final String id;
  final User author;
  final int? createdAt;
  final Map<String, dynamic>? metadata;
  final int? updatedAt;
  final String text;
  final String? widgetDefinition;

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      author: User.fromJson(json['author']),
      text: json['text'],
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
      metadata: json['metadata'],
      widgetDefinition: json['widgetDefinition'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'author': author.toJson(),
      'text': text,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'metadata': metadata,
      'widgetDefinition': widgetDefinition,
    };
  }
}

class User {
  const User({required this.id, this.name});

  final String id;
  final String? name;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}

String generateRandomString({int length = 8}) {
  const randomChars =
      "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
  const charsLength = randomChars.length;

  final rand = Random();
  final codeUnits = List.generate(
    length,
    (index) => randomChars[rand.nextInt(charsLength)].codeUnitAt(0),
  );

  return String.fromCharCodes(codeUnits);
}
