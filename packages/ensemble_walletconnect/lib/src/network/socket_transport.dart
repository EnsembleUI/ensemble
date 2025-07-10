import 'dart:async';
import 'dart:convert';

import 'package:ensemble_walletconnect/src/api/websocket/web_socket_message.dart';
import 'package:ensemble_walletconnect/src/network/reconnecting_web_socket.dart';
import 'package:ensemble_walletconnect/src/utils/event.dart';
import 'package:ensemble_walletconnect/src/utils/event_bus.dart';

/// The transport layer used to perform JSON-RPC 2 requests.
/// A client calls methods on a server and handles the server's responses to
/// those method calls. Methods can be called with [sendRequest].
class SocketTransport {
  final String protocol;
  final int version;
  final String url;
  final List<String> subscriptions;

  ReconnectingWebSocket? _socket;

  final EventBus _eventBus;

  /// The transport layer used to perform JSON-RPC 2 requests.
  SocketTransport({
    required this.protocol,
    required this.version,
    required this.url,
    required this.subscriptions,
  }) : _eventBus = EventBus();

  /// Open a new connection to a web socket server.
  void open({OnSocketOpen? onOpen, OnSocketClose? onClose}) {
    // Connect the channel
    final wsUrl = getWebSocketUrl(
      url: url,
      protocol: protocol,
      version: version.toString(),
    );

    _socket = ReconnectingWebSocket(
      url: wsUrl,
      maxReconnectAttempts: 5,
      debug: false,
      onOpen: onOpen,
      onClose: onClose,
      onMessage: _socketReceive,
    );

    _socket?.open(false);

    // Queue subscriptions
    _queueSubscriptions();
  }

  /// Closes the web socket connection.
  Future close({bool forceClose = false}) async {
    return _socket?.close(forceClose: forceClose);
  }

  /// Send a given payload to the server.
  /// The payload is json-encoded before sending.
  bool send({
    required Map<String, dynamic> payload,
    required String topic,
    bool silent = false,
  }) {
    final data = {
      'topic': topic,
      'type': 'pub',
      'payload': json.encode(payload),
      'silent': silent,
    };

    final message = json.encode(data);
    return _socket?.send(message) ?? false;
  }

  /// Subscribe to a given topic.
  void subscribe({required String topic}) {
    final data = {
      'topic': topic,
      'type': 'sub',
      'payload': '',
      'silent': true,
    };

    final message = json.encode(data);
    _socket?.send(message);
  }

  /// Send an ack.
  void ack({required String topic}) {
    final data = {
      'topic': topic,
      'type': 'ack',
      'payload': '',
      'silent': true,
    };

    final message = json.encode(data);
    _socket?.send(message);
  }

  /// Listen to events.
  void on<T>(String eventName, OnEvent<T> callback) {
    _eventBus
        .on<Event<T>>()
        .where((event) => event.name == eventName)
        .listen((event) => callback(event.data));
  }

  /// Check if we are currently connected with the socket.
  bool get connected => _socket?.connected ?? false;

  void _socketReceive(event) {
    if (event is! String) return;

    try {
      final data = json.decode(event);
      final message = WebSocketMessage.fromJson(data);
      ack(topic: message.topic);
      _eventBus.fire(Event<WebSocketMessage>('message', message));
    } catch (ex) {
      return;
    }
  }

  /// Get the websocket url based on a given url.
  String getWebSocketUrl({
    required String url,
    required String protocol,
    required String version,
  }) {
    url = url.startsWith('https')
        ? url.replaceFirst('https', 'wss')
        : url.startsWith('http')
            ? url.replaceFirst('http', 'ws')
            : url;

    final splitUrl = url.split('?');

    final params = Uri.dataFromString(url).queryParameters;
    final queryParams = {
      ...params,
      'protocol': protocol,
      'version': version,
      'env': 'browser',
      'host': 'test',
    };
    final queryString = Uri(queryParameters: queryParams).query;
    return '${splitUrl[0]}?$queryString';
  }

  void _queueSubscriptions() {
    for (var topic in subscriptions) {
      subscribe(topic: topic);
    }
  }
}
