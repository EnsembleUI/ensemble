import 'package:ensemble_walletconnect/src/session/wallet_connect_session.dart';

abstract class SessionStorage {
  Future store(WalletConnectSession session);

  Future<WalletConnectSession?> getSession();

  Future removeSession();
}
