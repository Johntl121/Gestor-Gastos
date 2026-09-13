import 'package:flutter/material.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

// Providers
import '../../providers/transaction_provider.dart';
import '../../providers/wallet_provider.dart';

// Entities
import '../../../domain/entities/transaction_entity.dart';
import '../../../core/utils/currency_formatter.dart';

import '../../../core/constants/app_filters.dart';
import '../../../core/constants/app_categories.dart';
import '../../../core/constants/app_strings.dart';
import 'transaction_search_delegate.dart';
import 'add_transaction_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  Map<String, dynamic> _selectedFilter = {'label': 'Todos', 'type': 'all'};

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
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
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
        title: Text(
          AppStrings.historyTitle,
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
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(Icons.search, color: iconColor, size: 24),
              onPressed: () {
                final txList =
                    Provider.of<TransactionProvider>(context, listen: false)
                        .transactions;
                showSearch(
                  context: context,
                  delegate: TransactionSearchDelegate(txList),
                );
              },
            ),
          )
        ],
      ),
      body: _isCalendarView
          ? _CalendarViewSection(
              focusedDay: _focusedDay,
              selectedDay: _selectedDay,
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
            )
          : Column(
              children: [
                // --- Static Filters Bar ---
                _FiltersBar(
                  selectedFilter: _selectedFilter,
                  onFilterChanged: (newFilter) {
                    setState(() {
                      _selectedFilter = newFilter;
                    });
                  },
                ),

                // --- Real Grouped Transactions List ---
                Expanded(
                  child: _TransactionListView(selectedFilter: _selectedFilter),
                ),
              ],
            ),
    );
  }
}

// --- TOP LEVEL HELPER FOR TRANSACTION DETAILS MODAL ---

void _showTransactionDetails(BuildContext context, TransactionEntity t,
    WalletProvider walletProvider, bool isDarkMode) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF15202B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Detalles de Transacción",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87)),
                  IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                AddTransactionPage(transactionToEdit: t),
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit, color: Colors.blueAccent))
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: t.amount > 0
                                ? Colors.green.withValues(alpha: 0.1)
                                : Colors.redAccent.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            t.amount > 0
                                ? Icons.arrow_upward
                                : Icons.arrow_downward,
                            size: 40,
                            color:
                                t.amount > 0 ? Colors.green : Colors.redAccent,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "${walletProvider.currencySymbol} ${t.amount.abs().toStringAsFixed(2)}",
                          style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color:
                                  isDarkMode ? Colors.white : Colors.black87),
                        ),
                        Text(
                          t.description,
                          style: TextStyle(
                              fontSize: 16,
                              color: isDarkMode
                                  ? Colors.grey[400]
                                  : Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  _DetailRowWidget(
                      icon: Icons.calendar_today,
                      label: "Fecha",
                      value: DateFormat('d MMM y, h:mm a').format(t.date),
                      isDarkMode: isDarkMode),
                  _DetailRowWidget(
                      icon: Icons.account_balance,
                      label: "Cuenta",
                      value: walletProvider.getAccountName(t.accountId),
                      isDarkMode: isDarkMode),
                  _DetailRowWidget(
                      icon: Icons.category,
                      label: "Categoría",
                      value: t.description,
                      isDarkMode: isDarkMode),
                  if (t.note != null && t.note!.isNotEmpty)
                    _DetailRowWidget(
                        icon: Icons.notes,
                        label: "Nota",
                        value: t.note!,
                        isDarkMode: isDarkMode),
                  if (t.imagePath != null &&
                      File(t.imagePath!).existsSync()) ...[
                    const SizedBox(height: 20),
                    const Text("Adjunto",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(t.imagePath!),
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    )
                  ]
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(
                            color: Colors.redAccent.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16))),
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Row(
                        children: [
                          Icon(Icons.swipe,
                              color: Colors.orangeAccent, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                              child: Text("Desliza en la lista para eliminar")),
                        ],
                      )));
                    },
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.redAccent),
                    label: const Text("Eliminar Transacción",
                        style: TextStyle(color: Colors.redAccent))),
              ),
            )
          ],
        ),
      );
    },
  );
}

class _DetailRowWidget extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDarkMode;

  const _DetailRowWidget({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.white10 : Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon,
                size: 20,
                color: isDarkMode ? Colors.white70 : Colors.grey[700]),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        color:
                            isDarkMode ? Colors.grey[400] : Colors.grey[600])),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isDarkMode ? Colors.white : Colors.black87)),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// --- DECOMPOSED WIDGETS WITH CONST CONSTRUCTORS ---

