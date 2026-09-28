import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../domain/entities/transaction_entity.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../providers/wallet_provider.dart';
import '../../../providers/transaction_provider.dart';

class DonutChartSection extends StatelessWidget {
  const DonutChartSection({super.key});

  Widget _buildMoodIndicator(double limit, double spent, bool isDarkMode) {
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
            color: Colors.cyan.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 60, color: color),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Consumer2<WalletProvider, TransactionProvider>(
      builder: (context, walletProvider, txProvider, _) {
        final currency = walletProvider.currencySymbol;
        final budgetLimit = walletProvider.budgetLimit;

        double monthSpent = 0;
        final now = DateTime.now();

        for (var t in txProvider.transactions) {
          if (t.type == TransactionType.transfer) continue;
          final isSameMonth =
              t.date.year == now.year && t.date.month == now.month;

          if (isSameMonth && t.amount < 0) {
            final accList =
                walletProvider.accounts.where((a) => a.id == t.accountId);
            final acc = accList.isNotEmpty ? accList.first : null;

            final sourceRate =
                walletProvider.exchangeRates[acc?.currencySymbol ?? 'S/'] ??
                    1.0;
            final targetRate = walletProvider.exchangeRates[currency] ?? 1.0;
            monthSpent += (t.amount.abs() * sourceRate) / targetRate;
          }
        }

        return Column(
          children: [
            _buildMoodIndicator(budgetLimit, monthSpent, isDarkMode),
          ],
        );
      },
    );
  }
}


class BalanceSummary extends StatelessWidget {
  const BalanceSummary({super.key});

  String _getMoodQuote(double limit, double spent) {
    if (limit == 0) return "Define un presupuesto.";
    final percent = (limit - spent) / limit;

    if (percent > 0.50) return "\"¡Estás en la cima! Sigue así.\"";
    if (percent > 0.20) return "\"Todo en orden, pero mantente atento.\"";
    return "\"¡Alerta roja! Presupuesto excedido.\"";
  }

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

  Widget _buildBudgetCard(
      BuildContext context, double limit, double spent, String currency) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

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
            color: isDarkMode
                ? Colors.black45
                : Colors.black.withValues(alpha: 0.05),
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
              Text("Calculado al día de hoy",
                  style: TextStyle(color: Colors.tealAccent, fontSize: 12))
            ],
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.white;
    final subTextColor = isDarkMode ? Colors.blueGrey[200] : Colors.grey[600];

    return Consumer2<WalletProvider, TransactionProvider>(
      builder: (context, walletProvider, txProvider, _) {
        final currency = walletProvider.currencySymbol;
        final balance = walletProvider.totalBalance;
        final budgetLimit = walletProvider.budgetLimit;

        double todayIncome = 0;
        double todayExpense = 0;
        double monthSpent = 0;
        final now = DateTime.now();

        for (var t in txProvider.transactions) {
          if (t.type == TransactionType.transfer) continue;

          final isToday = t.date.year == now.year &&
              t.date.month == now.month &&
              t.date.day == now.day;

          final isSameMonth =
              t.date.year == now.year && t.date.month == now.month;

          if (isToday) {
            final accList =
                walletProvider.accounts.where((a) => a.id == t.accountId);
            final acc = accList.isNotEmpty ? accList.first : null;

            final sourceRate =
                walletProvider.exchangeRates[acc?.currencySymbol ?? 'S/'] ??
                    1.0;
            final targetRate = walletProvider.exchangeRates[currency] ?? 1.0;
            final convertedAmount = (t.amount * sourceRate) / targetRate;

            if (t.amount > 0) {
              todayIncome += convertedAmount;
            } else {
              todayExpense += convertedAmount.abs();
            }
          }

          if (isSameMonth && t.amount < 0) {
            final accList =
                walletProvider.accounts.where((a) => a.id == t.accountId);
            final acc = accList.isNotEmpty ? accList.first : null;

            final sourceRate =
                walletProvider.exchangeRates[acc?.currencySymbol ?? 'S/'] ??
                    1.0;
            final targetRate = walletProvider.exchangeRates[currency] ?? 1.0;
            monthSpent += (t.amount.abs() * sourceRate) / targetRate;
          }
        }

        return Column(
          children: [
            Text(AppStrings.homeAvailableBalance.toUpperCase(),
                style: TextStyle(
                    color: subTextColor,
                    fontSize: 12,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 5),
            Text(
              CurrencyFormatter.format(balance, currency),
              style: TextStyle(
                  fontSize: 32, fontWeight: FontWeight.w900, color: textColor),
            ),
            const SizedBox(height: 5),
            Text(
              _getMoodQuote(budgetLimit, monthSpent),
              style: TextStyle(
                  color: Colors.cyanAccent.withValues(alpha: 0.8),
                  fontStyle: FontStyle.italic,
                  fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              "⚠️ Totales convertidos a $currency",
              style: TextStyle(
                  color: Colors.orangeAccent.withValues(alpha: 0.8),
                  fontSize: 10,
                  fontWeight: FontWeight.w500),
            ),

            const SizedBox(height: 30),

            // Budget Card
            _buildBudgetCard(context, budgetLimit, monthSpent, currency),

            const SizedBox(height: 20),

            // Summary Cards
            Row(
              children: [
                Expanded(
                    child: _buildSummaryCard(
                        icon: Icons.arrow_upward,
                        iconColor:
                            isDarkMode ? Colors.greenAccent : Colors.green,
                        backgroundColor: isDarkMode
                            ? Colors.greenAccent.withValues(alpha: 0.1)
                            : const Color(0xFFE0F2F1),
                        amount: CurrencyFormatter.formatWithSign(
                            todayIncome, currency),
                        label: "Ingresos Hoy",
                        context: context)),
                const SizedBox(width: 15),
                Expanded(
                    child: _buildSummaryCard(
                        icon: Icons.arrow_downward,
                        iconColor: Colors.redAccent,
                        backgroundColor: isDarkMode
                            ? Colors.redAccent.withValues(alpha: 0.1)
                            : const Color(0xFFFFEBEE),
                        amount: CurrencyFormatter.formatWithSign(
                            -todayExpense, currency),
                        label: "Gastos Hoy",
                        context: context)),
              ],
            ),
          ],
        );
      },
    );
  }
}

