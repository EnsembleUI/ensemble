import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:ensemble_walletconnect/src/api/api.dart';
import 'package:ensemble_walletconnect/src/crypto/crypto.dart';
import 'package:ensemble_walletconnect/src/crypto/encrypted_payload.dart';
import 'package:ensemble_walletconnect/src/exceptions/exceptions.dart';
import 'package:ensemble_walletconnect/src/network/network.dart';
import 'package:ensemble_walletconnect/src/session/session.dart';
import 'package:ensemble_walletconnect/src/utils/bridge_utils.dart';
import 'package:ensemble_walletconnect/src/utils/event.dart';
import 'package:ensemble_walletconnect/src/utils/event_bus.dart';
import 'package:stack_trace/stack_trace.dart';
import 'package:uuid/uuid.dart';

const ethSigningMethods = [
  'eth_sendTransaction',
  'eth_signTransaction',
  'eth_sign',
  'eth_signTypedData',
  'eth_signTypedData_v1',
  'eth_signTypedData_v2',
  'eth_signTypedData_v3',
  'eth_signTypedData_v4',
  'personal_sign',
];

typedef OnConnectRequest = void Function(SessionStatus status);
typedef OnSessionUpdate = void Function(WCSessionUpdateResponse response);
typedef OnDisconnect = void Function();
typedef OnDisplayUriCallback = void Function(String uri);

/// WalletConnect is an open source protocol for connecting decentralised
/// applications to mobile wallets with QR code scanning or deep linking.
///
/// A user can interact securely with any Dapp from their mobile phone,
/// making WalletConnect wallets a safer choice compared to desktop or
/// browser extension wallets.
class WalletConnect {
  /// The wallet connect protocol
  static const protocol = 'wc';

  /// The current wallet connect version
  static const version = 1;

  /// The current active session.
  final WalletConnectSession session;

  /// The storage when sessions can be stored and retrieved.
  final SessionStorage? sessionStorage;

  /// Default signing methods (for Ethereum)
  final List<String> signingMethods;

  /// The socket transport layer
  SocketTransport _transport;

  /// The algorithm used to encrypt/decrypt payloads
  CipherBox cipherBox;

  /// The map of request ids to pending requests.
  final _pendingRequests = <int, _Request>{};

  /// Eventbus used for internal events.
  final EventBus _eventBus;

  WalletConnect._internal({
    required this.session,
    required this.sessionStorage,
    required this.signingMethods,
    required this.cipherBox,
    required SocketTransport transport,
  })  : _transport = transport,
        _eventBus = EventBus() {
    // Init transport event handling
    _initTransport();

    // Subscribe to internal events
    _subscribeToInternalEvents();

    if (session.handshakeTopic.isNotEmpty) {
      transport.subscribe(topic: session.handshakeTopic);
    }
  }

  /// WalletConnect is an open source protocol for connecting decentralised
  /// applications to mobile wallets with QR code scanning or deep linking.
  ///
  /// You should provide a bridge, uri or session object.
  factory WalletConnect({
    String bridge = '',
    String uri = '',
    WalletConnectSession? session,
    SessionStorage? sessionStorage,
    CipherBox? cipher,
    SocketTransport? transport,
    String? clientId,
    PeerMeta? clientMeta,
  }) {
    if (bridge.isEmpty && uri.isEmpty && session == null) {
      throw WalletConnectException(
        'Missing one of the required parameters: bridge / uri / session',
      );
    }

    if (bridge.isNotEmpty) {
      bridge = BridgeUtils.getBridgeUrl(bridge);
    }

    if (uri.isNotEmpty) {
      session = WalletConnectSession.fromUri(
        uri: uri,
        clientId: clientId ?? const Uuid().v4(),
        clientMeta: clientMeta ?? const PeerMeta(),
      );
    }

    session = session ??
        WalletConnectSession(
          bridge: bridge,
          accounts: [],
          clientId: clientId ?? const Uuid().v4(),
          clientMeta: clientMeta ?? const PeerMeta(),
        );

    cipher = cipher ?? WalletConnectCipher();

    transport = transport ??
        SocketTransport(
          protocol: session.protocol,
          version: session.version,
          url: session.bridge,
          subscriptions: [session.clientId],
        );

    return WalletConnect._internal(
      session: session,
      sessionStorage: sessionStorage,
      cipherBox: cipher,
      signingMethods: [...ethSigningMethods],
      transport: transport,
    );
  }

