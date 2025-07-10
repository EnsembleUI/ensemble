import 'package:algorand_dart/algorand_dart.dart';
import 'package:ensemble_walletconnect/ensemble_walletconnect.dart';

class WalletConnector {
  final Algorand algorand;
  final WalletConnect connector;
  final AlgorandWalletConnectProvider provider;

  const WalletConnector._internal({
    required this.algorand,
    required this.connector,
    required this.provider,
  });

  factory WalletConnector() {
    final algorand = Algorand(
      algodClient: AlgodClient(apiUrl: AlgoExplorer.TESTNET_ALGOD_API_URL),
    );

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

    final provider = AlgorandWalletConnectProvider(connector);

    return WalletConnector._internal(
      algorand: algorand,
      connector: connector,
      provider: provider,
    );
  }

  Future<String> signTransaction(SessionStatus session) async {
    final sender = Address.fromAlgorandAddress(address: session.accounts[0]);

    // Fetch the suggested transaction params
    final params = await algorand.getSuggestedTransactionParams();

    // Build the transaction
    final tx = await (PaymentTransactionBuilder()
          ..sender = sender
          ..noteText = 'Signed with WalletConnect'
          ..amount = Algo.toMicroAlgos(0.0001)
          ..receiver = sender
          ..suggestedParams = params)
        .build();

    // Sign the transaction
    final signedBytes = await provider.signTransaction(
      tx.toBytes(),
      params: {
        'message': 'Optional description message',
      },
    );

    // Broadcast the transaction
    final txId = await algorand.sendRawTransactions(
      signedBytes,
      waitForConfirmation: true,
    );

    // Kill the session
    connector.killSession();

    return txId;
  }

  Future<String> signTransactions(SessionStatus session) async {
    final sender = Address.fromAlgorandAddress(address: session.accounts[0]);

    // Fetch the suggested transaction params
    final params = await algorand.getSuggestedTransactionParams();

    // Build the transaction
    final tx1 = await (PaymentTransactionBuilder()
          ..sender = sender
          ..noteText = 'Signed with WalletConnect - 1'
          ..amount = Algo.toMicroAlgos(0.0001)
          ..receiver = sender
          ..suggestedParams = params)
        .build();

    final tx2 = await (PaymentTransactionBuilder()
          ..sender = sender
          ..noteText = 'Signed with WalletConnect - 2'
          ..amount = Algo.toMicroAlgos(0.0002)
          ..receiver = sender
          ..suggestedParams = params)
        .build();

    AtomicTransfer.group([tx1, tx2]);

    // Sign the transaction
    final signedBytes = await provider.signTransactions(
      [tx1.toBytes(), tx2.toBytes()],
      params: {
        'message': 'Optional description message',
      },
    );

    // Broadcast the transaction
    final txId = await algorand.sendRawTransactions(
      signedBytes,
      waitForConfirmation: true,
    );

    // Kill the session
    connector.killSession();

    return txId;
  }
}
