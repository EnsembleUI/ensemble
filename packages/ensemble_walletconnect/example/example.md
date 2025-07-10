# walletconnect_dart

WalletConnect is an open source protocol for connecting decentralised applications to mobile wallets
with QR code scanning or deep linking. A user can interact securely with any Dapp from their mobile
phone, making WalletConnect wallets a safer choice compared to desktop or browser extension wallets.

## Getting Started

### Installation

You can install the package via pub.dev:

```bash
walletconnect_dart: ^latest-version
```

> **Note**: walletconnect-dart requires Dart >=2.14.0 & null safety
> See the latest version on pub.dev

## Usage
Create a ```WalletConnect``` connector and use ```createSession``` to start a new session.

```dart
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

// Set a default walletconnect provider
connector.setDefaultProvider(AlgorandWCProvider(connector));

// Check if connection is already established
final session = await connector.createSession(
    chainId: 4160,
    onDisplayUri: (uri) => print(uri),
);


final sender = Address.fromAlgorandAddress(address: session.accounts[0]);

// Fetch the suggested transaction params
final params = await algorand.getSuggestedTransactionParams();

// Build the transaction
final transaction = await (PaymentTransactionBuilder()
    ..sender = sender
    ..noteText = 'Signed with WalletConnect'
    ..amount = Algo.toMicroAlgos(0.0001)
    ..receiver = sender
    ..suggestedParams = params)
  .build();

// Sign the transaction
final txBytes = Encoder.encodeMessagePack(transaction.toMessagePack());
final signedBytes = await connector.signTransaction(
    txBytes,
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
```

Once installed, you can simply connect your application to the blockchain and start sending payments

```dart
algorand.sendPayment(
    account: account,
    recipient: newAccount.address,
    amount: Algo.toMicroAlgos(5),
);
```

### Algorand TestNet

It's better and cheaper to test on Algorand TestNet before testing on Algorand MainNet. To switch to TestNet update the `AlgodClient` to use the TestNet URL.

```dart
final algorand = Algorand(
  algodClient: AlgodClient(apiUrl: AlgoExplorer.TESTNET_ALGOD_API_URL),
);
```

If you need Algos on TestNet, you can use the faucet: https://bank.testnet.algorand.network/