  /// Registers event subscriptions.
  /// https://docs.walletconnect.com/client-api#register-event-subscription
  /// Supported events: connect, disconnect, session_request, session_update
  void on<T>(String eventName, OnEvent<T> callback) {
    _eventBus
        .on<Event<T>>()
        .where((event) => event.name == eventName)
        .listen((event) => callback(event.data));
  }

  /// Creates a new session calling [createSession] if it doesnt exists, or returns the instantiated one.
  Future<SessionStatus> connect(
      {int? chainId, OnDisplayUriCallback? onDisplayUri}) async {
    if (connected) {
      onDisplayUri?.call(session.toUri());
      return SessionStatus(
        chainId: session.chainId,
        accounts: session.accounts,
      );
    }

    return await createSession(chainId: chainId, onDisplayUri: onDisplayUri);
  }

  /// Reconnects to the web socket server.
  void reconnect() {
    _transport.close(forceClose: true);
    _transport.open();
  }

  /// Creates a new session between the dApp and wallet.
  /// The dapp should call this method for initiating the session.
  /// https://docs.walletconnect.com/client-api#create-new-session-session_request
  Future<SessionStatus> createSession({
    int? chainId,
    OnDisplayUriCallback? onDisplayUri,
  }) async {
    if (connected) {
      throw WalletConnectException('Session currently connected');
    }

    // Generate encryption key
    session.key = await cipherBox.generateKey();

    final request = JsonRpcRequest(
      id: payloadId,
      method: 'wc_sessionRequest',
      params: [
        {
          'peerId': session.clientId,
          'peerMeta': session.clientMeta,
          'chainId': chainId,
        }
      ],
    );

    session.handshakeId = request.id;
    session.handshakeTopic = const Uuid().v4();

    // Display the URI
    final uri = session.toUri();
    onDisplayUri?.call(uri);
    _eventBus.fire(Event<String>('display_uri', uri));

    // Send the request
    final response = await _sendRequest(request, topic: session.handshakeTopic);

    // Notify listeners
    await _handleSessionResponse(response);

    return WCSessionRequestResponse.fromJson(response).status;
  }

  /// Approves the session requested by the peer (dApp), responding with the accounts and client's id and meta.
  /// https://docs.walletconnect.com/client-api#approve-session-request-connect
  Future approveSession({
    required List<String> accounts,
    required int chainId,
  }) async {
    if (connected) {
      throw WalletConnectException('Session currently connected');
    }

    final params = {
      'approved': true,
      'chainId': chainId,
      'networkId': 0,
      'accounts': accounts,
      'rpcUrl': '',
      'peerId': session.clientId,
      'peerMeta': session.clientMeta,
    };

    final response = JsonRpcResponse(
      id: session.handshakeId,
      result: params,
    );

    await _sendResponse(response);
    session.connected = true;

    // Notify listeners
    _eventBus.fire(Event<SessionStatus>(
      'connect',
      SessionStatus(
        chainId: chainId,
        accounts: accounts,
      ),
    ));
  }

  /// Rejects the session requested by the peer (dApp), responding with reason message.
  /// https://docs.walletconnect.com/client-api#reject-session-request-disconnect
  Future rejectSession({String? message}) async {
    if (connected) {
      throw WalletConnectException('Session currently connected');
    }

    message = message ?? 'Session Rejected';

    final response = JsonRpcResponse(
      id: session.handshakeId,
      error: {
        'code': -32000,
        'message': message,
      },
    );

    await _sendResponse(response);
    session.connected = false;

    // Notify listeners
    _eventBus.fire(Event<String>('disconnect', message));
  }

  /// Updates the actual session requesting the peer to change some session data
  /// Only chainId and/or accounts can be changed.
  /// https://docs.walletconnect.com/client-api#update-session-session_update
  Future updateSession(SessionStatus sessionStatus) async {
    if (!connected) {
      throw WalletConnectException('Session currently disconnected');
    }

    session.chainId = sessionStatus.chainId;
    session.accounts = sessionStatus.accounts;
    session.networkId = sessionStatus.networkId ?? 0;
    session.rpcUrl = sessionStatus.rpcUrl ?? '';

    final params = {
      'approved': true,
      'chainId': session.chainId,
      'networkId': session.networkId,
      'accounts': session.accounts,
      'rpcUrl': session.rpcUrl,
    };

    final request = JsonRpcRequest(
      id: payloadId,
      method: 'wc_sessionUpdate',
      params: [params],
    );

    // Send the request
    final response = await _sendRequest(request);

    // Notify listeners
    await _handleSessionResponse(response);
  }

