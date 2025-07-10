/// Information regarding the current session.
class SessionStatus {
  final int chainId;
  final List<String> accounts;
  final int? networkId;
  final String? rpcUrl;

  SessionStatus({
    required this.chainId,
    required this.accounts,
    this.networkId,
    this.rpcUrl,
  });

  SessionStatus copyWith({
    int? chainId,
    List<String>? accounts,
    int? networkId,
    String? rpcUrl,
  }) {
    return SessionStatus(
      chainId: chainId ?? this.chainId,
      accounts: accounts ?? this.accounts,
      networkId: networkId ?? this.networkId,
      rpcUrl: rpcUrl ?? this.rpcUrl,
    );
  }

  @override
  String toString() {
    return 'SessionStatus{chainId: $chainId, accounts: $accounts, networkUrl: $networkId, rpcUrl: $rpcUrl}';
  }
}
