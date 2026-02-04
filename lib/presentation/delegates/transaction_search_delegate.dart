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
    final isIncome = t.amount > 0;
    final color = isIncome ? Colors.teal.shade300 : Colors.orange.shade300;
    final icon = isIncome ? Icons.account_balance_wallet : Icons.shopping_bag;
    final amount =
        "${isIncome ? '+' : ''}S/ ${t.amount.toStringAsFixed(2)}"; // Hardcoded currency for search delegate simpler for now or pass it.
    // Ideally we pass currency symbol too, but "S/" is fine if app is single currency.
    // Or we could pass 'currencySymbol' in constructor.

    final subtitle = t.note != null && t.note!.isNotEmpty
        ? "${DateFormat('h:mm a').format(t.date)} • ${t.note!}"
        : "${DateFormat('h:mm a').format(t.date)} • ${isIncome ? 'Ingreso' : 'Gasto'}";

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
                  t.description,
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
                        : const Color(0xFFFF5252),
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
              const SizedBox(height: 4),
              const Text(
                "CASH",
                style: TextStyle(
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