  /// Approves a pending request responding with a hex encoded string
  /// https://docs.walletconnect.com/client-api#approve-call-request
  Future approveRequest({
    required int id,
    required String result,
  }) async {
    final response = JsonRpcResponse(
      id: id,
      result: result,
    );

    return _sendResponse(response);
  }

  /// Rejects a pending request specifing the error
  /// https://docs.walletconnect.com/client-api#reject-call-request
  Future rejectRequest({
    required int id,
    String? errorMessage,
  }) async {
    final response = JsonRpcResponse(
      id: id,
      error: {'error': errorMessage},
    );

    return _sendResponse(response);
  }

  /// Send a custom request.
  /// https://docs.walletconnect.com/client-api#send-custom-request
  Future sendCustomRequest({
    int? id,
    required String method,
    required List<dynamic> params,
    String? topic,
  }) async {
    final request = JsonRpcRequest(
      id: id ?? payloadId,
      method: method,
      params: params,
    );

    return _sendRequest(request);
  }

  /// Send a custom response.
  Future sendCustomResponse({
    required int id,
    String? result,
    String? error,
  }) async {
    final response = JsonRpcResponse(
      id: id,
      result: result,
      error: error,
    );

    return _sendResponse(response);
  }

  /// Kill the current session.
  /// https://docs.walletconnect.com/client-api#kill-session-disconnect
  Future killSession({String? sessionError}) async {
    final message = sessionError ?? 'Session disconnected';

    final request = JsonRpcRequest(
      id: payloadId,
      method: 'wc_sessionUpdate',
      params: [
        {
          'approved': false,
          'chainId': null,
          'networkId': null,
          'accounts': null,
        }
      ],
    );

    unawaited(_sendRequest(request));

    await _handleSessionDisconnect(errorMessage: message, forceClose: true);
  }

  /// Close the connection
  /// This does not kill and clear the session.
  Future close({bool forceClose = false}) async {
    return _transport.close(forceClose: forceClose);
  }

  /// Check if the request is a silent payload.
  bool isSilentPayload(JsonRpcRequest request) {
    if (request.method.startsWith('wc_')) {
      return true;
    }

    if (signingMethods.contains(request.method)) {
      return false;
    }

    return true;
  }

  /// Get a new random, payload id.
  int get payloadId {
    var rng = Random();
    final date = (DateTime.now().millisecondsSinceEpoch * pow(10, 3)).toInt();
    final extra = (rng.nextDouble() * pow(10, 3)).floor();
    return date + extra;
  }

  /// Check if a current session is connected.
  bool get connected => session.connected;

  /// Check if walletconnect is currently connected with the bridge.
  bool get bridgeConnected => _transport.connected;

  /// Register callback listeners.
  void registerListeners({
    OnConnectRequest? onConnect,
    OnSessionUpdate? onSessionUpdate,
    OnDisconnect? onDisconnect,
  }) {
    on<SessionStatus>('connect', (data) => onConnect?.call(data));
    on<WCSessionUpdateResponse>(
        'session_update', (data) => onSessionUpdate?.call(data));
    on('disconnect', (data) => onDisconnect?.call());
  }

  void _handleIncomingMessages(WebSocketMessage message) async {
    final activeTopics = [session.clientId, session.handshakeTopic];
    if (!activeTopics.contains(message.topic)) {
      return;
    }

    final key = session.key;
    if (key == null) {
      return;
    }

    // Decrypt the payload
    final encryptedPayload = EncryptedPayload.fromJson(
      json.decode(message.payload),
    );
    final payload = await cipherBox.decrypt(
      payload: encryptedPayload,
      key: key,
    );

    // Decode the data
    final data = json.decode(utf8.decode(payload));

    // Check if the incoming message is a request
    if (_isJsonRpcRequest(data)) {
      final request = JsonRpcRequest.fromJson(data);
      _eventBus.fire(Event(request.method, request));
      return;
    }

    // Handle the response
    _handleSingleResponse(data);
  }

  /// Sends a JSON-RPC-2 compliant request to invoke the given [method].
  /// If no topic is specified, then the session`s peerId is used as topic.
  Future _sendRequest(
    JsonRpcRequest request, {
    String? topic,
  }) async {
    final key = session.key;
    if (key == null) {
      return;
    }

    final data = json.encode(request.toJson());
    final payload = await cipherBox.encrypt(
      data: Uint8List.fromList(utf8.encode(data)),
      key: key,
    );

    final method = request.method;
    final silent = isSilentPayload(request);

    // Send the request
    _transport.send(
      payload: payload.toJson(),
      topic: topic ?? session.peerId,
      silent: silent,
    );

    var completer = Completer.sync();
    _pendingRequests[request.id] = _Request(method, completer, Chain.current());
    return completer.future;
  }

