import 'package:flutter/material.dart';
import 'home_page.dart';
import 'add_transaction_page.dart';
import 'settings_page.dart';
import 'stats_page.dart';
import 'history_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;

  List<Widget> get _pages => [
        HomePage(onSeeAllPressed: () => _onItemTapped(2)),
        const StatsPage(),
        const HistoryPage(),
        const SettingsPage(),
      ];

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to Add Transaction
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddTransactionPage()),
          );
        },
        backgroundColor: Colors.cyan, // Teal/Cyan per requirement
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: const Color(0xFF1E293B), // Charcoal / Dark Color
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            _buildNavItem(Icons.home_filled, 0),
            _buildNavItem(Icons.bar_chart, 1),
            const SizedBox(width: 48), // Space for FAB
            _buildNavItem(Icons.account_balance_wallet, 2),
            _buildNavItem(Icons.person, 3),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index) {
    final isSelected = _currentIndex == index;
    return IconButton(
      icon: Icon(
        icon,
        color: isSelected ? Colors.cyan : Colors.grey,
        size: 28,
      ),
      onPressed: () => _onItemTapped(index),
    );
  }
}
