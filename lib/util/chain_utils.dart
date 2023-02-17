class ChainUtils {

  // Namespaces
  static const String ethereumNamespace = "eip155";

  // Chain Ids;
  static const String ethereumMainChain = "$ethereumNamespace:1";
  static const String ethereumTestChain = "$ethereumNamespace:5";

  //methods
  static const String ethSendTransaction = "eth_sendTransaction";
  static const String ethSignTransaction = "eth_signTransaction";
  static const String ethSign = "eth_sign";
  static const String personalSign = "personal_sign";

  //events
  static const String chainChanged = "chainChanged";
  static const String accountsChanged = "accountsChanged";

  static List<String> getEthereumMethods() {
    return [ethSendTransaction, ethSignTransaction, ethSign, personalSign];
  }

  static List<String> getEthereumEvents() {
    return [chainChanged, accountsChanged];
  }
  
}