  Future _sendResponse(JsonRpcResponse response) async {
    final key = session.key;
    if (key == null) {
      return;
    }

    final data = json.encode(response.toJson());
    final payload = await cipherBox.encrypt(
      data: Uint8List.fromList(utf8.encode(data)),
      key: key,
    );

    // Send the request
    _transport.send(
      payload: payload.toJson(),
      topic: session.peerId,
      silent: true,
    );
  }

  void _initTransport() {
    _transport.on('message', _handleIncomingMessages);

    // Open a new connection
    _transport.open();
  }

  /// Handles incoming JSON RPC requests that do not have a mapped id.
  void _subscribeToInternalEvents() {
    // Wallet received a session request.
    on<JsonRpcRequest>('wc_sessionRequest', (payload) {
      final request = WCSessionRequest.fromJson(payload.params?[0]);
      session.handshakeId = payload.id;
      session.peerId = request.peerId ?? '';
      session.peerMeta = request.peerMeta ?? const PeerMeta();

      _eventBus.fire(Event<WCSessionRequest>('session_request', request));
    });

    // Wallet received a session update.
    on<JsonRpcRequest>('wc_sessionUpdate', (payload) {
      _handleSessionResponse(payload.params?[0] ?? {});
    });
  }

  /// Handles a decoded response from the server after batches have been
  /// resolved.
  void _handleSingleResponse(response) {
    if (!_isResponseValid(response)) return;
    var id = response['id'];
    id = (id is String) ? int.parse(id) : id;
    var request = _pendingRequests.remove(id)!;
    if (response.containsKey('result')) {
      request.completer.complete(response['result']);
    } else {
      request.completer.completeError(
          WalletConnectException(
            response['error']['message'],
            code: response['error']['code'],
            data: response['error']['data'],
          ),
          request.chain);
    }
  }

  /// Determines whether the server's response is valid per the spec.
  bool _isJsonRpcRequest(response) {
    if (response is! Map) return false;
    if (response['jsonrpc'] != '2.0') return false;
    var id = response['id'];
    id = (id is String) ? int.parse(id) : id;
    return response.containsKey('method');
  }

  /// Determines whether the server's response is valid per the spec.
  bool _isResponseValid(response) {
    if (response is! Map) return false;
    if (response['jsonrpc'] != '2.0') return false;
    var id = response['id'];
    id = (id is String) ? int.parse(id) : id;
    if (!_pendingRequests.containsKey(id)) return false;
    if (response.containsKey('result')) return true;

    if (!response.containsKey('error')) return false;
    var error = response['error'];
    if (error is! Map) return false;
    if (error['code'] is! int) return false;
    if (error['message'] is! String) return false;
    return true;
  }

  Future _handleSessionResponse(Map<String, dynamic> params) async {
    final approved = params['approved'] ?? false;
    final connected = this.connected;
    if (approved && !connected) {
      // New connection
      session.approve(params);

      // Store session
      await sessionStorage?.store(session);

      // Notify the listeners
      final data = WCSessionRequestResponse.fromJson(params);
      _eventBus.fire(Event<SessionStatus>('connect', data.status));
    } else if (approved && connected) {
      // Session update
      session.approve(params);

      // Store session
      await sessionStorage?.store(session);

      // Notify the listeners
      final data = WCSessionUpdateResponse.fromJson(params);
      _eventBus.fire(Event<WCSessionUpdateResponse>('session_update', data));
    } else {
      await _handleSessionDisconnect();
    }
  }

  Future _handleSessionDisconnect({
    String? errorMessage,
    bool forceClose = false,
  }) async {
    session.reset();

    // Remove storage session
    await sessionStorage?.removeSession();

    // Close the web socket connection
    await _transport.close(forceClose: forceClose);

    // Notify listeners
    _eventBus.fire(Event<Map<String, dynamic>>('disconnect', {
      'message': errorMessage ?? '',
    }));
  }
}

/// A pending request to the server.
class _Request {
  /// The method that was sent.
  final String method;

  /// The completer to use to complete the response future.
  final Completer completer;

  /// The stack chain from where the request was made.
  final Chain chain;

  _Request(this.method, this.completer, this.chain);
}