class _FiltersBar extends StatelessWidget {
  final Map<String, dynamic> selectedFilter;
  final ValueChanged<Map<String, dynamic>> onFilterChanged;

  const _FiltersBar({
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Consumer<WalletProvider>(
      builder: (context, walletProvider, _) {
        final dynamicFilters =
            AppFilters.getHistoryFilters(walletProvider.accounts);

        return SizedBox(
          height: 60,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            itemCount: dynamicFilters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final filter = dynamicFilters[index];

              if (filter['type'] == 'separator') {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 1,
                  height: 20,
                  color: isDarkMode ? Colors.white24 : Colors.black12,
                );
              }

              final isSelected = filter['label'] == selectedFilter['label'];
              final color = filter['color'] as Color;

              return GestureDetector(
                onTap: () => onFilterChanged(filter),
                child: _FilterChipWidget(
                  label: filter['label'],
                  isSelected: isSelected,
                  activeColor: color,
                  isDarkMode: isDarkMode,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _FilterChipWidget extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color activeColor;
  final bool isDarkMode;

  const _FilterChipWidget({
    required this.label,
    required this.isSelected,
    required this.activeColor,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? activeColor
            : (isDarkMode
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05)),
        borderRadius: BorderRadius.circular(20),
        border: isSelected
            ? Border.all(color: Colors.transparent)
            : Border.all(
                color: isDarkMode
                    ? activeColor.withValues(alpha: 0.5)
                    : Colors.black12),
      ),
      child: Row(
        children: [
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
          ]
        ],
      ),
    );
  }
}

class _TransactionListView extends StatefulWidget {
  final Map<String, dynamic> selectedFilter;

  const _TransactionListView({required this.selectedFilter});

  @override
  State<_TransactionListView> createState() => _TransactionListViewState();
}

class _TransactionListViewState extends State<_TransactionListView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final provider = Provider.of<TransactionProvider>(context, listen: false);
      if (!provider.isLoadingMore && provider.hasMore) {
        provider.loadMoreTransactions();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Consumer2<TransactionProvider, WalletProvider>(
      builder: (context, transactionProvider, walletProvider, _) {
        final grouped = <String, List<TransactionEntity>>{};
        final now = DateTime.now();

        var displayedTransactions = transactionProvider.transactions;
        final type = widget.selectedFilter['type'];
        final value = widget.selectedFilter['value'];

        if (type == 'type') {
          displayedTransactions =
              displayedTransactions.where((t) => t.type == value).toList();
        } else if (type == 'account') {
          displayedTransactions =
              displayedTransactions.where((t) => t.accountId == value).toList();
        } else if (type == 'category') {
          displayedTransactions = displayedTransactions
              .where((t) => t.description == value)
              .toList();
        } else if (type == 'goal') {
          displayedTransactions = displayedTransactions
              .where((t) => t.description.contains(value))
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

        if (grouped.isEmpty) {
          return Center(
            child: Text(AppStrings.historyNoTransactions,
                style: TextStyle(color: Colors.grey[600])),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          padding:
              const EdgeInsets.only(left: 16, right: 16, top: 10, bottom: 24),
          itemCount:
              grouped.keys.length + (transactionProvider.isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == grouped.keys.length) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final key = grouped.keys.elementAt(index);
            final transactions = grouped[key]!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    key,
                    style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2),
                  ),
                ),
                ...transactions.map((t) => _DismissibleTransactionCard(
                      transaction: t,
                      walletProvider: walletProvider,
                      transactionProvider: transactionProvider,
                      isDarkMode: isDarkMode,
                    )),
              ],
            );
          },
        );
      },
    );
  }
}

class _DismissibleTransactionCard extends StatelessWidget {
  final TransactionEntity transaction;
  final WalletProvider walletProvider;
  final TransactionProvider transactionProvider;
  final bool isDarkMode;

  const _DismissibleTransactionCard({
    required this.transaction,
    required this.walletProvider,
    required this.transactionProvider,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(transaction.id.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        color: Colors.redAccent,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) async {
        final deletedTransaction = transaction;
        if (transaction.id != null) {
          await transactionProvider.deleteTransaction(transaction.id!);
          await walletProvider.loadWalletData();

          if (context.mounted) {
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Text('Transacción eliminada'),
              action: SnackBarAction(
                  label: 'DESHACER',
                  textColor: Colors.cyanAccent,
                  onPressed: () async {
                    await transactionProvider
                        .addTransaction(deletedTransaction);
                    await walletProvider.loadWalletData();
                  }),
              duration: const Duration(seconds: 4),
            ));
          }
        }
      },
      child: GestureDetector(
        onTap: () {
          _showTransactionDetails(
              context, transaction, walletProvider, isDarkMode);
        },
        child: _TransactionItemCard(
          transaction: transaction,
          walletProvider: walletProvider,
          isDarkMode: isDarkMode,
        ),
      ),
    );
  }
}

