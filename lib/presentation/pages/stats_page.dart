import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/dashboard_provider.dart';

/// StatsPage: Pantalla de Estadísticas.
/// Muestra un desglose visual de los gastos mediante gráficos y listas detalladas.
class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(builder: (context, provider, child) {
      final spendingMap = provider.spendingByCategory;
      final totalSpent = provider.totalMonthlyExpenses;
      final isDarkMode = provider.isDarkMode;

      final backgroundColor =
          isDarkMode ? const Color(0xFF15202B) : const Color(0xFFF8FAFC);
      final textColor = isDarkMode ? Colors.white : Colors.black;
      final subTextColor = isDarkMode ? Colors.blueGrey[200] : Colors.grey;

      // Prepare Chart Data
      List<PieChartSectionData> chartSections = [];
      final List<Color> colors = [
        Colors.cyan,
        const Color(0xFFFF6B6B),
        const Color(0xFF009688),
        Colors.orange,
        Colors.purple,
        Colors.blue
      ];

      if (spendingMap.isEmpty) {
        chartSections.add(PieChartSectionData(
            color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
            value: 1,
            radius: 25,
            showTitle: false));
      } else {
        int colorIndex = 0;
        spendingMap.forEach((category, amount) {
          final color = colors[colorIndex % colors.length];
          chartSections.add(PieChartSectionData(
            color: color,
            value: amount,
            radius: 25,
            showTitle: false,
          ));
          colorIndex++;
        });
      }

      // Prepare List Data (Sorted)
      final sortedEntries = spendingMap.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          title: Text(
            "Gastos",
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: textColor),
          actions: [
            IconButton(
              icon: Icon(Icons.calendar_today, color: textColor),
              onPressed: () => _pickMonth(context, provider),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
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
                          Text("GASTADO",
                              style: TextStyle(
                                  color: subTextColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.2)),
                          const SizedBox(height: 5),
                          Text(
                              "${provider.currencySymbol} ${totalSpent > 0 ? totalSpent.toStringAsFixed(2) : '0.00'}",
                              style: TextStyle(
                                  color: textColor,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1)),
                          const SizedBox(height: 5),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.arrow_downward,
                                  color: Colors.redAccent, size: 14),
                              Text(
                                  provider.currentStatsPeriod == PeriodType.week
                                      ? "ESTA SEMANA"
                                      : provider.currentStatsPeriod ==
                                              PeriodType.year
                                          ? "ESTE AÑO"
                                          : DateFormat('MMMM yyyy', 'es_ES')
                                              .format(provider.currentStatsDate)
                                              .toUpperCase(),
                                  style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.bold)),
                            ],
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // 3. Cabecera de Mayores Gastos
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Mayores Gastos",
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
                  child: Text("No hay gastos registrados este mes.",
                      style: TextStyle(color: subTextColor)),
                ))
              else
                ...List.generate(sortedEntries.length, (index) {
                  final entry = sortedEntries[index];
                  final amount = entry.value;
                  final percentage = totalSpent > 0 ? amount / totalSpent : 0.0;
                  final color = colors[index % colors.length];

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

  Future<void> _pickMonth(
      BuildContext context, DashboardProvider provider) async {
    final isDarkMode = provider.isDarkMode;
    final picked = await showDatePicker(
      context: context,
      initialDate: provider.currentStatsDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: isDarkMode
              ? ThemeData.dark().copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: Colors.cyan,
                    onPrimary: Colors.white,
                    surface: Color(0xFF1E2730),
                    onSurface: Colors.white,
                  ),
                  dialogBackgroundColor: const Color(0xFF15202B),
                  textButtonTheme: TextButtonThemeData(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.cyan,
                    ),
                  ),
                )
              : ThemeData.light().copyWith(
                  colorScheme: const ColorScheme.light(
                    primary: Colors.cyan,
                    onPrimary: Colors.white,
                    onSurface: Colors.black,
                  ),
                ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      provider.setStatsMonth(picked);
    }
  }
}
