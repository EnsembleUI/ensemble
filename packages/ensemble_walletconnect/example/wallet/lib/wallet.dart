import 'package:ensemble_walletconnect/ensemble_walletconnect.dart';

void main() async {
  final connector = _buildApp();
  if (!connector.connected) {
    final session = await connector.createSession(
      chainId: 4160,
      onDisplayUri: (uri) {
        print(uri);

        _connectWallet(uri: uri);
      },
    );

    print('Session: $session');
  }

  await Future.delayed(Duration(days: 1));
}

WalletConnect _buildApp() {
  final connector = WalletConnect(
    bridge: 'https://bridge.walletconnect.org',
    clientMeta: PeerMeta(
      name: 'WalletConnect',
      description: 'WalletConnect Developer App',
      url: 'https://walletconnect.org',
      icons: [
        'https://gblobscdn.gitbook.com/spaces%2F-LJJeCjcLrr53DcT1Ml7%2Favatar.png?alt=media'
      ],
    ),
  );

  connector.on('connect', (event) => print('Connected: $event'));

  connector.on('session_update', (payload) {
    print('Payload: $payload');
  });

  connector.on('disconnect', (event) {
    print('Disconnected');
  });

  connector.registerListeners(onSessionUpdate: (payload) {
    print(payload);
  });

  return connector;
}

void _connectWallet({required String uri}) {
  final connector = WalletConnect(
    uri: uri,
    clientMeta: PeerMeta(
      name: 'Algorand Wallet',
      description: 'Unofficial Algorand wallet',
      url: 'https://www.algorand.com',
      icons: [
        'https://cdn-images-1.medium.com/max/1200/1*VDrnmUI_W3GeeRClkfRPfg.png'
      ],
    ),
  );

  // Subscribe to session requests
  connector.on('session_request', (payload) async {
    await connector.approveSession(chainId: 4160, accounts: ['test']);

    await connector
        .updateSession(SessionStatus(chainId: 4000, accounts: ['test2']));
  });

  connector.on('disconnect', (message) async {
    print('Wallet disconnected $message');
  });

  connector.on('session_update', (session) async {
    print('Session updated: $session');
  });
}
