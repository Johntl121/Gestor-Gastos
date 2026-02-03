import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/dashboard_provider.dart';
import '../../domain/entities/transaction_entity.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Definición de colores oscuros
    const backgroundColor = Color(0xFF121C22);
    const primaryBlue = Color(0xFF007BFF);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        centerTitle: true,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.person, color: Colors.white, size: 20),
        ),
        title: const Text(
          "Historial",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.search, color: Colors.white, size: 24),
          )
        ],
      ),
      body: Consumer<DashboardProvider>(
        builder: (context, provider, child) {
          final grouped = <String, List<TransactionEntity>>{};
          final now = DateTime.now();

          for (var t in provider.transactions) {
            String key;
            final isToday = t.date.year == now.year &&
                t.date.month == now.month &&
                t.date.day == now.day;
            final isYesterday = t.date.year == now.year &&
                t.date.month == now.month &&
                t.date.day == now.day - 1;

            if (isToday) {
              key = 'HOY';
            } else if (isYesterday) {
              key = 'AYER';
            } else {
              key = DateFormat('MMM d').format(t.date).toUpperCase();
            }

            if (!grouped.containsKey(key)) {
              grouped[key] = [];
            }
            grouped[key]!.add(t);
          }

          return Column(
            children: [
              // 1. Filtros Horizontales
              SizedBox(
                height: 60,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  children: [
                    _buildFilterChip("Este Mes", true, primaryBlue),
                    const SizedBox(width: 8),
                    _buildFilterChip("Categoría", false, Colors.transparent,
                        icon: Icons.tune),
                    const SizedBox(width: 8),
                    _buildFilterChip("Comida", false, Colors.transparent),
                    const SizedBox(width: 8),
                    _buildFilterChip("Transporte", false, Colors.transparent),
                  ],
                ),
              ),

              // 2. Lista Agrupada Real
              Expanded(
                child: grouped.isEmpty
                    ? Center(
                        child: Text("No hay historial",
                            style: TextStyle(color: Colors.grey[600])))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: grouped.keys.length,
                        itemBuilder: (context, index) {
                          final key = grouped.keys.elementAt(index);
                          final transactions = grouped[key]!;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader(key),
                              ...transactions.map((t) => _buildTransactionItem(
                                    title: t.description,
                                    subtitle:
                                        "${DateFormat('h:mm a').format(t.date)} • Categoría", // TODO: Real category name
                                    amount:
                                        "${t.amount > 0 ? '+' : ''}S/ ${t.amount.toStringAsFixed(2)}",
                                    paymentMethod: "CASH", // Mocked for now
                                    icon: t.amount > 0
                                        ? Icons.account_balance_wallet
                                        : Icons.shopping_bag,
                                    color: t.amount > 0
                                        ? Colors.teal.shade300
                                        : Colors.orange.shade300,
                                    isIncome: t.amount > 0,
                                  ))
                            ],
                          );
                        },
                      ),
              )
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, Color activeColor,
      {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? activeColor : Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: isSelected ? null : Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
                color: Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13),
          ),
          if (isSelected) ...[
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 16)
          ] else if (icon != null) ...[
            const SizedBox(width: 4),
            Icon(icon, color: Colors.white70, size: 16)
          ]
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        title,
        style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildTransactionItem({
    required String title,
    required String subtitle,
    required String amount,
    required String paymentMethod,
    required IconData icon,
    required Color color,
    required bool isIncome,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.transparent, // Minimalist transparent look
        border: Border(
            bottom: BorderSide(
                color: Colors.white.withOpacity(0.05))), // Subtle separator
      ),
      child: Row(
        children: [
          // Leading Icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  const Color(0xFF1E2A32), // Dark card-like background for icon
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),

          // Title & Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ],
            ),
          ),

          // Amount & Payment Method
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                style: TextStyle(
                    color: isIncome
                        ? const Color(0xFF00E5FF)
                        : const Color(
                            0xFFFF5252), // Cyan for income, Red for expense
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                paymentMethod,
                style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 10,
                    fontWeight: FontWeight.w600),
              ),
            ],
          )
        ],
      ),
    );
  }
}
