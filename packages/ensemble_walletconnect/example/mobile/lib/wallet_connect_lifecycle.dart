import 'package:flutter/widgets.dart';
import 'package:ensemble_walletconnect/ensemble_walletconnect.dart';

class WalletConnectLifecycle extends StatefulWidget {
  final WalletConnect connector;
  final Widget child;

  const WalletConnectLifecycle({
    Key? key,
    required this.connector,
    required this.child,
  }) : super(key: key);

  @override
  State<WalletConnectLifecycle> createState() => _WalletConnectLifecycleState();
}

class _WalletConnectLifecycleState extends State<WalletConnectLifecycle>
    with WidgetsBindingObserver {
  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    super.initState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('AppLifecycleState: ${state.toString()}.');
    final connector = widget.connector;
    if (state == AppLifecycleState.resumed && mounted) {
      if (connector.connected && !connector.bridgeConnected) {
        print('Attempt to recover');
        connector.reconnect();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
