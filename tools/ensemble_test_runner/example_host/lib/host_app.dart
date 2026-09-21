import 'package:ensemble_test_runner_host_example/ensemble_host.dart';
import 'package:flutter/material.dart';

/// Flutter host: login, then a 3-tab shell with Ensemble as a child screen.
class HostApp extends StatefulWidget {
  const HostApp({super.key});

  @override
  State<HostApp> createState() => _HostAppState();
}

class _HostAppState extends State<HostApp> {
  var _loggedIn = false;

  @override
  Widget build(BuildContext context) {
    if (!_loggedIn) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
          useMaterial3: true,
        ),
        home: LoginScreen(onLogin: () => setState(() => _loggedIn = true)),
      );
    }
    return const EnsembleHost(child: AppShell());
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onLogin});

  final VoidCallback onLogin;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController(text: 'user@example.com');
  final _password = TextEditingController(text: 'password');

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('login_screen'),
      appBar: AppBar(title: const Text('Sign in')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Flutter host login'),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('email_field'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('password_field'),
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const ValueKey('login_button'),
              onPressed: widget.onLogin,
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  var _index = 0;

  static const _titles = ['Home', 'Shop', 'Account'];

  void _openShopFromCard() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ShopRoutePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('host_shell'),
      appBar: AppBar(title: Text(_titles[_index])),
      body: switch (_index) {
        1 => const EnsembleShopView(),
        2 => const AccountScreen(),
        _ => HomeScreen(onOpenShop: _openShopFromCard),
      },
      bottomNavigationBar: BottomNavigationBar(
        key: const ValueKey('host_bottom_nav'),
        currentIndex: _index,
        onTap: (index) => setState(() => _index = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined, key: ValueKey('nav_home')),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.storefront_outlined, key: ValueKey('nav_shop')),
            activeIcon: Icon(Icons.storefront),
            label: 'Shop',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline, key: ValueKey('nav_account')),
            activeIcon: Icon(Icons.person),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onOpenShop});

  final VoidCallback onOpenShop;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('home_screen'),
      padding: const EdgeInsets.all(24),
      children: [
        Text('Home',
            key: const ValueKey('home_title'),
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text(
            'This tab is Flutter. Open Ensemble from the card or the Shop tab.'),
        const SizedBox(height: 16),
        Card(
          child: InkWell(
            key: const ValueKey('open_shop_card'),
            onTap: onOpenShop,
            child: const ListTile(
              leading: Icon(Icons.storefront),
              title: Text('Open Shop'),
              subtitle: Text('Pushes the Ensemble shop from the Flutter host'),
              trailing: Icon(Icons.chevron_right),
            ),
          ),
        ),
      ],
    );
  }
}

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('account_screen'),
      padding: const EdgeInsets.all(24),
      children: [
        Text('Account',
            key: const ValueKey('account_title'),
            style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text(
            'This tab is Flutter. Profile and settings stay in the host app.'),
      ],
    );
  }
}
