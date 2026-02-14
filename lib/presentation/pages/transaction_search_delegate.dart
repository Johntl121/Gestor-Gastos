import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/transaction_entity.dart';

class TransactionSearchDelegate extends SearchDelegate {
  final List<TransactionEntity> transactions;

  TransactionSearchDelegate(this.transactions);

  @override
  String get searchFieldLabel => 'Buscar transacciones...';

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF121C22),
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 18),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: Colors.white54),
        border: InputBorder.none,
      ),
      textTheme: theme.textTheme.copyWith(
        titleLarge: const TextStyle(color: Colors.white),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: Colors.white,
        selectionColor: Colors.white24,
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          onPressed: () => query = '',
          icon: const Icon(Icons.clear),
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () => close(context, null),
      icon: const Icon(Icons.arrow_back),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildList();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildList();
  }

  Widget _buildList() {
    final cleanQuery = query.toLowerCase();
    final results = transactions.where((t) {
      final categoryMatch = t.description.toLowerCase().contains(cleanQuery);
      final noteMatch = t.note?.toLowerCase().contains(cleanQuery) ?? false;
      return categoryMatch || noteMatch;
    }).toList();

    if (results.isEmpty) {
      return Container(
        color: const Color(0xFF121C22),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off, size: 60, color: Colors.grey[600]),
              const SizedBox(height: 10),
              Text(
                "No se encontraron gastos",
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              )
            ],
          ),
        ),
      );
    }

    return Container(
      color: const Color(0xFF121C22),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: results.length,
        itemBuilder: (context, index) {
          final t = results[index];
          return _buildTransactionItem(t);
        },
      ),
    );
  }

  Widget _buildTransactionItem(TransactionEntity t) {
    // 1. Logic Setup
    bool isTransfer = t.type == TransactionType.transfer ||
        t.description.toLowerCase().contains('transferencia');
    bool isIncome = t.amount > 0;

    // 2. Colors & Icons
    Color color;
    IconData icon;
    String amountPrefix = "";

    if (isTransfer) {
      color = Colors.white70;
      icon = Icons.swap_horiz;
      amountPrefix = "⇄ ";
    } else if (isIncome) {
      color = Colors.greenAccent;
      icon = Icons.account_balance_wallet;
      amountPrefix = "+ ";
    } else {
      color = Colors.redAccent;
      icon = Icons.shopping_bag;
    }

    // 3. Account Logic
    String accountName = "Efectivo";
    Color accountColor = Colors.amber;
    IconData accountIcon = Icons.payments;

    if (t.accountId == 2) {
      accountName = "Bancaria";
      accountColor = Colors.blueAccent;
      accountIcon = Icons.credit_card;
    } else if (t.accountId == 3) {
      accountName = "Ahorros";
      accountColor = Colors.purpleAccent;
      accountIcon = Icons.savings;
    }

    // 4. Strings
    String title = t.description;
    String subtitle = DateFormat('h:mm a').format(t.date);
    if (t.note != null && t.note!.isNotEmpty) {
      subtitle += " • ${t.note!}";
    } else {
      subtitle += " • ${isIncome ? 'Ingreso' : 'Gasto'}";
    }

    String amountStr = "$amountPrefix S/ ${t.amount.abs().toStringAsFixed(2)}";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border:
            Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          // Leading Icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E2A32),
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

          // Amount & Account Badge
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amountStr,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              // Account Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: accountColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: accountColor.withOpacity(0.3))),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      accountIcon,
                      size: 10,
                      color: accountColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      accountName,
                      style: TextStyle(
                          color: accountColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
