import 'package:ensemble_walletconnect/ensemble_walletconnect.dart';

abstract class TransactionTester {
  TransactionTester({required this.connector});

  final WalletConnect connector;

  Future<String> signTransaction(SessionStatus session);

  Future<String> signTransactions(SessionStatus session);

  Future<SessionStatus> connect({OnDisplayUriCallback? onDisplayUri});

  Future<void> disconnect();
}
