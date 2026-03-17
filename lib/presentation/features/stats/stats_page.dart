import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';


// Providers
import '../../providers/stats_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/ui_provider.dart';

// Components
import 'financial_coach_sheet.dart';
import '../../../core/utils/currency_formatter.dart';

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
    final uiProvider = Provider.of<UiProvider>(context);

    // Calculate Categories (Dynamically mapped with actual colors)
    final categories = statsProvider.getSpendingByCategory(txProvider.subscriptions);

    // Calculate Total Amount
    final totalAmount = statsProvider.calculateTotalAmount(categories);

    final isDarkMode = uiProvider.isDarkMode;
    final currentType = statsProvider.currentStatsType;

    final backgroundColor =
        isDarkMode ? const Color(0xFF15202B) : const Color(0xFFF8FAFC);
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subTextColor = isDarkMode ? Colors.blueGrey[200] : Colors.grey;

    // Prepare Chart Data
    List<PieChartSectionData> chartSections = [];

    if (categories.isEmpty) {
      chartSections.add(PieChartSectionData(
          color: isDarkMode ? Colors.white10 : Colors.grey.shade300,
          value: 1,
          radius: 35, // More premium thickness
          showTitle: false));
    } else {
      for (int i = 0; i < categories.length; i++) {
        final isTouched = i == touchedIndex;
        final radius = isTouched ? 35.0 : 28.0; // Dynamic thickness - Elegant and Thinner
        final group = categories[i];

        chartSections.add(PieChartSectionData(
          color: group.color,
          value: group.amount,
          radius: radius,
          title: "",
          showTitle: false,
          borderSide: BorderSide.none, // Eliminamos bordes toscos
          badgeWidget: isTouched ? _buildSectionBadge(group.color) : null,
          badgePositionPercentageOffset: 0.98,
        ));
      }
    }

    // Determine Center Text Content
    String centerStartText =
        currentType == StatsType.expense ? "GASTADO" : "INGRESADO";
    
    final currencySymbol = statsProvider.currencySymbol;
    String centerAmountText = CurrencyFormatter.format(totalAmount, currencySymbol);

    if (touchedIndex != -1 && categories.isNotEmpty) {
      if (touchedIndex < categories.length) {
        final group = categories[touchedIndex];
        centerStartText = group.name.toUpperCase();
        centerAmountText = CurrencyFormatter.format(group.amount, currencySymbol);
      }
    }

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
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // 1. Selector de Periodo
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.white.withValues(alpha: 0.05)
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
                      height: 260,
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
                                sectionsSpace: 2,
                                centerSpaceRadius: 85,
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
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.2),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                SizedBox(
                                  width: 140, // Límite para el FittedBox
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: AnimatedDefaultTextStyle(
                                      duration: const Duration(milliseconds: 200),
                                      style: TextStyle(
                                          color: textColor,
                                          fontSize: 34,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.5),
                                      child: Text(centerAmountText),
                                    ),
                                  ),
                                ),
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
                            fontSize: 14,
                            letterSpacing: 1,
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
                                ? "Distribución de Gastos"
                                : "Distribución de Ingresos",
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textColor)),
                      ],
                    ),
        
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // 4. Lista de Gastos mediante Slivers para scroll fluido
            if (categories.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.pie_chart_outline_rounded, 
                           size: 64, 
                           color: isDarkMode ? Colors.white10 : Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        currentType == StatsType.expense
                            ? "Sin gastos en este periodo"
                            : "Sin ingresos en este periodo",
                        style: TextStyle(color: subTextColor, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final group = categories[index];
                      final amount = group.amount;
                      final percentage = totalAmount > 0 ? amount / totalAmount : 0.0;
                      

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 15),
                        child: _buildSpendingItem(
                            group.name,
                            "${(percentage * 100).toStringAsFixed(1)}% del total",
                            CurrencyFormatter.format(amount, currencySymbol),
                            percentage > 0.3 ? "Alto impacto" : "Normal",
                            group.icon,
                            group.color,
                            percentage < 0.4,
                            percentage,
                            isDarkMode),
                      );
                    },
                    childCount: categories.length,
                  ),
                ),
              ),
            
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
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
                      color: Colors.grey.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 5))
                ]),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: iconBgColor.withValues(alpha: 0.2),
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
          color: isSelected ? activeColor.withValues(alpha: 0.2) : Colors.transparent,
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

  Widget _buildSectionBadge(Color color) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.5),
            blurRadius: 4,
            spreadRadius: 2,
          )
        ],
      ),
    );
  }
}
