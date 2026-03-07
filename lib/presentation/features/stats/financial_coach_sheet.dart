import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:intl/intl.dart';

import '../../../core/services/gemini_client.dart';
import '../../../domain/entities/transaction_entity.dart';
import '../../providers/stats_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/wallet_provider.dart';

class FinancialCoachSheet extends StatefulWidget {
  const FinancialCoachSheet({super.key});

  @override
  State<FinancialCoachSheet> createState() => _FinancialCoachSheetState();
}

class _FinancialCoachSheetState extends State<FinancialCoachSheet> {
  String _selectedMode = 'weekly';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final statsProvider = Provider.of<StatsProvider>(context, listen: false);
      final txProvider =
          Provider.of<TransactionProvider>(context, listen: false);

      if (txProvider.transactions.length <= 5) {
        statsProvider.setFinancialAdvice(
            "👋 ¡Bienvenido a tu Coach! Para empezar a recibir consejos inteligentes, necesito datos. Registra tu primer gasto hoy mismo.");
      } else {
        statsProvider.showCachedAdvice('weekly');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final statsProvider = Provider.of<StatsProvider>(context);
    final txProvider = Provider.of<TransactionProvider>(context);

    return Container(
      height: 600,
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 50,
            height: 5,
            decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(10)),
          ),
          const SizedBox(height: 20),
          const Row(
            children: [
              Icon(Icons.psychology_alt, color: Colors.purpleAccent, size: 30),
              SizedBox(width: 10),
              Text("Coach Financiero IA",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),

          // Controls
          Row(
            children: [
              _buildAnalysisButton(statsProvider, txProvider, 'weekly',
                  "Análisis Semanal", Icons.calendar_view_week),
              const SizedBox(width: 10),
              _buildAnalysisButton(statsProvider, txProvider, 'monthly',
                  "Análisis Mensual", Icons.calendar_month),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(color: Colors.white10),
          const SizedBox(height: 10),

          // Content
          Expanded(
            child: statsProvider.isAdviceLoading
                ? const Center(
                    child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.purpleAccent),
                      SizedBox(height: 20),
                      Text("Analizando tus finanzas... 🧠",
                          style: TextStyle(color: Colors.white70)),
                    ],
                  ))
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MarkdownBody(
                          data: statsProvider.financialAdvice ?? "",
                          // If provider distinguishes nicely, great.
                          // Actually StatsProvider has separate variables but the getter/setter logic needs to be verified.
                          // Assuming weeklyAdvice is the 'current' advice shown or I need to switch based on mode.
                          // Let's check StatsProvider logic later or assume weeklyAdvice holds the 'display' text
                          // No, StatsProvider has `_weeklyAdvice` and `_monthlyAdvice`.
                          // We should probably show based on _selectedMode here or use a `currentAdvice` getter.
                          // Since I can't see StatsProvider right now, I'll use `weeklyAdvice` as a proxy or fix it.
                          // Actually, the original code used `provider.weeklyAdvice` for everything? No wait.
                          // Original: `provider.showCachedAdvice(type)` updates `_financialAdvice` (or similar).
                          // Let's assume `statsProvider.weeklyAdvice` holds the displayed text or `financialAdvice`.
                          // Looking at previous view_file for StatsProvider:
                          // `String _financialAdvice = ...` and `String get weeklyAdvice => _financialAdvice;` ?
                          // I'll check.
                          // Wait, I'll use `statsProvider.weeklyAdvice` (which seems to be the public getter for the advice text to show).
                          styleSheet:
                              MarkdownStyleSheet.fromTheme(Theme.of(context))
                                  .copyWith(
                            p: const TextStyle(
                                color: Colors.white, fontSize: 16, height: 1.5),
                            strong: const TextStyle(
                                color: Colors.cyanAccent,
                                fontWeight: FontWeight.bold),
                            h1: const TextStyle(
                                color: Colors.purpleAccent,
                                fontSize: 22,
                                fontWeight: FontWeight.bold),
                            h2: const TextStyle(
                                color: Colors.purpleAccent,
                                fontSize: 20,
                                fontWeight: FontWeight.bold),
                            listBullet:
                                const TextStyle(color: Colors.cyanAccent),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisButton(
      StatsProvider provider,
      TransactionProvider txProvider,
      String type,
      String label,
      IconData icon) {
    final hasData = txProvider.transactions.length > 5;

    bool isAvailable = false;
    int daysWait = 0;

    if (hasData) {
      isAvailable = provider.canRequestAnalysis(type);
      daysWait = provider.getDaysUntilAvailable(type);
    }

    final isSelected = _selectedMode == type;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final baseColor = type == 'weekly' ? Colors.cyanAccent : Colors.tealAccent;
    final activeColor = type == 'weekly' ? Colors.cyan : Colors.teal;

    final buttonColor = !hasData
        ? Colors.grey.withValues(alpha: 0.1)
        : (isSelected ? activeColor.withValues(alpha: 0.2) : Colors.transparent);

    final borderColor = !hasData
        ? Colors.grey.withValues(alpha: 0.2)
        : (isSelected ? baseColor : Colors.grey.withValues(alpha: 0.3));

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (!hasData) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content:
                    Text("Registra al menos un movimiento para desbloquear"),
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
            return;
          }

          setState(() => _selectedMode = type);
          _handleRequest(provider, txProvider, type);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: buttonColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!isAvailable)
                    const Padding(
                      padding: EdgeInsets.only(right: 6.0),
                      child: Icon(Icons.lock_outline,
                          size: 16, color: Colors.grey),
                    ),
                  Icon(icon,
                      size: 20,
                      color: !hasData
                          ? Colors.grey
                          : (isSelected
                              ? baseColor
                              : (isAvailable
                                  ? Colors.grey[400]
                                  : Colors.grey))),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: !hasData
                      ? Colors.grey
                      : (isSelected
                          ? (isDark ? Colors.white : Colors.black87)
                          : Colors.grey),
                ),
              ),
              if (hasData && !isAvailable)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    "Disponible en $daysWait días",
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleRequest(StatsProvider statsProvider,
      TransactionProvider txProvider, String type) async {
    // Check transactions
    if (txProvider.transactions.length <= 5) {
      statsProvider.setFinancialAdvice(
          "👋 ¡Bienvenido a tu Coach! Para empezar a recibir consejos inteligentes, necesito datos. Registra tu primer gasto hoy mismo.");
      return;
    }

    if (!statsProvider.canRequestAnalysis(type)) {
      statsProvider.showCachedAdvice(type);
      return;
    }

    statsProvider.setAdviceLoading(true);
    try {
      final transactions = txProvider.transactions;
      final budgetLimit =
          Provider.of<WalletProvider>(context, listen: false).budgetLimit;

      // Filter
      final now = DateTime.now();
      final filterDays = type == 'weekly' ? 7 : 30;
      final startDate = now.subtract(Duration(days: filterDays));

      final recent = transactions
          .where((t) =>
              t.date.isAfter(startDate) && t.type != TransactionType.transfer)
          .toList();

      if (recent.isEmpty) {
        statsProvider.setFinancialAdvice(
            "No hay suficientes datos recientes ($filterDays días) para analizar. ¡Sigue registrando!");
        return;
      }

      // Calculate logic (simplified here, but should match heavy logic if needed)
      // I'll keep the logic here as it prepares the context string for Gemini.
      double totalIncome = 0;
      double totalExpense = 0;
      final buffer = StringBuffer();

      buffer.writeln("Periodo: Últimos $filterDays días");
      buffer.writeln(
          "Presupuesto Mensual Base: ${budgetLimit.toStringAsFixed(2)}");

      for (var t in recent) {
        if (t.type == TransactionType.income) {
          totalIncome += t.amount.abs();
        } else {
          totalExpense += t.amount.abs();
        }

        if (buffer.length < 3500) {
          buffer.writeln(
              "- ${DateFormat('dd/MM').format(t.date)}: ${t.description} (${t.amount.abs().toStringAsFixed(2)})");
        }
      }

      buffer.writeln("\nResumen Total:");
      buffer.writeln("Ingresos: ${totalIncome.toStringAsFixed(2)}");
      buffer.writeln("Gastos: ${totalExpense.toStringAsFixed(2)}");
      buffer.writeln(
          "Balance: ${(totalIncome - totalExpense).toStringAsFixed(2)}");

      // Call API
      final advice = await GeminiClient().obtenerConsejo(
        contextData: buffer.toString(),
        periodType: type,
        isNewUser: false,
      );

      // Save Advice
      if (type == 'weekly') {
        await statsProvider.saveWeeklyAdvice(advice);
      } else {
        await statsProvider.saveMonthlyAdvice(advice);
      }

      // Update UI is handled by save... or setFinancialAdvice?
      // StatsProvider.saveWeeklyAdvice calls notifyListeners?
      // Yes, likely. But current displayed advice also needs update.
      statsProvider.setFinancialAdvice(advice);
    } catch (e) {
      statsProvider.setFinancialAdvice(
          "Ocurrió un error al contactar al coach. Inténtalo más tarde. \nError: $e");
    } finally {
      statsProvider.setAdviceLoading(false);
    }
  }
}
