import 'package:flutter/material.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../providers/dashboard_provider.dart';
import '../../domain/entities/transaction_entity.dart';
import '../delegates/transaction_search_delegate.dart';
import '../../presentation/pages/add_transaction_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  // Config: Filter Item Structure
  final List<Map<String, dynamic>> _filters = [
    {'label': 'Todos', 'type': 'all', 'value': null, 'color': Colors.blueGrey},
    {
      'label': 'Gastos',
      'type': 'type',
      'value': TransactionType.expense,
      'color': Colors.redAccent
    },
    {
      'label': 'Ingresos',
      'type': 'type',
      'value': TransactionType.income,
      'color': Colors.greenAccent
    },
    {'label': 'Efectivo', 'type': 'account', 'value': 1, 'color': Colors.amber},
    {
      'label': 'Banco',
      'type': 'account',
      'value': 2,
      'color': Colors.blueAccent
    },
    {
      'label': '|',
      'type': 'separator',
      'value': null,
      'color': Colors.grey
    }, // Visual Separator
    // Expanded Categories
    {
      'label': 'Comida',
      'type': 'category',
      'value': 'Comida',
      'color': Colors.orange
    },
    {
      'label': 'Mercado',
      'type': 'category',
      'value': 'Mercado',
      'color': Colors.lightGreen
    },
    {
      'label': 'Vivienda',
      'type': 'category',
      'value': 'Vivienda',
      'color': Colors.blueGrey
    },
    {
      'label': 'Servicios',
      'type': 'category',
      'value': 'Servicios',
      'color': Colors.amber.shade700
    },
    {
      'label': 'Transporte',
      'type': 'category',
      'value': 'Transporte',
      'color': Colors.blue
    },
    {
      'label': 'Vehículo',
      'type': 'category',
      'value': 'Vehículo',
      'color': Colors.redAccent
    },
    {
      'label': 'Compras',
      'type': 'category',
      'value': 'Compras',
      'color': Colors.pink
    },
    {
      'label': 'Cuidado',
      'type': 'category',
      'value': 'Cuidado',
      'color': Colors.purple
    },
    {
      'label': 'Suscripciones',
      'type': 'category',
      'value': 'Suscripciones',
      'color': Colors.red
    },
    {
      'label': 'Salud',
      'type': 'category',
      'value': 'Salud',
      'color': Colors.teal
    },
    {
      'label': 'Deportes',
      'type': 'category',
      'value': 'Deportes',
      'color': Colors.green
    },
    {
      'label': 'Entretenimiento',
      'type': 'category',
      'value': 'Entretenimiento',
      'color': Colors.indigo
    },
    {
      'label': 'Viajes',
      'type': 'category',
      'value': 'Viajes',
      'color': Colors.cyan
    },
    {
      'label': 'Educación',
      'type': 'category',
      'value': 'Educación',
      'color': Colors.brown
    },
    {
      'label': 'Tecnología',
      'type': 'category',
      'value': 'Tecnología',
      'color': Colors.grey
    },
    {
      'label': 'Deudas',
      'type': 'category',
      'value': 'Deudas',
      'color': Colors.deepOrange
    },
    {
      'label': 'Ahorro',
      'type': 'category',
      'value': 'Ahorro',
      'color': Colors.lime
    },
    {
      'label': 'Sueldo',
      'type': 'category',
      'value': 'Sueldo',
      'color': Colors.green.shade800
    },
    {
      'label': 'Negocio',
      'type': 'category',
      'value': 'Negocio',
      'color': Colors.blue.shade900
    },
    {
      'label': 'Otros',
      'type': 'category',
      'value': 'Otros',
      'color': Colors.blueGrey
    },
  ];

  Map<String, dynamic> _selectedFilter = {
    'label': 'Todos',
    'type': 'all'
  }; // Default

  bool _isCalendarView = false;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, provider, child) {
        final isDarkMode = provider.isDarkMode;
        final backgroundColor =
            isDarkMode ? const Color(0xFF15202B) : const Color(0xFFF5F7FA);
        final textColor = isDarkMode ? Colors.white : Colors.black;
        final iconColor = isDarkMode ? Colors.white : Colors.black54;

        return Scaffold(
          backgroundColor: backgroundColor,
          appBar: AppBar(
            backgroundColor: backgroundColor,
            elevation: 0,
            centerTitle: true,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person, color: iconColor, size: 20),
            ),
            title: Text(
              "Historial",
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
            ),
            actions: [
              IconButton(
                icon: Icon(_isCalendarView ? Icons.list : Icons.calendar_month,
                    color: iconColor),
                onPressed: () {
                  setState(() {
                    _isCalendarView = !_isCalendarView;
                  });
                },
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(Icons.search, color: iconColor, size: 24),
                  onPressed: () {
                    showSearch(
                      context: context,
                      delegate: TransactionSearchDelegate(
                          Provider.of<DashboardProvider>(context, listen: false)
                              .transactions),
                    );
                  },
                ),
              )
            ],
          ),
          body: Builder(
            builder: (context) {
              if (_isCalendarView) {
                return _buildCalendarView(provider, isDarkMode);
              }

              final grouped = <String, List<TransactionEntity>>{};
              final now = DateTime.now();

              // Apply Filter
              var displayedTransactions = provider.transactions;
              final type = _selectedFilter['type'];
              final value = _selectedFilter['value'];

              if (type == 'type') {
                displayedTransactions = displayedTransactions
                    .where((t) => t.type == value)
                    .toList();
              } else if (type == 'account') {
                displayedTransactions = displayedTransactions
                    .where((t) => t.accountId == value)
                    .toList();
              } else if (type == 'category') {
                displayedTransactions = displayedTransactions
                    .where((t) => t.description == value)
                    .toList();
              }

              for (var t in displayedTransactions) {
                String key;
                final isToday = t.date.year == now.year &&
                    t.date.month == now.month &&
                    t.date.day == now.day;
                final isYesterday = t.date.year == now.year &&
                    t.date.month == now.month &&
                    t.date.day == now.day - 1;

                if (isToday) {
                  key = 'HOY';
                } else if (isYesterday) {
                  key = 'AYER';
                } else {
                  key = DateFormat('MMM d', 'es').format(t.date).toUpperCase();
                }

                if (!grouped.containsKey(key)) {
                  grouped[key] = [];
                }
                grouped[key]!.add(t);
              }

              return Column(
                children: [
                  // 1. Filtros Horizontales Potenciados
                  SizedBox(
                    height: 60,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      itemCount: _filters.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final filter = _filters[index];

                        // Separator Logic
                        if (filter['type'] == 'separator') {
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: 1,
                            height: 20,
                            color: isDarkMode ? Colors.white24 : Colors.black12,
                          );
                        }

                        final isSelected =
                            filter['label'] == _selectedFilter['label'];
                        final color = filter['color'] as Color;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedFilter = filter;
                            });
                          },
                          child: _buildFilterChip(
                              filter['label'], isSelected, color, isDarkMode),
                        );
                      },
                    ),
                  ),

                  // 2. Lista Agrupada Real
                  Expanded(
                    child: grouped.isEmpty
                        ? Center(
                            child: Text("No hay transacciones",
                                style: TextStyle(color: Colors.grey[600])))
                        : ListView.builder(
                            padding: const EdgeInsets.only(
                                left: 16, right: 16, top: 10, bottom: 100),
                            itemCount: grouped.keys.length,
                            itemBuilder: (context, index) {
                              final key = grouped.keys.elementAt(index);
                              final transactions = grouped[key]!;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionHeader(key),
                                  ...transactions.map((t) => Dismissible(
                                        key: Key(t.id.toString()),
                                        direction: DismissDirection.endToStart,
                                        background: Container(
                                          alignment: Alignment.centerRight,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 20),
                                          color: Colors.redAccent,
                                          child: const Icon(Icons.delete,
                                              color: Colors.white),
                                        ),
                                        onDismissed: (direction) {
                                          final deletedTransaction = t;
                                          if (t.id != null) {
                                            provider.deleteTransaction(t.id!);
                                            ScaffoldMessenger.of(context)
                                                .clearSnackBars();
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(SnackBar(
                                              content: const Text(
                                                  'Transacción eliminada'),
                                              action: SnackBarAction(
                                                  label: 'DESHACER',
                                                  textColor: Colors.cyanAccent,
                                                  onPressed: () {
                                                    provider.addTransaction(
                                                        deletedTransaction);
                                                  }),
                                              duration:
                                                  const Duration(seconds: 4),
                                            ));
                                          }
                                        },
                                        child: GestureDetector(
                                          onTap: () {
                                            _showTransactionDetails(context, t,
                                                provider, isDarkMode);
                                          },
                                          child: Builder(builder: (context) {
                                            // Forced Visual Fix for legacy data
                                            bool isTransfer = t.type ==
                                                    TransactionType.transfer ||
                                                t.description
                                                    .toLowerCase()
                                                    .contains('transferencia');

                                            String title = t.description;
                                            String subtitle =
                                                DateFormat('h:mm a')
                                                    .format(t.date);

                                            // Amount & Color Formatting
                                            bool isIncome = t.amount > 0;
                                            String symbol = provider.accounts
                                                    .where((a) =>
                                                        a.id == t.accountId)
                                                    .firstOrNull
                                                    ?.currencySymbol ??
                                                provider.currencySymbol;
                                            String absAmount = t.amount
                                                .abs()
                                                .toStringAsFixed(2);

                                            String amount;
                                            Color color;
                                            IconData icon;

                                            if (isTransfer) {
                                              final source = provider
                                                  .getAccountName(t.accountId);
                                              final dest =
                                                  t.destinationAccountId != null
                                                      ? provider.getAccountName(
                                                          t.destinationAccountId!)
                                                      : 'Destino';

                                              title = t.description.isNotEmpty
                                                  ? t.description
                                                  : "Transferencia";
                                              subtitle =
                                                  "${DateFormat('h:mm a').format(t.date)} • $source ➔ $dest";

                                              amount = "⇄ $symbol $absAmount";
                                              color = isDarkMode
                                                  ? Colors.white70
                                                  : const Color(0xFF64B5F6);
                                              icon = Icons.swap_horiz;
                                            } else {
                                              amount =
                                                  "${isIncome ? '+' : '-'} $symbol $absAmount";
                                              color = isIncome
                                                  ? (isDarkMode
                                                      ? Colors.greenAccent
                                                      : Colors.green)
                                                  : Colors.redAccent;
                                              icon = isIncome
                                                  ? Icons.account_balance_wallet
                                                  : Icons.shopping_bag;

                                              if (t.note != null &&
                                                  t.note!.isNotEmpty) {
                                                subtitle += " • ${t.note!}";
                                              } else {
                                                subtitle +=
                                                    " • ${isIncome ? 'Ingreso' : 'Gasto'}";
                                              }
                                            }

                                            Color accountColor = Colors.grey;
                                            if (t.accountId == 1)
                                              accountColor =
                                                  Colors.amber; // Cash
                                            else if (t.accountId == 2)
                                              accountColor =
                                                  Colors.blueAccent; // Bank
                                            else if (t.accountId == 3)
                                              accountColor = Colors
                                                  .purpleAccent; // Savings

                                            String accountName = provider
                                                .getAccountName(t.accountId);

                                            return _buildTransactionItem(
                                                title: title,
                                                subtitle: subtitle,
                                                amount: amount,
                                                accountName: accountName,
                                                accountColor: accountColor,
                                                icon: icon,
                                                color: color,
                                                isIncome: isIncome,
                                                type: isTransfer
                                                    ? TransactionType.transfer
                                                    : t.type,
                                                isDarkMode: isDarkMode);
                                          }),
                                        ),
                                      ))
                                ],
                              );
                            },
                          ),
                  )
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(
      String label, bool isSelected, Color activeColor, bool isDarkMode,
      {IconData? icon}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? activeColor
            : (isDarkMode
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.05)),
        borderRadius: BorderRadius.circular(20),
        border: isSelected
            ? Border.all(color: Colors.transparent)
            : Border.all(
                color:
                    isDarkMode ? activeColor.withOpacity(0.5) : Colors.black12),
      ),
      child: Row(
        children: [
          // Filter Label
          Text(
            label,
            style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : (isDarkMode ? Colors.white70 : Colors.black54),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13),
          ),
          if (isSelected) ...[
            const SizedBox(width: 4),
            const Icon(Icons.check, color: Colors.white, size: 16)
          ] else if (icon != null) ...[
            const SizedBox(width: 4),
            Icon(icon,
                color: isDarkMode ? Colors.white70 : Colors.black54, size: 16)
          ]
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        title,
        style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildTransactionItem({
    required String title,
    required String subtitle,
    required String amount,
    required String accountName,
    required Color accountColor,
    required IconData icon,
    required Color color,
    required bool isIncome,
    required bool isDarkMode,
    bool hasAttachment = false,
    TransactionType type = TransactionType.expense,
  }) {
    final cardColor = isDarkMode ? const Color(0xFF1F2937) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subTextColor = isDarkMode ? Colors.blueGrey[200] : Colors.grey[600];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDarkMode
            ? []
            : [
                BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 5,
                    offset: const Offset(0, 2))
              ],
      ),
      child: Row(
        children: [
          // Leading Icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 24),
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
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: subTextColor, fontSize: 12),
                ),
              ],
            ),
          ),

          // Amount & Payment Method
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasAttachment)
                    const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(Icons.attach_file,
                            size: 16, color: Colors.grey)),
                  Text(
                    amount,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Account Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: accountColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: accountColor.withOpacity(0.3))),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      accountName == "Bancaria"
                          ? Icons.credit_card
                          : (accountName == "Ahorros"
                              ? Icons.savings
                              : Icons.payments),
                      size: 10,
                      color: accountColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      accountName,
                      style: TextStyle(
                          color: accountColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildCalendarView(DashboardProvider provider, bool isDarkMode) {
    final textColor = isDarkMode ? Colors.white : Colors.black;
    // Calendar Text Styles need adaption
    return Column(
      children: [
        TableCalendar(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          },
          eventLoader: (day) {
            return provider.getTransactionsForDay(day);
          },
          calendarStyle: CalendarStyle(
            defaultTextStyle: TextStyle(color: textColor),
            weekendTextStyle:
                TextStyle(color: isDarkMode ? Colors.white70 : Colors.black54),
            outsideTextStyle:
                TextStyle(color: isDarkMode ? Colors.white24 : Colors.black26),
            todayDecoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            selectedDecoration: const BoxDecoration(
              color: Color(0xFF64B5F6),
              shape: BoxShape.circle,
            ),
            markerDecoration: const BoxDecoration(
              color: Colors.redAccent,
              shape: BoxShape.circle,
            ),
          ),
          headerStyle: HeaderStyle(
            titleCentered: true,
            formatButtonVisible: false,
            titleTextStyle: TextStyle(
                color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
            leftChevronIcon: Icon(Icons.chevron_left, color: textColor),
            rightChevronIcon: Icon(Icons.chevron_right, color: textColor),
          ),
          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, date, events) {
              if (events.isEmpty) return null;
              final hasExpense = (events as List<TransactionEntity>)
                  .any((t) => t.amount < 0 && t.amount.abs() > 50);
              // Simple Dot
              return Positioned(
                bottom: 1,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: hasExpense ? Colors.redAccent : Colors.greenAccent,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          ),
        ),
        Divider(color: isDarkMode ? Colors.white24 : Colors.black12),
        // Day Details
        Expanded(
          child: _selectedDay == null
              ? const Center(
                  child: Text("Selecciona un día",
                      style: TextStyle(color: Colors.grey)))
              : Builder(builder: (context) {
                  final dayTransactions =
                      provider.getTransactionsForDay(_selectedDay!);
                  if (dayTransactions.isEmpty) {
                    return Center(
                        child: Text(
                            "Sin movimientos el ${DateFormat('d MMM', 'es').format(_selectedDay!)}",
                            style: const TextStyle(color: Colors.grey)));
                  }
                  return ListView(
                    padding: const EdgeInsets.only(
                        left: 16, right: 16, top: 16, bottom: 100),
                    children: dayTransactions.map((t) {
                      return Dismissible(
                        key: Key(t.id.toString()),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          color: Colors.redAccent,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (direction) {
                          if (t.id != null) {
                            final deletedTransaction = t;
                            provider.deleteTransaction(t.id!);
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: const Text('Transacción eliminada'),
                              action: SnackBarAction(
                                  label: 'DESHACER',
                                  textColor: Colors.cyanAccent,
                                  onPressed: () {
                                    provider.addTransaction(deletedTransaction);
                                  }),
                              duration: const Duration(seconds: 4),
                            ));
                          }
                        },
                        child: GestureDetector(
                          onTap: () {
                            _showTransactionDetails(
                                context, t, provider, isDarkMode);
                          },
                          child: Builder(builder: (context) {
                            bool isTransfer =
                                t.type == TransactionType.transfer ||
                                    t.description
                                        .toLowerCase()
                                        .contains('transferencia');

                            // Amount & Color Formatting
                            bool isIncome = t.amount > 0;
                            String title = t.description;
                            String subtitle =
                                DateFormat('h:mm a').format(t.date);
                            String symbol = provider.accounts
                                    .where((a) => a.id == t.accountId)
                                    .firstOrNull
                                    ?.currencySymbol ??
                                provider.currencySymbol;
                            String absAmount =
                                t.amount.abs().toStringAsFixed(2);

                            String amount;
                            Color color;
                            IconData icon;

                            if (isTransfer) {
                              final source =
                                  provider.getAccountName(t.accountId);
                              final dest = t.destinationAccountId != null
                                  ? provider
                                      .getAccountName(t.destinationAccountId!)
                                  : 'Destino';

                              title = t.description.isNotEmpty
                                  ? t.description
                                  : "Transferencia";
                              subtitle =
                                  "${DateFormat('h:mm a').format(t.date)} • $source ➔ $dest";

                              amount = "⇄ $symbol $absAmount";
                              color = isDarkMode
                                  ? Colors.white70
                                  : const Color(0xFF64B5F6);
                              icon = Icons.swap_horiz;
                            } else {
                              amount =
                                  "${isIncome ? '+' : '-'} $symbol $absAmount";
                              color = isIncome
                                  ? (isDarkMode
                                      ? Colors.greenAccent
                                      : Colors.green)
                                  : Colors.redAccent;
                              icon = isIncome
                                  ? Icons.account_balance_wallet
                                  : Icons.shopping_bag;

                              if (t.note != null && t.note!.isNotEmpty) {
                                subtitle += " • ${t.note!}";
                              } else {
                                subtitle +=
                                    " • ${isIncome ? 'Ingreso' : 'Gasto'}";
                              }
                            }

                            Color accountColor = Colors.grey;
                            if (t.accountId == 1)
                              accountColor = Colors.amber;
                            else if (t.accountId == 2)
                              accountColor = Colors.blue;
                            else if (t.accountId == 3)
                              accountColor = Colors.purpleAccent;

                            String accountName =
                                provider.getAccountName(t.accountId);

                            return _buildTransactionItem(
                              title: title,
                              subtitle: subtitle,
                              amount: amount,
                              accountName: accountName,
                              accountColor: accountColor,
                              icon: icon,
                              color: color,
                              isIncome: isIncome,
                              type: isTransfer
                                  ? TransactionType.transfer
                                  : t.type,
                              isDarkMode: isDarkMode,
                              hasAttachment: t.imagePath != null,
                            );
                          }),
                        ),
                      );
                    }).toList(),
                  );
                }),
        )
      ],
    );
  }

  void _showTransactionDetails(BuildContext context, TransactionEntity t,
      DashboardProvider provider, bool isDarkMode) {
    final backgroundColor = isDarkMode ? const Color(0xFF1E2730) : Colors.white;

    showModalBottomSheet(
      context: context,
      backgroundColor: backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        bool isTransfer = t.type == TransactionType.transfer ||
            t.description.toLowerCase().contains('transferencia');

        Color finalColor;
        String formattedAmount;
        String symbol = provider.accounts
                .where((a) => a.id == t.accountId)
                .firstOrNull
                ?.currencySymbol ??
            provider.currencySymbol;
        String absAmount = t.amount.abs().toStringAsFixed(2);

        if (isTransfer) {
          finalColor = const Color(0xFF64B5F6);
          formattedAmount = "⇄ $symbol $absAmount";
        } else if (t.amount > 0) {
          finalColor = isDarkMode ? Colors.greenAccent : Colors.green;
          formattedAmount = "+ $symbol $absAmount";
        } else {
          finalColor = Colors.redAccent;
          formattedAmount = "- $symbol $absAmount";
        }

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: finalColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isTransfer
                        ? Icons.swap_horiz
                        : (t.amount > 0
                            ? Icons.account_balance_wallet
                            : Icons.shopping_bag),
                    color: finalColor,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  formattedAmount,
                  style: TextStyle(
                    color: finalColor,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),

                // Details List
                if (isTransfer)
                  _buildDetailRow(
                      Icons.swap_horiz,
                      "Flujo",
                      "De ${provider.getAccountName(t.accountId)} hacia ${t.destinationAccountId != null ? provider.getAccountName(t.destinationAccountId!) : 'Destino'}",
                      isDarkMode)
                else
                  _buildDetailRow(
                      Icons.category, "Categoría", t.description, isDarkMode),
                _buildDetailRow(
                    Icons.calendar_today,
                    "Fecha",
                    DateFormat('EEEE d MMM, h:mm a', 'es').format(t.date),
                    isDarkMode),
                if (t.note != null && t.note!.isNotEmpty)
                  _buildDetailRow(Icons.note, "Nota", t.note!, isDarkMode),

                if (t.imagePath != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Comprobante",
                          style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () {
                            showDialog(
                                context: context,
                                builder: (_) => Dialog(
                                      backgroundColor: Colors.transparent,
                                      child: InteractiveViewer(
                                        child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            child:
                                                Image.file(File(t.imagePath!))),
                                      ),
                                    ));
                          },
                          child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(File(t.imagePath!),
                                  height: 150,
                                  width: double.infinity,
                                  fit: BoxFit.cover)),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 10),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // Delete Action
                          if (t.id != null) {
                            provider.deleteTransaction(t.id!);
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Transacción eliminada')),
                            );
                          }
                        },
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.redAccent),
                        label: const Text("Eliminar",
                            style: TextStyle(color: Colors.redAccent)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: Colors.redAccent),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // Edit Action
                          Navigator.pop(ctx); // Close Sheet
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    AddTransactionPage(transactionToEdit: t)),
                          );
                        },
                        icon: const Icon(Icons.edit, color: Colors.black),
                        label: const Text("Editar",
                            style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF64B5F6),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(
      IconData icon, String label, String value, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.grey, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 4),
                Text(value,
                    style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          )
        ],
      ),
    );
  }
}
