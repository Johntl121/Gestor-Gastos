import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/budget_mood.dart';
import '../../domain/entities/transaction_entity.dart';
import '../providers/dashboard_provider.dart';
import 'package:intl/intl.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, provider, child) {
        final balance = provider.balanceBreakdown?.total ?? 0.00;
        final mood = provider.budgetMood;

        // Calculate Today's Income/Expense
        double todayIncome = 0;
        double todayExpense = 0;
        final now = DateTime.now();

        // Calculate Monthly Spent for Budget
        double monthSpent = 0;

        for (var t in provider.transactions) {
          final isToday = t.date.year == now.year &&
              t.date.month == now.month &&
              t.date.day == now.day;

          final isSameMonth =
              t.date.year == now.year && t.date.month == now.month;

          if (isToday) {
            if (t.amount > 0) {
              todayIncome += t.amount;
            } else {
              todayExpense += t.amount.abs();
            }
          }

          if (isSameMonth && t.amount < 0) {
            monthSpent += t.amount.abs();
          }
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // --- Header Code Omitted for Brevity (Same as before) ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 20,
                            backgroundImage:
                                NetworkImage('https://i.pravatar.cc/150?img=1'),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text("Bienvenido,",
                                  style: TextStyle(
                                      color: Colors.teal, fontSize: 12)),
                              Text("Alex",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                            ],
                          )
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.notifications_none,
                            color: Colors.black54),
                      )
                    ],
                  ),

                  const SizedBox(height: 30),

                  // Budget Mood Widget
                  _buildMoodIndicator(mood),

                  const SizedBox(height: 10),

                  // Balance
                  const Text("SALDO DISPONIBLE",
                      style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 5),
                  Text(
                    "S/ ${balance.toStringAsFixed(2)}",
                    style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _getMoodQuote(mood),
                    style: const TextStyle(
                        color: Colors.teal, fontStyle: FontStyle.italic),
                  ),

                  const SizedBox(height: 30),

                  // Budget Card
                  _buildBudgetCard(provider.budgetLimit, monthSpent),

                  const SizedBox(height: 20),

                  // Income / Expenses Summary
                  Row(
                    children: [
                      Expanded(
                          child: _buildSummaryCard(
                              icon: Icons.arrow_upward,
                              iconColor: Colors.green,
                              backgroundColor: const Color(0xFFE0F2F1),
                              amount: "+S/ ${todayIncome.toStringAsFixed(2)}",
                              label: "Ingresos Hoy")),
                      const SizedBox(width: 15),
                      Expanded(
                          child: _buildSummaryCard(
                              icon: Icons.arrow_downward,
                              iconColor: Colors.redAccent,
                              backgroundColor: const Color(0xFFFFEBEE),
                              amount: "-S/ ${todayExpense.toStringAsFixed(2)}",
                              label: "Gastos Hoy")),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // Recent Activity Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text("Actividad Reciente",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18)),
                      Text("Ver todo",
                          style: TextStyle(
                              color: Colors.teal, fontWeight: FontWeight.w600)),
                    ],
                  ),

                  const SizedBox(height: 15),

                  // Recent Activity List (Real Data)
                  provider.transactions.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(20),
                          child: Text("No hay transacciones recientes",
                              style: TextStyle(color: Colors.grey)),
                        )
                      : ListView.separated(
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          itemCount: provider.transactions.take(3).length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final transaction = provider.transactions[index];
                            return _buildTransactionItem(transaction);
                          },
                        ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ... (Mood Indicator & Quote methods remain same) ...
  Widget _buildMoodIndicator(BudgetMood mood) {
    IconData icon;
    Color color;

    switch (mood) {
      case BudgetMood.happy:
        icon = Icons.sentiment_very_satisfied_rounded;
        color = Colors.amber.shade600;
        break;
      case BudgetMood.neutral:
        icon = Icons.sentiment_neutral_rounded;
        color = Colors.amber.shade300;
        break;
      case BudgetMood.sad:
        icon = Icons.sentiment_very_dissatisfied_rounded;
        color = Colors.redAccent;
        break;
    }

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.cyan.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 60, color: color),
        ),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
          child: const Icon(Icons.edit, size: 14, color: Colors.teal),
        )
      ],
    );
  }

  String _getMoodQuote(BudgetMood mood) {
    switch (mood) {
      case BudgetMood.happy:
        return "\"¡Te sientes genial hoy!\"";
      case BudgetMood.neutral:
        return "\"Todo marcha bien.\"";
      case BudgetMood.sad:
        return "\"Cuidado con los gastos.\"";
    }
  }

  Widget _buildBudgetCard(double limit, double spent) {
    final progress = (limit > 0) ? (spent / limit).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 4),
            blurRadius: 10,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("PRESUPUESTO MENSUAL",
              style: TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              RichText(
                text: TextSpan(children: [
                  TextSpan(
                      text: "S/ ${spent.toStringAsFixed(2)}",
                      style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  TextSpan(
                      text: " / S/ ${limit.toStringAsFixed(2)}",
                      style: const TextStyle(color: Colors.grey, fontSize: 14)),
                ]),
              ),
              Text("${((1 - progress) * 100).toInt()}% restante",
                  style: const TextStyle(
                      color: Colors.teal, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 15),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade200,
              color: progress > 0.9 ? Colors.redAccent : Colors.cyan,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: const [
              Icon(Icons.access_time_filled, size: 14, color: Colors.teal),
              SizedBox(width: 5),
              Text("Calculado al día de hoy", // Simplificado
                  style: TextStyle(color: Colors.teal, fontSize: 12))
            ],
          )
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
      {required IconData icon,
      required Color iconColor,
      required Color backgroundColor,
      required String amount,
      required String label}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12, blurRadius: 5, offset: Offset(0, 2))
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 12),
          Text(amount,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(TransactionEntity transaction) {
    final isExpense = transaction.amount < 0;
    final amountColor = isExpense ? Colors.black87 : Colors.teal;
    final icon = isExpense ? Icons.shopping_cart : Icons.account_balance_wallet;
    final color = isExpense ? Colors.orange.shade100 : Colors.green.shade100;
    final iconColor = isExpense ? Colors.orange : Colors.green;

    // TODO: Map categoryId to real icons/colors

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        title: Text(transaction.description,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(DateFormat('MMM d, h:mm a').format(transaction.date),
            style: const TextStyle(color: Colors.grey, fontSize: 12)),
        trailing: Text("S/ ${transaction.amount.toStringAsFixed(2)}",
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16, color: amountColor)),
      ),
    );
  }
}