class _TransactionItemCard extends StatelessWidget {
  final TransactionEntity transaction;
  final WalletProvider walletProvider;
  final bool isDarkMode;

  const _TransactionItemCard({
    required this.transaction,
    required this.walletProvider,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final t = transaction;
    bool isTransfer = t.type == TransactionType.transfer ||
        t.description.toLowerCase().contains('transferencia');

    String title = t.description;
    String subtitle = DateFormat('h:mm a').format(t.date);

    bool isIncome = t.amount > 0;
    String symbol = walletProvider.accounts
            .where((a) => a.id == t.accountId)
            .firstOrNull
            ?.currencySymbol ??
        walletProvider.currencySymbol;

    final account =
        walletProvider.accounts.where((a) => a.id == t.accountId).firstOrNull;

    Color accountColor =
        account != null ? Color(account.colorValue) : Colors.grey;
    String accountName = account?.name ?? 'Cuenta Desconocida';
    IconData accountIcon =
        account != null ? account.displayIcon : Icons.account_balance_wallet;

    String amount;
    Color color;
    IconData icon;

    if (isTransfer) {
      final source = walletProvider.getAccountName(t.accountId);
      final dest = t.destinationAccountId != null
          ? walletProvider.getAccountName(t.destinationAccountId!)
          : 'Destino';

      title = t.description.isNotEmpty ? t.description : "Transferencia";
      subtitle = "${DateFormat('h:mm a').format(t.date)} • $source ➔ $dest";

      amount = "⇄ ${CurrencyFormatter.format(t.amount.abs(), symbol)}";
      color = isDarkMode ? Colors.white70 : const Color(0xFF64B5F6);
      icon = Icons.swap_horiz;
    } else {
      amount = CurrencyFormatter.formatWithSign(t.amount, symbol);

      color = isIncome
          ? (isDarkMode ? Colors.greenAccent : Colors.green)
          : Colors.redAccent;

      if (t.colorValue != null) {
        color = Color(t.colorValue!);
      }

      icon = AppCategories.getIcon(t.categoryId);

      if (t.iconCode != null) {
        icon = IconData(t.iconCode!, fontFamily: 'MaterialIcons');
      }

      if (t.note != null && t.note!.isNotEmpty) {
        subtitle += " • ${t.note!}";
      } else {
        subtitle += " • ${isIncome ? 'Ingreso' : 'Gasto'}";
      }
    }

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
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 5,
                    offset: const Offset(0, 2))
              ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (isTransfer ? TransactionType.transfer : t.type) ==
                      TransactionType.expense
                  ? Colors.redAccent.withValues(alpha: 0.15)
                  : color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: (isTransfer ? TransactionType.transfer : t.type) ==
                        TransactionType.expense
                    ? Colors.redAccent.withValues(alpha: 0.1)
                    : color.withValues(alpha: 0.1),
              ),
            ),
            child: Icon(
              icon,
              color: (isTransfer ? TransactionType.transfer : t.type) ==
                      TransactionType.expense
                  ? Colors.redAccent
                  : color,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: subTextColor, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (t.imagePath != null && t.imagePath!.isNotEmpty)
                    const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(Icons.attach_file,
                            size: 16, color: Colors.grey)),
                  Text(
                    amount,
                    style: TextStyle(
                        color:
                            (isTransfer ? TransactionType.transfer : t.type) ==
                                    TransactionType.expense
                                ? Colors.redAccent
                                : color,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accountColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      accountIcon,
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
}

class _CalendarViewSection extends StatelessWidget {
  final DateTime focusedDay;
  final DateTime? selectedDay;
  final void Function(DateTime, DateTime) onDaySelected;

  const _CalendarViewSection({
    required this.focusedDay,
    required this.selectedDay,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black;

    return Consumer<TransactionProvider>(
      builder: (context, provider, _) {
        return Column(
          children: [
            TableCalendar(
              locale: 'es_ES',
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: focusedDay,
              selectedDayPredicate: (day) => isSameDay(selectedDay, day),
              onDaySelected: onDaySelected,
              eventLoader: (day) {
                return provider.transactions
                    .where((t) =>
                        t.date.year == day.year &&
                        t.date.month == day.month &&
                        t.date.day == day.day)
                    .toList();
              },
              calendarStyle: CalendarStyle(
                defaultTextStyle: TextStyle(color: textColor),
                weekendTextStyle: TextStyle(
                    color: isDarkMode ? Colors.white70 : Colors.black54),
                outsideTextStyle: TextStyle(
                    color: isDarkMode ? Colors.white24 : Colors.black26),
                todayDecoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.05),
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
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
                leftChevronIcon: Icon(Icons.chevron_left, color: textColor),
                rightChevronIcon: Icon(Icons.chevron_right, color: textColor),
              ),
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, date, events) {
                  if (events.isEmpty) return null;
                  final hasExpense = (events as List<TransactionEntity>)
                      .any((t) => t.amount < 0 && t.amount.abs() > 50);
                  return Positioned(
                    bottom: 1,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color:
                            hasExpense ? Colors.redAccent : Colors.greenAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                },
              ),
            ),
            Divider(color: isDarkMode ? Colors.white24 : Colors.black12),
            Expanded(
              child: selectedDay == null
                  ? const Center(
                      child: Text("Selecciona un día",
                          style: TextStyle(color: Colors.grey)))
                  : FutureBuilder<List<TransactionEntity>>(
                      future: provider.getTransactionsForDay(selectedDay!),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        final dayTransactions = snapshot.data ?? [];

                        if (dayTransactions.isEmpty) {
                          return Center(
                              child: Text(
                                  "Sin movimientos el ${DateFormat('d MMM', 'es').format(selectedDay!)}",
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
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                color: Colors.redAccent,
                                child: const Icon(Icons.delete,
                                    color: Colors.white),
                              ),
                              onDismissed: (direction) async {
                                if (t.id != null) {
                                  final deletedTransaction = t;
                                  await provider.deleteTransaction(t.id!);
                                  if (context.mounted) {
                                    Provider.of<WalletProvider>(context,
                                            listen: false)
                                        .loadWalletData();

                                    ScaffoldMessenger.of(context)
                                        .clearSnackBars();
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(SnackBar(
                                      content:
                                          const Text('Transacción eliminada'),
                                      action: SnackBarAction(
                                          label: 'DESHACER',
                                          textColor: Colors.cyanAccent,
                                          onPressed: () async {
                                            await provider.addTransaction(
                                                deletedTransaction);
                                            if (context.mounted) {
                                              Provider.of<WalletProvider>(
                                                      context,
                                                      listen: false)
                                                  .loadWalletData();
                                            }
                                          }),
                                      duration: const Duration(seconds: 4),
                                    ));
                                  }
                                }
                              },
                              child: GestureDetector(
                                onTap: () {
                                  _showTransactionDetails(
                                      context,
                                      t,
                                      Provider.of<WalletProvider>(context,
                                          listen: false),
                                      isDarkMode);
                                },
                                child: _CalendarTransactionTile(
                                  transaction: t,
                                  isDarkMode: isDarkMode,
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      }),
            ),
          ],
        );
      },
    );
  }
}

class _CalendarTransactionTile extends StatelessWidget {
  final TransactionEntity transaction;
  final bool isDarkMode;

  const _CalendarTransactionTile({
    required this.transaction,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final t = transaction;
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    bool isTransfer = t.type == TransactionType.transfer ||
        t.description.toLowerCase().contains('transferencia');
    String title = t.description;
    String subtitle = DateFormat('h:mm a').format(t.date);
    bool isIncome = t.amount > 0;
    String symbol = walletProvider.currencySymbol;

    String amountString = CurrencyFormatter.formatWithSign(t.amount, symbol);
    Color color = isIncome
        ? (isDarkMode ? Colors.greenAccent : Colors.green)
        : Colors.redAccent;
    IconData icon =
        isIncome ? Icons.account_balance_wallet : Icons.shopping_bag;

    if (isTransfer) {
      amountString = "⇄ ${CurrencyFormatter.format(t.amount.abs(), symbol)}";
      color = Colors.blueAccent;
      icon = Icons.swap_horiz;
    }

    return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1F2937) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              if (!isDarkMode)
                const BoxShadow(
                    color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
            ]),
        child: Row(children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold)),
                Text(subtitle,
                    style: const TextStyle(color: Colors.grey, fontSize: 12))
              ])),
          Text(amountString,
              style: TextStyle(color: color, fontWeight: FontWeight.bold))
        ]));
  }
}
