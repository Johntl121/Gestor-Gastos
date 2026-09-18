import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:provider/provider.dart';
import '../../providers/ui_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../../data/models/subscription.dart';
import '../../../domain/entities/goal_entity.dart';
import '../../../domain/entities/account_entity.dart';
import 'widgets/add_account_sheet.dart';
import 'widgets/goal_form_sheet.dart';
import 'widgets/goal_card.dart';
import 'widgets/add_fixed_expense_sheet.dart';
import 'widgets/fixed_expense_card.dart';
import 'widgets/goal_detail_sheet.dart';
import '../../../core/constants/app_categories.dart';
import '../../../core/constants/icon_mapper.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/entities/reminder.dart';
import '../../providers/reminder_provider.dart';
import '../reminders/reminders_page.dart';
import '../reminders/widgets/reminder_card.dart';
import '../reminders/widgets/reminder_form_sheet.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  // Flag to lock scroll during reordering
  bool _isDragging = false;

  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
    // Verificar si hay un pago pendiente desde una notificación
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndOpenPendingPayment();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  // --- DIALOGS & ACTIONS ---

  void _showGoalFormDialog(BuildContext context, {GoalEntity? toEdit}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GoalFormSheet(goalToEdit: toEdit),
    );
  }

  void _showAddAccountSheet(BuildContext context,
      {AccountEntity? accountToEdit}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddAccountSheet(accountToEdit: accountToEdit),
    );
  }

  void _showGoalDetails(BuildContext context, GoalEntity goal) {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (ctx) => GoalDetailSheet(
              goal: goal,
              onConfettiTrigger: () => _confettiController.play(),
            ));
  }

  /// Verifica si hay un gasto pendiente desde notificación y abre el dialog
  void _checkAndOpenPendingPayment() {
    if (!mounted) return;
    final uiProvider = Provider.of<UiProvider>(context, listen: false);
    final pending = uiProvider.pendingPaySubscription;
    if (pending != null) {
      uiProvider.setPendingPaySubscription(null); // limpiar antes de abrir
      _showPaymentDialog(context, pending);
    }
  }

  /// Muestra el dialog de pago para una Subscription dada
  void _showPaymentDialog(BuildContext context, Subscription sub) {
    if (sub.isPaid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 20),
              SizedBox(width: 8),
              Text("Ya pagaste este gasto este mes"),
            ],
          ),
        ),
      );
      return;
    }
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (ctx) {
        int selectedAccountId = walletProvider.accounts.isNotEmpty
            ? walletProvider.accounts.first.id
            : 1;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28)),
              backgroundColor: const Color(0xFF1E2435),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Color(sub.customColor ??
                            AppCategories.getColor(sub.categoryId).toARGB32()),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(sub.customColor ??
                                    AppCategories.getColor(sub.categoryId)
                                        .toARGB32())
                                .withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Icon(
                        sub.customIcon != null
                            ? IconMapper.getIcon(sub.customIcon)
                            : AppCategories.getIcon(sub.categoryId),
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Pagar ${sub.name}",
                      style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                          fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      CurrencyFormatter.format(
                          sub.amount,
                          walletProvider.accounts
                              .firstWhere((a) => a.id == selectedAccountId,
                                  orElse: () => walletProvider.accounts.first)
                              .currencySymbol),
                      style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent),
                    ),
                    const SizedBox(height: 32),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Cuenta origen:",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 12),
                    if (walletProvider.accounts.isNotEmpty)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          alignment: WrapAlignment.center,
                          children: walletProvider.accounts.map((acc) {
                            final isSelected = acc.id == selectedAccountId;
                            return GestureDetector(
                              onTap: () => setDialogState(
                                  () => selectedAccountId = acc.id),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Color(acc.colorValue)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? Color(acc.colorValue)
                                        : Colors.grey.withValues(alpha: 0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(acc.displayIcon,
                                        size: 16,
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.grey.shade400),
                                    const SizedBox(width: 4),
                                    Text(acc.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.grey.shade400,
                                        )),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: () async {
                          final subToPay =
                              sub.copyWith(accountToCharge: selectedAccountId);
                          final transactionProvider =
                              Provider.of<TransactionProvider>(context,
                                  listen: false);
                          final walletProvider = Provider.of<WalletProvider>(
                              context,
                              listen: false);

                          await transactionProvider
                              .markSubscriptionAsPaid(subToPay);

                          // Sincronizar saldos de cuenta en WalletProvider
                          if (mounted) {
                            await walletProvider.loadWalletData();
                          }

                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.cyan,
                          foregroundColor: const Color(0xFF0F172A),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text("Confirmar Pago",
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey.shade400,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text("Cancelar",
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _setDragging(bool dragging) {
    if (_isDragging != dragging) {
      setState(() {
        _isDragging = dragging;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final backgroundColor = theme.scaffoldBackgroundColor;
    final textColor = theme.textTheme.titleLarge?.color ?? Colors.black;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        title: Text("Billetera",
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Stack(
        alignment: Alignment.topCenter,
        children: [
          SingleChildScrollView(
            physics: _isDragging
                ? const NeverScrollableScrollPhysics()
                : const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                // --- Accounts Section ---
                _AccountsSection(
                  onAddAccount: () => _showAddAccountSheet(context),
                  onEditAccount: (acc) =>
                      _showAddAccountSheet(context, accountToEdit: acc),
                ),

                const SizedBox(height: 40),

                // --- Goals Section ---
                _GoalsSection(
                  onAddGoal: () => _showGoalFormDialog(context),
                  onEditGoal: (goal) =>
                      _showGoalFormDialog(context, toEdit: goal),
                  onShowDetails: (goal) => _showGoalDetails(context, goal),
                  onDraggingChanged: _setDragging,
                ),

                const SizedBox(height: 40),

                // --- Fixed Expenses Section ---
                _FixedExpensesSection(
                  onAddExpense: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (ctx) => const AddFixedExpenseSheet(),
                    );
                  },
                  onEditExpense: (sub) {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (ctx) =>
                          AddFixedExpenseSheet(subscriptionToEdit: sub),
                    );
                  },
                  onPayExpense: (sub) => _showPaymentDialog(context, sub),
                  onDraggingChanged: _setDragging,
                  isDarkMode: isDarkMode,
                ),

                const SizedBox(height: 40),

                // --- Reminders Section ---
                const RemindersSummarySection(),

                const SizedBox(height: 120),
              ],
            ),
          ),
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [
              Colors.cyan,
              Colors.purple,
              Colors.amber,
              Colors.green
            ],
          ),
        ],
      ),
    );
  }
}

// --- DECOMPOSED WIDGETS WITH CONST CONSTRUCTORS & SCOPED CONSUMERS ---

Widget _proxyDecorator(Widget child, int index, Animation<double> animation) {
  return AnimatedBuilder(
    animation: animation,
    builder: (BuildContext context, Widget? child) {
      return Material(
        elevation: 0,
        color: Colors.transparent,
        child: Transform.scale(
          scale: 1.05,
          child: Opacity(
            opacity: 0.9,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: child,
            ),
          ),
        ),
      );
    },
    child: child,
  );
}

class _AccountsSection extends StatelessWidget {
  final VoidCallback onAddAccount;
  final void Function(AccountEntity) onEditAccount;

  const _AccountsSection({
    required this.onAddAccount,
    required this.onEditAccount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return SizedBox(
      height: 200,
      child: Consumer<WalletProvider>(
        builder: (context, walletProvider, _) {
          final accounts = walletProvider.accounts;
          return PageView.builder(
            controller: PageController(viewportFraction: 0.9),
            itemCount: accounts.length + 1,
            itemBuilder: (context, index) {
              if (index < accounts.length) {
                final account = accounts[index];
                return GestureDetector(
                  onTap: () => onEditAccount(account),
                  child: _AccountCard(account: account),
                );
              } else {
                return GestureDetector(
                  onTap: onAddAccount,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.white10 : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                          color: isDarkMode
                              ? Colors.white24
                              : Colors.grey.shade400,
                          style: BorderStyle.solid),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_circle_outline,
                              size: 45,
                              color: isDarkMode ? Colors.white54 : Colors.grey),
                          const SizedBox(height: 8),
                          Text("Añadir Cuenta",
                              style: TextStyle(
                                  color:
                                      isDarkMode ? Colors.white54 : Colors.grey,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold))
                        ],
                      ),
                    ),
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final AccountEntity account;

  const _AccountCard({required this.account});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Color(account.colorValue),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 5),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                account.displayIcon,
                color: Colors.white70,
                size: 34,
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz, color: Colors.white70),
                color: const Color(0xFF1E293B),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                onSelected: (value) {
                  final provider =
                      Provider.of<WalletProvider>(context, listen: false);
                  if (value == 'edit') {
                    // Call sheet via provider contextual reference or notify parent indirectly
                    // Since context in popup menu is disconnected, let's open modal securely
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (ctx) => AddAccountSheet(accountToEdit: account),
                    );
                  } else if (value == 'delete') {
                    provider.softDeleteAccount(account);
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(
                          content: Text("Cuenta '${account.name}' eliminada."),
                          duration: const Duration(seconds: 4),
                          action: SnackBarAction(
                              label: "DESHACER",
                              textColor: Colors.cyanAccent,
                              onPressed: () {
                                provider.undoDeleteAccount(account);
                              }),
                        ))
                        .closed
                        .then((reason) {
                      if (reason != SnackBarClosedReason.action) {
                        provider.confirmDeleteAccount(account.id);
                      }
                    });
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit, color: Colors.cyanAccent),
                        SizedBox(width: 8),
                        Text('Editar', style: TextStyle(color: Colors.white))
                      ])),
                  const PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete, color: Colors.redAccent),
                        SizedBox(width: 8),
                        Text('Eliminar', style: TextStyle(color: Colors.white))
                      ])),
                ],
              )
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                account.name,
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(
                CurrencyFormatter.format(
                    account.currentBalance, account.currencySymbol),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoalsSection extends StatelessWidget {
  final VoidCallback onAddGoal;
  final void Function(GoalEntity) onEditGoal;
  final void Function(GoalEntity) onShowDetails;
  final void Function(bool) onDraggingChanged;

  const _GoalsSection({
    required this.onAddGoal,
    required this.onEditGoal,
    required this.onShowDetails,
    required this.onDraggingChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.titleLarge?.color ?? Colors.black;

    return Consumer<WalletProvider>(
      builder: (context, walletProvider, _) {
        final goals = walletProvider.goals;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Mis Metas (${goals.length})",
                    style: TextStyle(
                        color: textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  GestureDetector(
                    onTap: onAddGoal,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E5FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child:
                          const Icon(Icons.add, color: Colors.white, size: 24),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (goals.isEmpty)
              Padding(
                padding: const EdgeInsets.all(40.0),
                child: Center(
                  child: Text(
                    "No tienes metas activas.\n¡Crea una para empezar a ahorrar!",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: isDarkMode ? Colors.blueGrey[200] : Colors.grey),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  proxyDecorator: _proxyDecorator,
                  onReorder: (oldIndex, newIndex) {
                    walletProvider.reorderGoals(oldIndex, newIndex);
                  },
                  onReorderStart: (_) => onDraggingChanged(true),
                  onReorderEnd: (_) => onDraggingChanged(false),
                  itemCount: goals.length,
                  itemBuilder: (context, index) {
                    final goal = goals[index];
                    String currency = walletProvider.currencySymbol;
                    if (goal.accountId != null) {
                      try {
                        currency = walletProvider.accounts
                            .firstWhere((a) => a.id == goal.accountId)
                            .currencySymbol;
                      } catch (e) {
                        // ignore
                      }
                    }

                    return Container(
                      key: ValueKey(goal.id),
                      child: GoalCard(
                        name: goal.name,
                        currentAmount: goal.currentAmount,
                        targetAmount: goal.targetAmount,
                        color: Color(goal.colorValue),
                        icon: goal.icon,
                        currencySymbol: currency,
                        deadline: goal.deadline,
                        isCompleted: goal.isCompleted,
                        onTap: () => onShowDetails(goal),
                        onEdit: () => onEditGoal(goal),
                        onDelete: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text("Eliminar Meta"),
                              content: const Text(
                                  "¿Estás seguro de eliminar esta meta? Esto no se puede deshacer."),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text("Cancelar")),
                                ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red),
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text("Eliminar"))
                              ],
                            ),
                          );
                          if (confirm == true) {
                            walletProvider.deleteGoal(goal.id.toString());
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _FixedExpensesSection extends StatelessWidget {
  final VoidCallback onAddExpense;
  final void Function(Subscription) onEditExpense;
  final void Function(Subscription) onPayExpense;
  final void Function(bool) onDraggingChanged;
  final bool isDarkMode;

  const _FixedExpensesSection({
    required this.onAddExpense,
    required this.onEditExpense,
    required this.onPayExpense,
    required this.onDraggingChanged,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionProvider>(
      builder: (context, provider, _) {
        final subscriptions = provider.subscriptions;
        final walletProvider =
            Provider.of<WalletProvider>(context, listen: false);
        final currencySymbol = walletProvider.currencySymbol;

        double totalFixed = 0.0;
        for (var sub in subscriptions) {
          String subCurrency = 'S/';
          try {
            final acc = walletProvider.accounts
                .firstWhere((a) => a.id == sub.accountToCharge);
            subCurrency = acc.currencySymbol;
          } catch (e) {
            // Ignore if account not found
          }

          totalFixed += walletProvider.currencyConverter
              .convert(sub.amount, subCurrency, currencySymbol);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    "Gastos Fijos",
                    style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "Total: ${CurrencyFormatter.format(totalFixed, currencySymbol)}",
                      style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: onAddExpense,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                          color: const Color(0xFFD500F9),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFD500F9)
                                  .withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            )
                          ]),
                      child:
                          const Icon(Icons.add, color: Colors.white, size: 26),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            if (subscriptions.isEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                child: SizedBox(
                  width: double.infinity,
                  child: Center(
                    child: Text(
                      "No tienes gastos fijos registrados.\n¡Agrega uno para empezar!",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: isDarkMode ? Colors.grey : Colors.grey[600]),
                    ),
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  proxyDecorator: _proxyDecorator,
                  onReorderStart: (_) => onDraggingChanged(true),
                  onReorderEnd: (_) => onDraggingChanged(false),
                  itemCount: subscriptions.length,
                  onReorder: (oldIndex, newIndex) {
                    provider.reorderSubscriptions(oldIndex, newIndex);
                  },
                  itemBuilder: (context, index) {
                    final sub = subscriptions[index];
                    final account =
                        Provider.of<WalletProvider>(context, listen: false)
                            .accounts
                            .firstWhere((a) => a.id == sub.accountToCharge,
                                orElse: () => const AccountEntity(
                                    id: -1,
                                    name: 'Desconocido',
                                    initialBalance: 0,
                                    currencySymbol: '',
                                    colorValue: 0xFF9E9E9E,
                                    iconCode: 0));

                    return Container(
                      key: ValueKey(sub.id),
                      child: FixedExpenseCard(
                        subscription: sub,
                        account: account,
                        onTap: () => onEditExpense(sub),
                        onPay: () => onPayExpense(sub),
                        onDelete: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text("¿Eliminar gasto fijo?"),
                              content: Text(
                                  "¿Ya no pagas ${sub.name}? Esto dejará de notificarte."),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text("Cancelar")),
                                ElevatedButton(
                                    onPressed: () {
                                      provider.removeSubscription(
                                          sub.id.toString());
                                      Navigator.pop(ctx);
                                    },
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red),
                                    child: const Text("Eliminar"))
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class RemindersSummarySection extends StatelessWidget {
  const RemindersSummarySection({super.key});

  void _completeOneTime(BuildContext context, ReminderProvider provider,
      Reminder reminder) async {
    final res = await provider.completeOneTime(reminder.id);
    res.fold(
      (failure) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(failure.message)));
        }
      },
      (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Recordatorio completado 🎉")));
        }
      },
    );
  }

  void _toggleActive(BuildContext context, ReminderProvider provider,
      Reminder reminder) async {
    final res = await provider.toggleActive(reminder.id, !reminder.active);
    res.fold(
      (failure) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(failure.message)));
        }
      },
      (_) {},
    );
  }

  void _confirmDelete(BuildContext context, ReminderProvider provider,
      Reminder reminder) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Eliminar Recordatorio"),
        content: const Text(
            "¿Estás seguro de eliminar este recordatorio? Esta acción no se puede deshacer."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Eliminar"),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final res = await provider.deleteReminder(reminder.id);
      res.fold(
        (failure) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text("Error al eliminar el recordatorio")));
          }
        },
        (_) {},
      );
    }
  }

  void _showReminderForm(BuildContext context, [Reminder? reminder]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReminderFormSheet(existingReminder: reminder),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Consumer<ReminderProvider>(
      builder: (context, provider, child) {
        // Collect up to 3 active reminders: overdue first, then upcoming
        final activeOverdue = provider.overdue.where((r) => r.active).toList();
        final activeUpcoming =
            provider.upcoming.where((r) => r.active).toList();

        final combined = [...activeOverdue, ...activeUpcoming];
        final displayItems = combined.take(3).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Recordatorios",
                    style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const RemindersPage()),
                      );
                    },
                    child: const Text(
                      "Ver todos",
                      style: TextStyle(
                          color: Colors.cyan, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            if (provider.isLoading && displayItems.isEmpty)
              const Center(child: CircularProgressIndicator())
            else if (displayItems.isEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: SizedBox(
                  width: double.infinity,
                  child: Center(
                    child: Text(
                      "No tienes recordatorios próximos.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: isDarkMode ? Colors.grey : Colors.grey[600]),
                    ),
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: displayItems.length,
                  itemBuilder: (context, index) {
                    final reminder = displayItems[index];
                    return ReminderCard(
                      reminder: reminder,
                      onTap: () => _showReminderForm(context, reminder),
                      onComplete: () =>
                          _completeOneTime(context, provider, reminder),
                      onToggleActive: () =>
                          _toggleActive(context, provider, reminder),
                      onDelete: () =>
                          _confirmDelete(context, provider, reminder),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}
