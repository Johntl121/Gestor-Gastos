import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/budget_mood.dart';
import '../../domain/entities/transaction_entity.dart';
import '../providers/dashboard_provider.dart';
import 'package:intl/intl.dart';
import 'settings_page.dart';

/// HomePage: Pantalla principal de la aplicación.
/// Muestra el balance general, el estado de ánimo financiero, el progreso del presupuesto
/// y las transacciones recientes.
class HomePage extends StatelessWidget {
  final VoidCallback? onSeeAllPressed;

  const HomePage({super.key, this.onSeeAllPressed});

  @override
  Widget build(BuildContext context) {
    // Usamos Consumer para escuchar cambios en DashboardProvider
    return Consumer<DashboardProvider>(
      builder: (context, provider, child) {
        // Obtener el balance total (o 0.00 si es nulo)
        final balance = provider.balanceBreakdown?.total ?? 0.00;
        final mood = provider.budgetMood;

        // Calcular Ingresos y Gastos de Hoy
        double todayIncome = 0;
        double todayExpense = 0;
        final now = DateTime.now();

        // Calcular Gasto Mensual para el Presupuesto
        double monthSpent = 0;

        for (var t in provider.transactions) {
          // Ignorar transferencias en cálculos de resumen
          if (t.type == TransactionType.transfer) continue;

          // Verificar si la fecha es hoy
          final isToday = t.date.year == now.year &&
              t.date.month == now.month &&
              t.date.day == now.day;

          // Verificar si es del mes actual
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
                  // --- Header: Avatar y Notificaciones ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const SettingsPage()),
                          );
                        },
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 20,
                              backgroundImage: NetworkImage(
                                  'https://i.pravatar.cc/150?img=1'),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Bienvenido,",
                                    style: TextStyle(
                                        color: Colors.teal, fontSize: 12)),
                                Text(provider.userName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                              ],
                            )
                          ],
                        ),
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

                  const SizedBox(height: 30),

                  // Widget de Estado de Ánimo Financiero
                  _buildMoodIndicator(mood),

                  const SizedBox(height: 10),

                  // Saldo Actual
                  const Text("SALDO DISPONIBLE",
                      style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 5),
                  Text(
                    "${provider.currencySymbol} ${balance.toStringAsFixed(2)}",
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

                  // Tarjeta de Presupuesto
                  _buildBudgetCard(provider.budgetLimit, monthSpent,
                      provider.currencySymbol),

                  const SizedBox(height: 20),

                  // Resumen de Ingresos / Gastos
                  Row(
                    children: [
                      Expanded(
                          child: _buildSummaryCard(
                              icon: Icons.arrow_upward,
                              iconColor: Colors.green,
                              backgroundColor: const Color(0xFFE0F2F1),
                              amount:
                                  "+${provider.currencySymbol} ${todayIncome.toStringAsFixed(2)}",
                              label: "Ingresos Hoy")),
                      const SizedBox(width: 15),
                      Expanded(
                          child: _buildSummaryCard(
                              icon: Icons.arrow_downward,
                              iconColor: Colors.redAccent,
                              backgroundColor: const Color(0xFFFFEBEE),
                              amount:
                                  "-${provider.currencySymbol} ${todayExpense.toStringAsFixed(2)}",
                              label: "Gastos Hoy")),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // Cabecera de Actividad Reciente
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Actividad Reciente",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18)),
                      GestureDetector(
                        onTap: onSeeAllPressed,
                        child: const Text("Ver todo",
                            style: TextStyle(
                                color: Colors.teal,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 15),

                  // Lista de Actividad Reciente (Datos Reales)
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
                            return _buildTransactionItem(transaction, provider);
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

  /// Construye el widget del indicador de estado de ánimo (la carita)
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
            color: Colors.cyan.withValues(alpha: 0.1),
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

  /// Retorna una frase motivacional según el estado de ánimo
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

  /// Construye la tarjeta de progreso del presupuesto mensual
  Widget _buildBudgetCard(double limit, double spent, String currency) {
    // Calculamos el progreso (0.0 a 1.0)
    final progress = (limit > 0) ? (spent / limit).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
                      text: "$currency ${spent.toStringAsFixed(2)}",
                      style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  TextSpan(
                      text: " / $currency ${limit.toStringAsFixed(2)}",
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
          const Row(
            children: [
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

  /// Construye las tarjetas pequeñas de resumen (Ingresos/Gastos de hoy)
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

  /// Construye un item individual de la lista de transacciones con el Nuevo Estilo
  Widget _buildTransactionItem(
      TransactionEntity t, DashboardProvider provider) {
    // 1. Logic for Transfer & Legacy Fix
    bool isTransfer = t.type == TransactionType.transfer ||
        t.description.toLowerCase().contains('transferencia');

    // 2. Data Preparation
    String title = t.description;
    String subtitle = DateFormat('h:mm a').format(t.date);
    String symbol = provider.currencySymbol;
    String absAmount = t.amount.abs().toStringAsFixed(2);

    String amountFormatted;
    Color color;
    IconData icon;
    bool isIncome = t.amount > 0;

    if (isTransfer) {
      final source = provider.getAccountName(t.accountId);
      final dest = t.destinationAccountId != null
          ? provider.getAccountName(t.destinationAccountId!)
          : 'Destino';

      title = t.description.isNotEmpty ? t.description : "Transferencia";
      subtitle = "${DateFormat('h:mm a').format(t.date)} • $source ➔ $dest";

      amountFormatted = "⇄ $symbol $absAmount";
      color = const Color(0xFF64B5F6); // Soft Blue
      icon = Icons.swap_horiz;
    } else {
      amountFormatted = "${isIncome ? '+' : '-'} $symbol $absAmount";
      color = isIncome
          ? Colors.green // Darker green for readability on white
          : Colors.redAccent;
      icon = isIncome ? Icons.account_balance_wallet : Icons.shopping_bag;

      if (t.note != null && t.note!.isNotEmpty) {
        subtitle += " • ${t.note!}";
      } else {
        subtitle += " • ${isIncome ? 'Ingreso' : 'Gasto'}";
      }
    }

    // 3. Render
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            offset: const Offset(0, 4),
            blurRadius: 10,
          )
        ],
      ),
      child: Row(
        children: [
          // Icon Box
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isIncome && !isTransfer)
                  ? Colors.greenAccent.withValues(alpha: 0.15)
                  : color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon,
                color: (isIncome && !isTransfer) ? Colors.greenAccent : color,
                size: 24),
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
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.black87),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Amount
          Text(
            amountFormatted,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16, color: color),
          ),
        ],
      ),
    );
  }
}
