import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/transaction_entity.dart';

// Providers
import '../../providers/stats_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/ui_provider.dart';

// Components
import 'financial_coach_sheet.dart';

/// StatsPage: Pantalla de Estadísticas.
/// Muestra un desglose visual de los gastos mediante gráficos y listas detalladas.
class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage>
    with SingleTickerProviderStateMixin {
  int touchedIndex = -1;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Access Providers
    final statsProvider = Provider.of<StatsProvider>(context);
    final txProvider = Provider.of<TransactionProvider>(context);
    final walletProvider = Provider.of<WalletProvider>(context);
    final uiProvider = Provider.of<UiProvider>(context);

    // Filter Transactions based on Stats Provider State (Date/Period)
    final filteredTransactions = statsProvider.filterTransactionsByDate(
        txProvider.transactions,
        statsProvider.currentStatsDate,
        statsProvider.currentStatsPeriod);

    // Calculate Spending Map
    final spendingMap =
        statsProvider.getSpendingByCategory(filteredTransactions);

    // Calculate Total Amount
    final totalAmount =
        statsProvider.calculateTotalAmount(filteredTransactions);

    final isDarkMode = uiProvider.isDarkMode;
    final currentType = statsProvider.currentStatsType;

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
      Colors.greenAccent,
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
      final entries = spendingMap.entries.toList();
      entries.sort((a, b) => b.value.compareTo(a.value));

      for (int i = 0; i < entries.length; i++) {
        final isTouched = i == touchedIndex;
        final radius = isTouched ? 35.0 : 25.0;

        final entry = entries[i];
        final color = colors[colorIndex % colors.length];

        chartSections.add(PieChartSectionData(
          color: color,
          value: entry.value,
          radius: radius,
          title: "",
          showTitle: false,
        ));
        colorIndex++;
      }
    }

    // Determine Center Text Content
    String centerStartText =
        currentType == StatsType.expense ? "GASTADO" : "INGRESADO";
    String centerAmountText =
        "${walletProvider.currencySymbol} ${totalAmount > 0 ? totalAmount.toStringAsFixed(2) : '0.00'}";

    if (touchedIndex != -1 && spendingMap.isNotEmpty) {
      final entries = spendingMap.entries.toList();
      entries.sort((a, b) => b.value.compareTo(a.value));

      if (touchedIndex < entries.length) {
        final entry = entries[touchedIndex];
        centerStartText = entry.key.toUpperCase();
        centerAmountText =
            "${walletProvider.currencySymbol} ${entry.value.toStringAsFixed(2)}";
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
                  "Gastos", StatsType.expense, statsProvider, isDarkMode),
              const SizedBox(width: 4),
              _buildTypeToggle(
                  "Ingresos", StatsType.income, statsProvider, isDarkMode),
            ],
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              final isReady = (statsProvider.canRequestAnalysis('weekly') ||
                      statsProvider.canRequestAnalysis('monthly')) &&
                  txProvider.transactions.isNotEmpty;

              final scale = isReady ? _pulseAnimation.value : 1.0;
              final glowAlpha = isReady
                  ? (0.1 + (_pulseAnimation.value - 1.0) * 2.0).clamp(0.0, 1.0)
                  : 0.05;
              final glowBlur =
                  isReady ? (4.0 + (_pulseAnimation.value - 1.0) * 40.0) : 4.0;
              final glowSpread =
                  isReady ? ((_pulseAnimation.value - 1.0) * 10.0) : 0.0;

              return Transform.scale(
                scale: scale,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.purpleAccent
                                .withValues(alpha: glowAlpha),
                            blurRadius: glowBlur,
                            spreadRadius: glowSpread,
                          )
                        ],
                      ),
                      child: IconButton(
                        onPressed: () => _showFinancialCoach(context),
                        icon: const Icon(Icons.psychology_alt,
                            color: Colors.purpleAccent),
                        tooltip: "Coach Financiero IA",
                      ),
                    ),
                    if (isReady)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.redAccent,
                                  blurRadius: 4,
                                  spreadRadius: 1)
                            ],
                          ),
                        ),
                      )
                  ],
                ),
              );
            },
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
                      statsProvider.currentStatsPeriod == PeriodType.week,
                      () => statsProvider.setStatsPeriod(PeriodType.week),
                      isDarkMode),
                  _buildPeriodTab(
                      "Mes",
                      statsProvider.currentStatsPeriod == PeriodType.month,
                      () => statsProvider.setStatsPeriod(PeriodType.month),
                      isDarkMode),
                  _buildPeriodTab(
                      "Año",
                      statsProvider.currentStatsPeriod == PeriodType.year,
                      () => statsProvider.setStatsPeriod(PeriodType.year),
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
                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
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

            // Date Navigation Control
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  color: subTextColor,
                  onPressed: () => _navigateDate(statsProvider, false),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDate(statsProvider.currentStatsDate,
                          statsProvider.currentStatsPeriod)
                      .toUpperCase(),
                  style: TextStyle(
                    color: currentType == StatsType.expense
                        ? Colors.redAccent
                        : Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  color: subTextColor,
                  onPressed: () => _navigateDate(statsProvider, true),
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
                final percentage = totalAmount > 0 ? amount / totalAmount : 0.0;
                final color = colors[adjustedIndex % colors.length];

                return Column(
                  children: [
                    _buildSpendingItem(
                        entry.key,
                        "${(percentage * 100).toStringAsFixed(1)}% del total",
                        "${walletProvider.currencySymbol} ${amount.toStringAsFixed(2)}",
                        "Variable",
                        Icons.label,
                        color,
                        true,
                        percentage,
                        isDarkMode),
                    const SizedBox(height: 15),
                  ],
                );
              }),
          ],
        ),
      ),
    );
  }

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
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected
                  ? Colors.black
                  : (isDarkMode ? Colors.white70 : Colors.black54),
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

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
            constraints: const BoxConstraints(maxWidth: 120),
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
                        fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          )
        ],
      ),
    );
  }

  void _navigateDate(StatsProvider provider, bool isNext) {
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

    provider.setStatsDate(newDate);
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

  Widget _buildTypeToggle(
      String text, StatsType type, StatsProvider provider, bool isDarkMode) {
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

  void _showFinancialCoach(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const FinancialCoachSheet(),
    );
  }
}
