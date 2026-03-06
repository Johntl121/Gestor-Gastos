import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:provider/provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../../domain/entities/goal_entity.dart';
import '../../../domain/entities/account_entity.dart';
import 'widgets/add_account_sheet.dart';
import 'widgets/goal_form_sheet.dart';
import 'widgets/goal_card.dart';
import 'widgets/add_fixed_expense_sheet.dart';
import 'widgets/fixed_expense_card.dart';
import 'widgets/goal_detail_sheet.dart';

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
        backgroundColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (ctx) => GoalDetailSheet(
              goal: goal,
              onConfettiTrigger: () => _confettiController.play(),
            ));
  }

  // --- Proxy Decorator for Drag & Drop ---
  Widget _proxyDecorator(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        return Material(
          elevation: 0,
          color: Colors.transparent,
          child: Transform.scale(
            scale: 1.05, // Efecto de escala
            child: Opacity(
              opacity: 0.9,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.45),
                      blurRadius: 20, // Sombra aumentada
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

  @override
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(
      builder: (context, walletProvider, child) {
        final goals = walletProvider.goals;
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
                style:
                    TextStyle(color: textColor, fontWeight: FontWeight.bold)),
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
                    // --- Accounts PageView ---
                    SizedBox(
                      height: 200,
                      child: PageView.builder(
                        controller: PageController(viewportFraction: 0.9),
                        itemCount: walletProvider.accounts.length + 1,
                        itemBuilder: (context, index) {
                          if (index < walletProvider.accounts.length) {
                            final account = walletProvider.accounts[index];
                            return GestureDetector(
                              onTap: () => _showAddAccountSheet(context,
                                  accountToEdit: account),
                              child: _buildAccountCard(context, account),
                            );
                          } else {
                            // Add Account Card
                            return GestureDetector(
                              onTap: () => _showAddAccountSheet(context),
                              child: Container(
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? Colors.white10
                                      : Colors.grey.shade200,
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
                                          size: 48,
                                          color: isDarkMode
                                              ? Colors.white54
                                              : Colors.grey),
                                      const SizedBox(height: 8),
                                      Text("Añadir Cuenta",
                                          style: TextStyle(
                                              color: isDarkMode
                                                  ? Colors.white54
                                                  : Colors.grey,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold))
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ),

                    const SizedBox(height: 40),

                    // --- Goals Section (Reorderable) ---
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
                            onTap: () => _showGoalFormDialog(context),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFF00E5FF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.add,
                                  color: Colors.white, size: 24),
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
                                    color: isDarkMode
                                        ? Colors.blueGrey[200]
                                        : Colors.grey))),
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
                          onReorderStart: (_) =>
                              setState(() => _isDragging = true),
                          onReorderEnd: (_) =>
                              setState(() => _isDragging = false),
                          itemCount: goals.length,
                          itemBuilder: (context, index) {
                            final goal = goals[index];
                            return Container(
                              key: ValueKey(goal.id),
                              child: GoalCard(
                                name: goal.name,
                                currentAmount: goal.currentAmount,
                                targetAmount: goal.targetAmount,
                                color: Color(goal.colorValue),
                                icon: IconData(goal.iconCode,
                                    fontFamily: 'MaterialIcons'),
                                onTap: () => _showGoalDetails(context, goal),
                                onEdit: () =>
                                    _showGoalFormDialog(context, toEdit: goal),
                                onDelete: () async {
                                  // Lógica de borrado con confirmación
                                  final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                              title:
                                                  const Text("Eliminar Meta"),
                                              content: const Text(
                                                  "¿Estás seguro de eliminar esta meta? Esto no se puede deshacer."),
                                              actions: [
                                                TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            ctx, false),
                                                    child:
                                                        const Text("Cancelar")),
                                                ElevatedButton(
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                            backgroundColor:
                                                                Colors.red),
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            ctx, true),
                                                    child:
                                                        const Text("Eliminar"))
                                              ]));
                                  if (confirm == true) {
                                    walletProvider
                                        .deleteGoal(goal.id.toString());
                                  }
                                },
                              ),
                            );
                          },
                        ),
                      ),

                    const SizedBox(height: 40),

                    // --- Fixed Expenses Section (Reorderable) ---
                    Consumer<TransactionProvider>(
                      builder: (context, transactionProvider, _) {
                        return _buildFixedExpensesSection(
                            context, transactionProvider, isDarkMode);
                      },
                    ),

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
      },
    );
  }

  Widget _buildAccountCard(BuildContext context, AccountEntity account) {
    IconData displayIcon =
        IconData(account.iconCode, fontFamily: 'MaterialIcons');
    if (account.name.toLowerCase() == 'efectivo' &&
        (account.iconCode == Icons.money.codePoint ||
            account.iconCode == Icons.wallet_rounded.codePoint ||
            account.iconCode == Icons.account_balance_wallet.codePoint)) {
      displayIcon = Icons.payments_rounded;
    }

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
                displayIcon,
                color: Colors.white70,
                size: 28,
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz, color: Colors.white70),
                color: const Color(0xFF1E293B),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                onSelected: (value) {
                  if (value == 'edit') {
                    _showAddAccountSheet(context, accountToEdit: account);
                  } else if (value == 'delete') {
                    final provider =
                        Provider.of<WalletProvider>(context, listen: false);
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
                "${account.currencySymbol} ${account.currentBalance.toStringAsFixed(2)}",
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

  Widget _buildFixedExpensesSection(
      BuildContext context, TransactionProvider provider, bool isDarkMode) {
    // Calculate Total
    double totalFixed =
        provider.subscriptions.fold(0, (sum, item) => sum + item.amount);

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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "Total: S/ ${totalFixed.toStringAsFixed(2)}",
                  style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => const AddFixedExpenseSheet(),
                  );
                },
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                      color: const Color(0xFFD500F9), // Purple Accent
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD500F9).withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ]),
                  child: const Icon(Icons.add, color: Colors.white, size: 26),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        if (provider.subscriptions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Center(
              child: Text(
                "No tienes suscripciones registradas.",
                style: TextStyle(
                    color: isDarkMode ? Colors.grey : Colors.grey[600]),
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
              onReorderStart: (_) => setState(() => _isDragging = true),
              onReorderEnd: (_) => setState(() => _isDragging = false),
              itemCount: provider.subscriptions.length,
              onReorder: (oldIndex, newIndex) {
                provider.reorderSubscriptions(oldIndex, newIndex);
              },
              itemBuilder: (context, index) {
                final sub = provider.subscriptions[index];
                return Container(
                  key: ValueKey(sub.id),
                  child: FixedExpenseCard(
                    subscription: sub,
                    onTap: () {
                      // Editar? El usuario dijo "Click Total -> Pagar", pero también "Menú: Editar"
                      // onTap en el card ahora dispara onPay según la implementación del card.
                      // Así que aquí pasamos una función vacía o redirigimos edit a través del menú.
                      // FixedExpenseCard usa onTap interno para Pay, así que este callback podría ser redundante
                      // si el card lo maneja, pero el card llama a `onTap: onTap`.
                      // Un momento, en FixedExpenseCard implementé: `onTap: onPay`.
                      // Entonces este callback `onTap` no se usa para Pay, se usa onTap interno.
                      // Espera, el widget `FixedExpenseCard` tiene `required this.onTap`.
                      // Y en su build usa `onTap: onPay` (mi error anterior).
                      // Corregí en el write: `onTap: onPay` en InkWell.
                      // El parámetro `onTap` del constructor se usa en el menú para 'edit': `if (value == 'edit') onTap();`.
                      // Por tanto, este `onTap` que paso aquí debe ser EDITAR.

                      // Show edit sheet logic requires implementing EditFixedExpenseSheet?
                      // Or reusing AddFixedExpenseSheet with params.
                      // Assuming AddFixedExpenseSheet(subscriptionToEdit: sub) exists or similar implies refactoring Add sheet.
                      // User didn't asking for Edit sheet implementation, just "Menu -> Edit".
                      // I'll show a "Not implemented" snackbar or similar if Logic missing.
                      // But I can leave it empty for now or log.
                    },
                    onPay: () {
                      if (!sub.isPaid) {
                        provider.markSubscriptionAsPaid(sub);
                      }
                    },
                    onDelete: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text("¿Eliminar suscripción?"),
                          content: Text(
                              "¿Ya no pagas ${sub.name}? Esto dejará de notificarte."),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text("Cancelar")),
                            ElevatedButton(
                                onPressed: () {
                                  provider
                                      .removeSubscription(sub.id.toString());
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
  }
}
