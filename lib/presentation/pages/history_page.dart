import 'package:flutter/material.dart';
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
  String _selectedCategory = 'Todos';
  bool _isCalendarView = false;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  // Mapping simple chips for MVP
  final List<String> _filterOptions = [
    'Todos',
    'Comida',
    'Transporte',
    'Compras',
    'Ocio'
  ];

  @override
  Widget build(BuildContext context) {
    // Definición de colores oscuros
    const backgroundColor = Color(0xFF121C22);
    const primaryBlue = Color(0xFF007BFF);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        centerTitle: true,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.person, color: Colors.white, size: 20),
        ),
        title: const Text(
          "Historial",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(_isCalendarView ? Icons.list : Icons.calendar_month,
                color: Colors.white),
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
              color: Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.search, color: Colors.white, size: 24),
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
      body: Consumer<DashboardProvider>(
        builder: (context, provider, child) {
          if (_isCalendarView) {
            return _buildCalendarView(provider);
          }

          // ... (Existing List View Logic) ...
          final grouped = <String, List<TransactionEntity>>{};
          final now = DateTime.now();

          // Apply Filter
          var displayedTransactions = provider.transactions;
          if (_selectedCategory != 'Todos') {
            displayedTransactions = displayedTransactions
                .where((t) => t.description == _selectedCategory)
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
              // 1. Filtros Horizontales
              SizedBox(
                height: 60,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  itemCount: _filterOptions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final label = _filterOptions[index];
                    final isSelected = label == _selectedCategory;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCategory = label;
                        });
                      },
                      child: _buildFilterChip(
                        label,
                        isSelected,
                        primaryBlue,
                      ),
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
                        padding: const EdgeInsets.symmetric(horizontal: 16),
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
                                      if (t.id != null) {
                                        provider.deleteTransaction(t.id!);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                          content:
                                              Text('Transacción eliminada'),
                                        ));
                                      }
                                    },
                                    child: GestureDetector(
                                      onTap: () {
                                        _showTransactionDetails(
                                            context, t, provider);
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
                                            DateFormat('h:mm a').format(t.date);

                                        // Amount & Color Formatting
                                        bool isIncome = t.amount > 0;
                                        String symbol = provider.currencySymbol;
                                        String absAmount =
                                            t.amount.abs().toStringAsFixed(2);

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
                                          color = const Color(0xFF64B5F6);
                                          icon = Icons.swap_horiz;
                                        } else {
                                          amount =
                                              "${isIncome ? '+' : '-'} $symbol $absAmount";
                                          color = isIncome
                                              ? Colors.greenAccent
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

                                        return _buildTransactionItem(
                                          title: title,
                                          subtitle: subtitle,
                                          amount: amount,
                                          paymentMethod: "CASH",
                                          icon: icon,
                                          color: color,
                                          isIncome: isIncome,
                                          type: isTransfer
                                              ? TransactionType.transfer
                                              : t.type,
                                        );
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
  }

  Widget _buildFilterChip(String label, bool isSelected, Color activeColor,
      {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? activeColor : Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: isSelected ? null : Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
                color: Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13),
          ),
          if (isSelected) ...[
            const SizedBox(width: 4),
            const Icon(Icons.check, color: Colors.white, size: 16)
          ] else if (icon != null) ...[
            const SizedBox(width: 4),
            Icon(icon, color: Colors.white70, size: 16)
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
    required String paymentMethod,
    required IconData icon,
    required Color color,
    required bool isIncome,
    TransactionType type = TransactionType.expense,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.transparent, // Minimalist transparent look
        border: Border(
            bottom: BorderSide(
                color: Colors.white.withOpacity(0.05))), // Subtle separator
      ),
      child: Row(
        children: [
          // Leading Icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15), // Dynamic background opacity
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
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
              ],
            ),
          ),

          // Amount & Payment Method
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                paymentMethod,
                style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 10,
                    fontWeight: FontWeight.w600),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildCalendarView(DashboardProvider provider) {
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
            defaultTextStyle: const TextStyle(color: Colors.white),
            weekendTextStyle: const TextStyle(color: Colors.white70),
            outsideTextStyle: const TextStyle(color: Colors.white24),
            todayDecoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            selectedDecoration: const BoxDecoration(
              color: const Color(0xFF64B5F6),
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
            titleTextStyle: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            leftChevronIcon:
                const Icon(Icons.chevron_left, color: Colors.white),
            rightChevronIcon:
                const Icon(Icons.chevron_right, color: Colors.white),
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
        const Divider(color: Colors.white24),
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
                    padding: const EdgeInsets.all(16),
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
                            provider.deleteTransaction(t.id!);
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Transacción eliminada')));
                          }
                        },
                        child: GestureDetector(
                          onTap: () {
                            _showTransactionDetails(context, t, provider);
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
                            String symbol = provider.currencySymbol;
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
                              color = const Color(0xFF64B5F6);
                              icon = Icons.swap_horiz;
                            } else {
                              amount =
                                  "${isIncome ? '+' : '-'} $symbol $absAmount";
                              color = isIncome
                                  ? Colors.greenAccent
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

                            return _buildTransactionItem(
                              title: title,
                              subtitle: subtitle,
                              amount: amount,
                              paymentMethod: "CASH",
                              icon: icon,
                              color: color,
                              isIncome: isIncome,
                              type: isTransfer
                                  ? TransactionType.transfer
                                  : t.type,
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

  void _showTransactionDetails(
      BuildContext context, TransactionEntity t, DashboardProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E2730),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        bool isTransfer = t.type == TransactionType.transfer ||
            t.description.toLowerCase().contains('transferencia');

        Color finalColor;
        String formattedAmount;
        String symbol = provider.currencySymbol;
        String absAmount = t.amount.abs().toStringAsFixed(2);

        if (isTransfer) {
          finalColor = const Color(0xFF64B5F6);
          formattedAmount = "⇄ $symbol $absAmount";
        } else if (t.amount > 0) {
          finalColor = Colors.greenAccent;
          formattedAmount = "+ $symbol $absAmount";
        } else {
          finalColor = Colors.redAccent;
          formattedAmount = "- $symbol $absAmount";
        }

        return Padding(
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
                _buildDetailRow(Icons.swap_horiz, "Flujo",
                    "De ${provider.getAccountName(t.accountId)} hacia ${t.destinationAccountId != null ? provider.getAccountName(t.destinationAccountId!) : 'Destino'}")
              else
                _buildDetailRow(Icons.category, "Categoría", t.description),
              _buildDetailRow(Icons.calendar_today, "Fecha",
                  DateFormat('EEEE d MMM, h:mm a', 'es').format(t.date)),
              if (t.note != null && t.note!.isNotEmpty)
                _buildDetailRow(Icons.note, "Nota", t.note!),

              const SizedBox(height: 32),

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
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.grey, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 4),
              Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500)),
            ],
          )
        ],
      ),
    );
  }
}
