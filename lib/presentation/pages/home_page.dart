import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/budget_mood.dart';
import '../providers/dashboard_provider.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, provider, child) {
        final balance =
            provider.balanceBreakdown?.total ?? 0.00; // Default mock if needed
        final mood = provider.budgetMood;

        // Mock Data specifically requested if no data
        final displayBalance =
            provider.isLoading && provider.balanceBreakdown == null
                ? 2450.00
                : balance;

        return Scaffold(
          backgroundColor:
              const Color(0xFFF8FAFC), // Slight off-white background
          body: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Header: Avatar & Notification
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 20,
                            backgroundImage: NetworkImage(
                                'https://i.pravatar.cc/150?img=1'), // Placeholder avatar
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

                  // Budget Mood Widget (Central Face)
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
                    "S/ ${displayBalance.toStringAsFixed(2)}",
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
                  _buildBudgetCard(),

                  const SizedBox(height: 20),

                  // Income / Expenses Summary
                  Row(
                    children: [
                      Expanded(
                          child: _buildSummaryCard(
                              icon: Icons.arrow_upward,
                              iconColor: Colors.green,
                              backgroundColor:
                                  const Color(0xFFE0F2F1), // Very light teal
                              amount: "+S/ 120.00",
                              label: "Ingresos Hoy")),
                      const SizedBox(width: 15),
                      Expanded(
                          child: _buildSummaryCard(
                              icon: Icons.arrow_downward,
                              iconColor: Colors.redAccent,
                              backgroundColor:
                                  const Color(0xFFFFEBEE), // Very light red
                              amount: "-S/ 45.00",
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

                  // Recent Activity List (Mock)
                  ListView.separated(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: 3,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      return _buildTransactionItem(index);
                    },
                  ),

                  // Bottom padding for FAB
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

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

  Widget _buildBudgetCard() {
    // Mock values for visual adherence
    const double totalBudget = 4000.00;
    const double spent = 1200.00;
    const double progress = spent / totalBudget;

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
                text: const TextSpan(children: [
                  TextSpan(
                      text: "S/ 1,200.00",
                      style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  TextSpan(
                      text: " / S/ 4,000.00",
                      style: TextStyle(color: Colors.grey, fontSize: 14)),
                ]),
              ),
              const Text("70% restante",
                  style: TextStyle(
                      color: Colors.teal, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 15),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade200,
              color: Colors.cyan,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: const [
              Icon(Icons.access_time_filled, size: 14, color: Colors.teal),
              SizedBox(width: 5),
              Text("12 días restantes en el mes",
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

  Widget _buildTransactionItem(int index) {
    // Mock Data List
    final List<Map<String, dynamic>> transactions = [
      {
        'title': 'Supermercado',
        'subtitle': 'Compras • 2:30 PM',
        'amount': '-S/ 32.50',
        'icon': Icons.shopping_cart,
        'color': Colors.blue.shade100,
        'iconColor': Colors.blue,
      },
      {
        'title': 'Cafetería',
        'subtitle': 'Comida y Bebida • 11:15 AM',
        'amount': '-S/ 12.50',
        'icon': Icons.coffee,
        'color': Colors.orange.shade100,
        'iconColor': Colors.orange,
      },
      {
        'title': 'Pago Freelance',
        'subtitle': 'Ingreso • Ayer',
        'amount': '+S/ 120.00',
        'amountColor': Colors.teal,
        'icon': Icons.account_balance_wallet,
        'color': Colors.green.shade100,
        'iconColor': Colors.green,
      },
    ];

    final item = transactions[index];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        // No visual shadow in the image for list items, just white cards maybe?
        // The image has them as detached cards or just rows.
        // Let's make them white cards.
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: item['color'],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(item['icon'], color: item['iconColor'], size: 24),
        ),
        title: Text(item['title'],
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(item['subtitle'],
            style: const TextStyle(color: Colors.grey, fontSize: 12)),
        trailing: Text(item['amount'],
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: item['amountColor'] ?? Colors.black87)),
      ),
    );
  }
}
