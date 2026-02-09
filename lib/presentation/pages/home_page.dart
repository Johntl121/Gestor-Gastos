import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
        final balance = provider.totalBalance;

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

        // Theme Logic from Context
        final theme = Theme.of(context);
        final isDarkMode = theme.brightness == Brightness.dark;

        final backgroundColor = theme.scaffoldBackgroundColor;
        final textColor = theme.textTheme.bodyLarge?.color ?? Colors.white;
        final subTextColor =
            isDarkMode ? Colors.blueGrey[200] : Colors.grey[600];

        return Scaffold(
          backgroundColor: backgroundColor,
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
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.cyanAccent,
                                  width: 2,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 20,
                                backgroundColor: Colors.transparent,
                                child: Text(provider.userAvatar,
                                    style: const TextStyle(
                                        fontSize: 28)), // Slightly larger
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Bienvenido,",
                                    style: TextStyle(
                                        color: Colors.teal, fontSize: 12)),
                                Text(provider.userName,
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: textColor)),
                              ],
                            )
                          ],
                        ),
                      ),

                      // Campana de Notificaciones
                      GestureDetector(
                        onTap: () => _showNotificationSheet(context),
                        child: Stack(
                          alignment: Alignment.topRight,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isDarkMode
                                    ? Colors.white.withOpacity(0.1)
                                    : Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.notifications_none,
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.black54),
                            ),
                            // Red Dot if pending
                            if (_hasPendingNotifications(provider))
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                ),
                              )
                          ],
                        ),
                      )
                    ],
                  ),

                  const SizedBox(height: 30),

                  // Widget de Estado de Ánimo Financiero (Clásico)
                  _buildMoodIndicator(
                      provider.budgetLimit, monthSpent, isDarkMode),

                  const SizedBox(height: 10),

                  // Saldo Actual
                  Text("SALDO DISPONIBLE",
                      style: TextStyle(
                          color: subTextColor,
                          fontSize: 12,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 5),
                  Text(
                    "${provider.currencySymbol} ${balance.toStringAsFixed(2)}",
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: textColor),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _getMoodQuote(provider.budgetLimit, monthSpent),
                    style: TextStyle(
                        color: Colors.cyanAccent.withOpacity(0.8),
                        fontStyle: FontStyle.italic,
                        fontSize: 13),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    "⚠️ Totales estimados en S/",
                    style: TextStyle(color: Colors.orangeAccent, fontSize: 10),
                  ),

                  const SizedBox(height: 30),

                  // Tarjeta de Presupuesto
                  _buildBudgetCard(context, provider.budgetLimit, monthSpent,
                      provider.currencySymbol),

                  const SizedBox(height: 20),

                  // Resumen de Ingresos / Gastos
                  Row(
                    children: [
                      Expanded(
                          child: _buildSummaryCard(
                              icon: Icons.arrow_upward,
                              iconColor: isDarkMode
                                  ? Colors.greenAccent
                                  : Colors.green,
                              backgroundColor: isDarkMode
                                  ? Colors.greenAccent.withOpacity(0.1)
                                  : const Color(0xFFE0F2F1),
                              amount:
                                  "+${provider.currencySymbol} ${todayIncome.toStringAsFixed(2)}",
                              label: "Ingresos Hoy",
                              context: context)),
                      const SizedBox(width: 15),
                      Expanded(
                          child: _buildSummaryCard(
                              icon: Icons.arrow_downward,
                              iconColor: Colors.redAccent,
                              backgroundColor: isDarkMode
                                  ? Colors.redAccent.withOpacity(0.1)
                                  : const Color(0xFFFFEBEE),
                              amount:
                                  "-${provider.currencySymbol} ${todayExpense.toStringAsFixed(2)}",
                              label: "Gastos Hoy",
                              context: context)),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // Cabecera de Actividad Reciente
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Actividad Reciente",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: textColor)),
                      GestureDetector(
                        onTap: onSeeAllPressed,
                        child: const Text("Ver todo",
                            style: TextStyle(
                                color: Colors.tealAccent,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 15),

                  // Lista de Actividad Reciente (Datos Reales)
                  provider.transactions.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text("No hay transacciones recientes",
                              style: TextStyle(color: subTextColor)),
                        )
                      : ListView.separated(
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          itemCount: provider.transactions.take(3).length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final transaction = provider.transactions[index];
                            return Dismissible(
                              key: Key(transaction.id.toString()),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(Icons.delete,
                                    color: Colors.white),
                              ),
                              onDismissed: (_) {
                                final deleted = transaction;
                                if (transaction.id != null) {
                                  provider.deleteTransaction(transaction.id!);
                                  ScaffoldMessenger.of(context)
                                      .clearSnackBars();
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(
                                    content: const Text(
                                        'Transacción eliminada de recientes'),
                                    action: SnackBarAction(
                                      label: 'DESHACER',
                                      textColor: Colors.cyanAccent,
                                      onPressed: () {
                                        provider.addTransaction(deleted);
                                      },
                                    ),
                                    duration: const Duration(seconds: 4),
                                  ));
                                }
                              },
                              child: _buildTransactionItem(
                                  transaction, provider, context),
                            );
                          },
                        ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Construye el widget del indicador de estado de ánimo (la carita)
  /// Estilo Clásico con 3 fases
  Widget _buildMoodIndicator(double limit, double spent, bool isDarkMode) {
    // 1. Calculate Health Percentage
    final remaining = (limit - spent).clamp(0, limit);
    final percent = (limit > 0) ? (remaining / limit) : 0.0;

    IconData icon;
    Color color;

    if (percent > 0.50) {
      icon = Icons.sentiment_very_satisfied_rounded;
      color = Colors.greenAccent.shade700;
    } else if (percent > 0.20) {
      icon = Icons.sentiment_neutral_rounded;
      color = Colors.amber.shade300;
    } else {
      icon = Icons.sentiment_very_dissatisfied_rounded;
      color = Colors.redAccent;
    }

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDarkMode
                ? Colors.cyan.withOpacity(0.1)
                : Colors.cyan.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 60, color: color),
        ),
      ],
    );
  }

  /// Retorna una frase motivacional basada en % de presupuesto
  String _getMoodQuote(double limit, double spent) {
    if (limit == 0) return "Define un presupuesto.";
    final percent = (limit - spent) / limit;

    if (percent > 0.50) return "\"¡Estás en la cima! Sigue así.\"";
    if (percent > 0.20) return "\"Todo en orden, pero mantente atento.\"";
    return "\"¡Alerta roja! Presupuesto excedido.\"";
  }

  // --- Notification Logic ---
  bool _hasPendingNotifications(DashboardProvider provider) {
    // Check subscriptions due in <= 3 days or overdue
    final now = DateTime.now();
    for (var sub in provider.subscriptions) {
      if (sub.isPaidThisMonth) continue;

      // Simplified check: if day of month is close
      final dueDay = sub.renewalDay;
      final currentDay = now.day;

      // Handle end of month wrap logic simply:
      if (currentDay >= dueDay) return true; // Overdue this month
      if (dueDay - currentDay <= 3) return true; // Due soon
    }
    return false;
  }

  void _showNotificationSheet(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final subs =
        provider.subscriptions.where((s) => !s.isPaidThisMonth).toList();

    showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF1E2A32),
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) {
          return Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Notificaciones",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                if (subs.isEmpty)
                  const Text("¡Todo al día! No tienes pagos pendientes.",
                      style: TextStyle(color: Colors.grey))
                else
                  ...subs.map((s) => ListTile(
                        leading: const Icon(Icons.warning_amber_rounded,
                            color: Colors.orangeAccent),
                        title: Text("Pago próximo: ${s.name}",
                            style: const TextStyle(color: Colors.white)),
                        subtitle: Text("Vence el día ${s.renewalDay}",
                            style: const TextStyle(color: Colors.grey)),
                        trailing: Text("S/ ${s.amount}",
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ))
              ],
            ),
          );
        });
  }

  /// Construye la tarjeta de progreso del presupuesto mensual
  Widget _buildBudgetCard(
      BuildContext context, double limit, double spent, String currency) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Calculamos el progreso (0.0 a 1.0)
    final progress = (limit > 0) ? (spent / limit).clamp(0.0, 1.0) : 0.0;
    final cardColor = theme.cardColor;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final subTextColor = isDarkMode ? Colors.blueGrey[200] : Colors.grey[600];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDarkMode ? Colors.black45 : Colors.black.withOpacity(0.05),
            offset: const Offset(0, 4),
            blurRadius: 10,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("PRESUPUESTO MENSUAL",
              style: TextStyle(
                  color: subTextColor,
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
                      style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  TextSpan(
                      text: " / $currency ${limit.toStringAsFixed(2)}",
                      style: TextStyle(color: subTextColor, fontSize: 14)),
                ]),
              ),
              Text("${((1 - progress) * 100).toInt()}% restante",
                  style: const TextStyle(
                      color: Colors.tealAccent, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 15),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor:
                  isDarkMode ? Colors.white10 : Colors.grey.shade200,
              color: progress > 0.9 ? Colors.redAccent : Colors.cyan,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 15),
          const Row(
            children: [
              Icon(Icons.access_time_filled,
                  size: 14, color: Colors.tealAccent),
              SizedBox(width: 5),
              Text("Calculado al día de hoy", // Simplificado
                  style: TextStyle(color: Colors.tealAccent, fontSize: 12))
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
      required String label,
      required BuildContext context}) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final cardColor = theme.cardColor;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final subTextColor = isDarkMode ? Colors.blueGrey[200] : Colors.grey[600];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: isDarkMode
              ? Border.all(color: Colors.white10)
              : Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
                color: isDarkMode ? Colors.black45 : Colors.black12,
                blurRadius: 5,
                offset: const Offset(0, 2))
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
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: subTextColor, fontSize: 12)),
        ],
      ),
    );
  }

  /// Construye un item individual de la lista de transacciones con el Nuevo Estilo
  Widget _buildTransactionItem(
      TransactionEntity t, DashboardProvider provider, BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

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

    final cardColor = theme.cardColor;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black87;
    final subTextColor = isDarkMode ? Colors.blueGrey[200] : Colors.grey[600];

    if (isTransfer) {
      final source = provider.getAccountName(t.accountId);
      final dest = t.destinationAccountId != null
          ? provider.getAccountName(t.destinationAccountId!)
          : 'Destino';

      title = t.description.isNotEmpty ? t.description : "Transferencia";
      subtitle = "${DateFormat('h:mm a').format(t.date)} • $source ➔ $dest";

      amountFormatted = "⇄ $symbol $absAmount";
      color = isDarkMode
          ? Colors.white70
          : const Color(0xFF64B5F6); // Soft Blue or white
      icon = Icons.swap_horiz;
    } else {
      amountFormatted = "${isIncome ? '+' : '-'} $symbol $absAmount";
      color = isIncome
          ? (isDarkMode
              ? Colors.greenAccent
              : Colors.green) // Darker green for readability on white
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
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isDarkMode
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    offset: const Offset(0, 4),
                    blurRadius: 10,
                  )
                ]),
      child: Row(
        children: [
          // Icon Box
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isIncome && !isTransfer)
                  ? (isDarkMode
                      ? Colors.greenAccent.withOpacity(0.15)
                      : Colors.greenAccent.withOpacity(0.15))
                  : color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon,
                color: (isIncome && !isTransfer)
                    ? (isDarkMode ? Colors.greenAccent : Colors.green)
                    : color,
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
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: textColor),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: subTextColor, fontSize: 12),
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
