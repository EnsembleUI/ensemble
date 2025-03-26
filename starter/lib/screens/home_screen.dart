import 'package:flutter/material.dart';
import 'tabs/home_tab.dart';
import 'tabs/sports_tab.dart';

class HomeScreen extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  
  const HomeScreen({super.key, required this.navigatorKey});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = [
      const HomeTab(),
      SportsTab(navigatorKey: widget.navigatorKey),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tabs[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.sports),
            label: 'Sports',
          ),
        ],
      ),
    );
  }
}