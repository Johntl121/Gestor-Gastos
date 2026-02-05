import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dashboard_provider.dart';

class WalletPage extends StatelessWidget {
  const WalletPage({super.key});

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFF1E293B);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        title: const Text("Billetera",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Consumer<DashboardProvider>(
        builder: (context, provider, child) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                // --- Accounts PageView ---
                SizedBox(
                  height: 200,
                  child: PageView(
                    controller: PageController(viewportFraction: 0.9),
                    children: [
                      _buildAccountCard(
                        "Efectivo",
                        provider.currencySymbol,
                        provider.cashBalance,
                        Colors.green,
                        Icons.payments_outlined,
                      ),
                      _buildAccountCard(
                        "Banco",
                        provider.currencySymbol,
                        provider.bankBalance,
                        const Color(0xFF1565C0), // Dark Blue
                        Icons.account_balance,
                      ),
                      _buildAccountCard(
                        "Ahorros",
                        provider.currencySymbol,
                        provider.savingsBalance,
                        const Color(0xFF6A1B9A), // Purple
                        Icons.savings,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // --- Goals Section ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Mis Metas",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.cyan,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.add, color: Colors.white),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Mock Goals List
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      _buildGoalItem("Laptop Gamer", 3500, 1200, Colors.blue),
                      const SizedBox(height: 15),
                      _buildGoalItem("Viaje a Japón", 8000, 2500, Colors.pink),
                      const SizedBox(height: 15),
                      _buildGoalItem(
                          "Fondo Emergencia", 1000, 1000, Colors.green),
                    ],
                  ),
                ),
                const SizedBox(height: 100), // Spacing for safe area
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAccountCard(String title, String currency, double balance,
      Color color, IconData icon) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 5),
          )
        ],
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: Colors.white70, size: 32),
              const Icon(Icons.more_horiz, color: Colors.white70),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "$currency ${balance.toStringAsFixed(2)}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildGoalItem(
      String title, double target, double current, Color color) {
    final double progress = (current / target).clamp(0.0, 1.0);
    final int percent = (progress * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2C3E50),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.flag, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                    Text(
                      "$percent%",
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    color: color,
                    backgroundColor: Colors.white10,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "${current.toStringAsFixed(0)} / ${target.toStringAsFixed(0)}",
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
