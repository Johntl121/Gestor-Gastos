import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import '../../../core/services/gemini_client.dart';
import '../../providers/stats_provider.dart';
import '../../providers/transaction_provider.dart';

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
          const SizedBox(height: 10),
          const Text(
            "Tus datos financieros se procesan mediante un servicio de IA externo para generar este análisis.",
            style: TextStyle(fontSize: 10, color: Colors.white38),
            textAlign: TextAlign.center,
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
        : (isSelected
            ? activeColor.withValues(alpha: 0.2)
            : Colors.transparent);

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
  Widget _buildAdviceContent(
      StatsProvider statsProvider, TransactionProvider txProvider) {
    final hasMinData = txProvider.transactions.length > 5;

    if (!hasMinData) {
      return _buildPlaceholder(
        icon: Icons.bar_chart_outlined,
        message:
            "Registra al menos 5 movimientos para recibir tu primer análisis.",
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
      {required IconData icon, required String message, required String sub}) {
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
      return;
    }

    statsProvider.setAdviceLoading(true);
    try {
      // --- Usar el nuevo Context Builder centralizado ---
      final contextData = await statsProvider.buildFinancialContextForAI();

      // --- Llamar a la API con el contexto estructurado ---
      final advice = await GeminiClient().obtenerConsejo(
        contextData: contextData,
        periodType: type,
        isNewUser: false,
      );

      if (type == 'weekly') {
        await statsProvider.saveWeeklyAdvice(advice);
      } else {
        await statsProvider.saveMonthlyAdvice(advice);
      }
    } catch (e) {
      final errorMessage =
          "Error al contactar al coach. Inténtalo más tarde.\nDetalle: $e";
      if (type == 'weekly') {
        await statsProvider.saveWeeklyAdvice(errorMessage);
      } else {
        await statsProvider.saveMonthlyAdvice(errorMessage);
      }
    } finally {
      statsProvider.setAdviceLoading(false);
    }
  }
}
