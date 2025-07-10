import 'package:algorand_dart/algorand_dart.dart';
import 'package:ensemble_walletconnect/ensemble_walletconnect.dart';

void main() async {
  // Create an Algorand instance
  final algorand = _buildAlgorand();

  // Create a connector
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

  final algo = AlgorandWalletConnectProvider(connector);

  // Check if connection is already established
  final session = await connector.createSession(
    chainId: 4160,
    onDisplayUri: (uri) => print(uri),
  );
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
  final signedBytes = await algo.signTransaction(
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
  print(txId);

  // Kill the session
  connector.killSession();
}

Algorand _buildAlgorand() {
  final algodClient = AlgodClient(
    apiUrl: AlgoExplorer.MAINNET_ALGOD_API_URL,
  );
  final indexerClient = IndexerClient(
    apiUrl: AlgoExplorer.MAINNET_ALGOD_API_URL,
  );
  return Algorand(algodClient: algodClient, indexerClient: indexerClient);
}
