import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/dashboard_provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../core/services/ai_service.dart';

/// StatsPage: Pantalla de Estadísticas.
/// Muestra un desglose visual de los gastos mediante gráficos y listas detalladas.
class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(builder: (context, provider, child) {
      final spendingMap = provider.spendingByCategory;
      final totalAmount = provider.totalStatsAmount;
      final isDarkMode = provider.isDarkMode;
      final currentType = provider.currentStatsType; // Get Filter Type

      final backgroundColor =
          isDarkMode ? const Color(0xFF15202B) : const Color(0xFFF8FAFC);
      final textColor = isDarkMode ? Colors.white : Colors.black;
      final subTextColor = isDarkMode ? Colors.blueGrey[200] : Colors.grey;

      // Prepare Chart Data
      List<PieChartSectionData> chartSections = [];
      final List<Color> expenseColors = [
        Colors.cyan,
        const Color(0xFFFF6B6B),
        const Color(0xFF009688),
        Colors.orange,
        Colors.purple,
        Colors.blue
      ];

      final List<Color> incomeColors = [
        Colors.greenAccent,
        Colors.teal,
        Colors.lightGreen,
        Colors.green,
        Colors.limeAccent,
        Colors.greenAccent, // Replacement for emerald
      ];

      final colors =
          currentType == StatsType.expense ? expenseColors : incomeColors;

      if (spendingMap.isEmpty) {
        chartSections.add(PieChartSectionData(
            color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
            value: 1,
            radius: 25,
            showTitle: false));
      } else {
        int colorIndex = 0;
        final entries =
            spendingMap.entries.toList(); // Fixed order for index matching
        // Sort same as list for consistency if desired, but map iteration order is generally insertion in Dart.
        // Let's sort to match "Mayores Gastos" order for consistency.
        entries.sort((a, b) => b.value.compareTo(a.value));

        for (int i = 0; i < entries.length; i++) {
          final isTouched = i == touchedIndex;
          final radius = isTouched ? 35.0 : 25.0; // Enlarge on touch

          final entry = entries[i];
          final color = colors[colorIndex % colors.length];

          chartSections.add(PieChartSectionData(
            color: color,
            value: entry.value,
            radius: radius,
            title: "", // Titles hidden inside chart, shown in center
            showTitle: false,
          ));
          colorIndex++;
        }
      }

      // Determine Center Text Content
      String centerStartText =
          currentType == StatsType.expense ? "GASTADO" : "INGRESADO";
      String centerAmountText =
          "${provider.currencySymbol} ${totalAmount > 0 ? totalAmount.toStringAsFixed(2) : '0.00'}";

      if (touchedIndex != -1 && spendingMap.isNotEmpty) {
        final entries = spendingMap.entries.toList();
        entries.sort((a, b) => b.value.compareTo(a.value));

        if (touchedIndex < entries.length) {
          final entry = entries[touchedIndex];
          centerStartText = entry.key.toUpperCase(); // Category Name
          centerAmountText =
              "${provider.currencySymbol} ${entry.value.toStringAsFixed(2)}";
        }
      }

      // Prepare List Data (Sorted)
      final sortedEntries = spendingMap.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          title: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.white12 : Colors.grey[200],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTypeToggle(
                    "Gastos", StatsType.expense, provider, isDarkMode),
                const SizedBox(width: 4),
                _buildTypeToggle(
                    "Ingresos", StatsType.income, provider, isDarkMode),
              ],
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false, // Prevent default back button
          iconTheme: IconThemeData(color: textColor),
          actions: [
            IconButton(
              onPressed: () => _showFinancialCoach(context, provider),
              icon:
                  const Icon(Icons.psychology_alt, color: Colors.purpleAccent),
              tooltip: "Coach Financiero IA",
            )
          ],
        ),
        body: SingleChildScrollView(
          padding:
              const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 100),
          child: Column(
            children: [
              // 1. Selector de Periodo
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.05)
                      : Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _buildPeriodTab(
                        "Semana",
                        provider.currentStatsPeriod == PeriodType.week,
                        () => provider.setStatsPeriod(PeriodType.week),
                        isDarkMode),
                    _buildPeriodTab(
                        "Mes",
                        provider.currentStatsPeriod == PeriodType.month,
                        () => provider.setStatsPeriod(PeriodType.month),
                        isDarkMode),
                    _buildPeriodTab(
                        "Año",
                        provider.currentStatsPeriod == PeriodType.year,
                        () => provider.setStatsPeriod(PeriodType.year),
                        isDarkMode),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // 2. Gráfico Circular (Donut Chart)
              SizedBox(
                height: 250,
                child: Stack(
                  children: [
                    PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback:
                              (FlTouchEvent event, pieTouchResponse) {
                            setState(() {
                              if (!event.isInterestedForInteractions ||
                                  pieTouchResponse == null ||
                                  pieTouchResponse.touchedSection == null) {
                                touchedIndex = -1;
                                return;
                              }
                              touchedIndex = pieTouchResponse
                                  .touchedSection!.touchedSectionIndex;
                            });
                          },
                        ),
                        sectionsSpace: 0,
                        centerSpaceRadius: 80,
                        startDegreeOffset: -90,
                        sections: chartSections,
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(centerStartText,
                              style: TextStyle(
                                  color: subTextColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.2),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 5),
                          Text(centerAmountText,
                              style: TextStyle(
                                  color: textColor,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1)),
                          const SizedBox(height: 5),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Date Navigation Control (Moved Outside)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    color: subTextColor,
                    onPressed: () => _navigateDate(provider, false),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatDate(provider.currentStatsDate,
                            provider.currentStatsPeriod)
                        .toUpperCase(),
                    style: TextStyle(
                      color: currentType == StatsType.expense
                          ? Colors.redAccent
                          : Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 16, // Increasing Size slightly
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    color: subTextColor,
                    onPressed: () => _navigateDate(provider, true),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // 3. Cabecera de Mayores Gastos
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                      currentType == StatsType.expense
                          ? "Mayores Gastos"
                          : "Mayores Ingresos",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor)),
                  const Text("Ver todos",
                      style: TextStyle(
                          color: Colors.cyan,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                ],
              ),

              const SizedBox(height: 20),

              // 4. Lista de Gastos
              if (sortedEntries.isEmpty)
                Center(
                    child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                      currentType == StatsType.expense
                          ? "No hay gastos registrados este periodo."
                          : "No hay ingresos registrados este periodo.",
                      style: TextStyle(color: subTextColor)),
                ))
              else
                ...List.generate(sortedEntries.length, (index) {
                  final adjustedIndex = index;
                  final entry = sortedEntries[adjustedIndex];
                  final amount = entry.value;
                  final percentage =
                      totalAmount > 0 ? amount / totalAmount : 0.0;
                  final color = colors[adjustedIndex % colors.length];

                  return Column(
                    children: [
                      _buildSpendingItem(
                          entry.key, // Title (Category Name)
                          "${(percentage * 100).toStringAsFixed(1)}% del total", // Subtitle
                          "${provider.currencySymbol} ${amount.toStringAsFixed(2)}", // Amount
                          "Variable", // Status (Mock)
                          Icons.label, // Icon (Generic)
                          color, // IconBgColor
                          true, // isGoodStatus (Mock)
                          percentage, // Percentage
                          isDarkMode),
                      const SizedBox(height: 15),
                    ],
                  );
                }),
            ],
          ),
        ),
      );
    });
  }

  /// Construye una pestaña del selector de periodo (Semana, Mes, Año)
  /// Estilo High Contrast
  Widget _buildPeriodTab(
      String text, bool isSelected, VoidCallback onTap, bool isDarkMode) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.cyanAccent : Colors.transparent,
            borderRadius: BorderRadius.circular(30), // Rounded pill shape
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected
                  ? Colors.black // High contrast on Cyan
                  : (isDarkMode ? Colors.white70 : Colors.black54),
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  /// Construye un item de la lista de gastos
  Widget _buildSpendingItem(
      String title,
      String subtitle,
      String amount,
      String status,
      IconData icon,
      Color iconBgColor,
      bool isGoodStatus,
      double percentage,
      bool isDarkMode) {
    final cardColor = isDarkMode ? const Color(0xFF1F2937) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subTextColor = isDarkMode ? Colors.blueGrey[200] : Colors.grey[400];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isDarkMode
              ? []
              : [
                  BoxShadow(
                      color: Colors.grey.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 5))
                ]),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: iconBgColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16)),
            child: Icon(icon,
                color: isDarkMode ? Colors.white70 : Colors.black54, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: textColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(isGoodStatus ? "😊" : "☹️",
                        style: const TextStyle(fontSize: 12))
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percentage,
                    color: isGoodStatus ? Colors.cyan : Colors.redAccent,
                    backgroundColor:
                        isDarkMode ? Colors.white10 : Colors.grey[100],
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 8),
                Text(subtitle,
                    style: TextStyle(color: subTextColor, fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(
                maxWidth: 120), // Restricción para evitar desbordamiento
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(amount,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: textColor)),
                const SizedBox(height: 4),
                Text(status,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        color: isGoodStatus ? Colors.grey : Colors.redAccent,
                        fontSize: 11), // Slightly smaller font
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          )
        ],
      ),
    );
  }

  /* Future<void> _pickMonth(
      BuildContext context, DashboardProvider provider) async { ... } */

  void _navigateDate(DashboardProvider provider, bool isNext) {
    DateTime newDate = provider.currentStatsDate;
    final period = provider.currentStatsPeriod;

    if (isNext) {
      if (period == PeriodType.week) {
        newDate = newDate.add(const Duration(days: 7));
      } else if (period == PeriodType.month) {
        newDate = DateTime(newDate.year, newDate.month + 1, newDate.day);
      } else {
        newDate = DateTime(newDate.year + 1, newDate.month, newDate.day);
      }
    } else {
      if (period == PeriodType.week) {
        newDate = newDate.subtract(const Duration(days: 7));
      } else if (period == PeriodType.month) {
        newDate = DateTime(newDate.year, newDate.month - 1, newDate.day);
      } else {
        newDate = DateTime(newDate.year - 1, newDate.month, newDate.day);
      }
    }

    provider.setStatsMonth(newDate); // reusing existing setter
  }

  String _formatDate(DateTime date, PeriodType period) {
    if (period == PeriodType.week) {
      final start = date.subtract(Duration(days: date.weekday - 1));
      final end = start.add(const Duration(days: 6));
      return "${DateFormat('d MMM', 'es_ES').format(start)} - ${DateFormat('d MMM', 'es_ES').format(end)}";
    } else if (period == PeriodType.year) {
      return DateFormat('yyyy', 'es_ES').format(date);
    } else {
      return DateFormat('MMMM yyyy', 'es_ES').format(date);
    }
  }

  Widget _buildTypeToggle(String text, StatsType type,
      DashboardProvider provider, bool isDarkMode) {
    final isSelected = provider.currentStatsType == type;
    final activeColor =
        type == StatsType.expense ? Colors.redAccent : Colors.greenAccent;

    return GestureDetector(
      onTap: () => provider.setStatsType(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isSelected ? activeColor : Colors.transparent, width: 1),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected
                ? activeColor
                : (isDarkMode ? Colors.white54 : Colors.black54),
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  void _showFinancialCoach(BuildContext context, DashboardProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: provider.isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: FutureBuilder<String>(
          future: AIService().getFinancialAdvice(
              provider.transactions, // Assuming this getter exists
              2000.0 // Default Budget if not available
              ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.purpleAccent),
                    SizedBox(height: 16),
                    Text("Analizando tus finanzas con IA...",
                        style: TextStyle(fontSize: 16)),
                  ],
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(child: Text("Error: ${snapshot.error}"));
            }

            return Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                        bottom:
                            BorderSide(color: Colors.grey.withOpacity(0.2))),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.psychology_alt,
                          color: Colors.purpleAccent, size: 28),
                      const SizedBox(width: 12),
                      const Text("Coach Financiero",
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      )
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: MarkdownBody(
                      data: snapshot.data ?? "No hay consejos disponibles.",
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(
                            fontSize: 16,
                            color: provider.isDarkMode
                                ? Colors.white70
                                : Colors.black87),
                        h1: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold),
                        h2: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                        listBullet: const TextStyle(
                            color: Colors.purpleAccent, fontSize: 16),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
