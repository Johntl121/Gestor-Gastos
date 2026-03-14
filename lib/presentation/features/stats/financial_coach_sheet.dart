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
    // El initState solo establece el modo por defecto.
    // La UI lee directamente del Provider via currentAdvice(_selectedMode).
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
                : _buildAdviceContent(statsProvider, txProvider),
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

  /// Construye el contenido según si hay advice guardado o no
  Widget _buildAdviceContent(StatsProvider statsProvider, TransactionProvider txProvider) {
    final hasMinData = txProvider.transactions.length > 5;

    if (!hasMinData) {
      return _buildPlaceholder(
        icon: Icons.bar_chart_outlined,
        message: "Registra al menos 5 movimientos para recibir tu primer análisis.",
        sub: "Cuantos más datos tengas, más preciso será el coach.",
      );
    }

    final advice = statsProvider.currentAdvice(_selectedMode);

    if (advice == null || advice.isEmpty) {
      final isWeekly = _selectedMode == 'weekly';
      return _buildPlaceholder(
        icon: isWeekly ? Icons.calendar_view_week : Icons.calendar_month,
        message: isWeekly
            ? "Todavía no has generado tu análisis de esta semana."
            : "Todavía no has generado tu análisis de este mes.",
        sub: "Toca el botón de arriba para obtener tu primer reporte.",
      );
    }

    return SingleChildScrollView(
      child: MarkdownBody(
        data: advice,
        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
          p: const TextStyle(color: Colors.white, fontSize: 15, height: 1.6),
          strong: const TextStyle(
              color: Colors.cyanAccent, fontWeight: FontWeight.bold),
          h1: const TextStyle(
              color: Colors.purpleAccent,
              fontSize: 22,
              fontWeight: FontWeight.bold),
          h2: const TextStyle(
              color: Colors.purpleAccent,
              fontSize: 20,
              fontWeight: FontWeight.bold),
          listBullet: const TextStyle(color: Colors.cyanAccent),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(
      {required IconData icon,
      required String message,
      required String sub}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 52, color: Colors.white24),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 10),
            Text(
              sub,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleRequest(StatsProvider statsProvider,
      TransactionProvider txProvider, String type) async {
    // Check min transactions
    if (txProvider.transactions.length <= 5) return;

    if (!statsProvider.canRequestAnalysis(type)) {
      // No hay nada nuevo que hacer — la UI ya lee del cache via currentAdvice
      return;
    }

    statsProvider.setAdviceLoading(true);
    try {
      final transactions = txProvider.transactions;
      final walletProvider =
          Provider.of<WalletProvider>(context, listen: false);
      final budgetLimit = walletProvider.budgetLimit;
      final subscriptions = txProvider.subscriptions;
      final goals = walletProvider.goals;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // --- Filtrar transacciones recientes ---
      final filterDays = type == 'weekly' ? 7 : 30;
      final startDate = now.subtract(Duration(days: filterDays));

      final recent = transactions
          .where((t) =>
              t.date.isAfter(startDate) && t.type != TransactionType.transfer)
          .toList();

      if (recent.isEmpty) return;

      // --- Construir el payload ---
      final buffer = StringBuffer();

      buffer.writeln("Periodo: Últimos $filterDays días");
      buffer.writeln(
          "Presupuesto Mensual Base: S/ ${budgetLimit.toStringAsFixed(2)}");
      buffer.writeln();

      // Sección 1: Transacciones recientes
      double totalIncome = 0;
      double totalExpense = 0;
      buffer.writeln("=== TRANSACCIONES DEL PERIODO ===");

      for (var t in recent) {
        if (t.type == TransactionType.income) {
          totalIncome += t.amount.abs();
        } else {
          totalExpense += t.amount.abs();
        }

        if (buffer.length < 3000) {
          final tipo = t.type == TransactionType.income ? "Ingreso" : "Gasto";
          buffer.writeln(
              "- ${DateFormat('dd/MM').format(t.date)}: [$tipo] ${t.description} (S/ ${t.amount.abs().toStringAsFixed(2)})");
        }
      }

      buffer.writeln();
      buffer.writeln("Resumen Transacciones:");
      buffer.writeln("  Ingresos: S/ ${totalIncome.toStringAsFixed(2)}");
      buffer.writeln("  Gastos: S/ ${totalExpense.toStringAsFixed(2)}");
      buffer.writeln(
          "  Balance: S/ ${(totalIncome - totalExpense).toStringAsFixed(2)}");
      buffer.writeln();

      // Sección 2: Gastos Fijos / Suscripciones
      if (subscriptions.isNotEmpty) {
        buffer.writeln("=== GASTOS FIJOS (Suscripciones/Recurrentes) ===");
        for (var s in subscriptions) {
          final dueDate = s.nextDueDate;
          final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
          final diff = dueDay.difference(today).inDays;
          final amountStr = s.amount % 1 == 0
              ? s.amount.toInt().toString()
              : s.amount.toStringAsFixed(2);

          String estado;
          if (s.isPaid) {
            estado = "PAGADO este mes";
          } else if (diff < 0) {
            estado =
                "ATRASADO (venció hace ${diff.abs()} días, el ${DateFormat('dd/MM').format(dueDate)})";
          } else if (diff == 0) {
            estado = "VENCE HOY";
          } else if (diff <= 5) {
            estado =
                "PRÓXIMO (vence en $diff días, el ${DateFormat('dd/MM').format(dueDate)})";
          } else {
            estado = "Pendiente (vence el ${DateFormat('dd/MM').format(dueDate)})";
          }

          buffer.writeln("- ${s.name}: S/ $amountStr — $estado");
        }

        final totalFixed =
            subscriptions.fold(0.0, (sum, s) => sum + s.amount);
        buffer.writeln(
            "  Total comprometido en fijos: S/ ${totalFixed.toStringAsFixed(2)}");
        buffer.writeln();
      }

      // Sección 3: Metas de ahorro
      if (goals.isNotEmpty) {
        buffer.writeln("=== METAS DE AHORRO ===");
        for (var g in goals) {
          final progress = g.targetAmount > 0
              ? (g.currentAmount / g.targetAmount * 100).clamp(0, 100)
              : 0.0;
          final remaining = g.targetAmount - g.currentAmount;
          final targetStr = g.targetAmount % 1 == 0
              ? g.targetAmount.toInt().toString()
              : g.targetAmount.toStringAsFixed(2);
          final currentStr = g.currentAmount % 1 == 0
              ? g.currentAmount.toInt().toString()
              : g.currentAmount.toStringAsFixed(2);
          final remainingStr = remaining <= 0
              ? "COMPLETADA"
              : "Faltan S/ ${remaining.toStringAsFixed(2)}";

          buffer.writeln(
              "- ${g.name}: S/ $currentStr / S/ $targetStr (${progress.toStringAsFixed(0)}%) — $remainingStr");
        }
        buffer.writeln();
      }

      // --- Llamar a la API ---
      final advice = await GeminiClient().obtenerConsejo(
        contextData: buffer.toString(),
        periodType: type,
        isNewUser: false,
      );

      // save* actualiza el estado Y llama notifyListeners internamente
      if (type == 'weekly') {
        await statsProvider.saveWeeklyAdvice(advice);
      } else {
        await statsProvider.saveMonthlyAdvice(advice);
      }
    } catch (e) {
      // En error guardamos en el campo correspondiente para que persista el estado
      if (type == 'weekly') {
        await statsProvider.saveWeeklyAdvice(
            "Error al contactar al coach. Inténtalo más tarde.\nDetalle: $e");
      } else {
        await statsProvider.saveMonthlyAdvice(
            "Error al contactar al coach. Inténtalo más tarde.\nDetalle: $e");
      }
    } finally {
      statsProvider.setAdviceLoading(false);
    }
  }
}
