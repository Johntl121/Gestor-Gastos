import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:provider/provider.dart';
import '../../providers/ui_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../../data/models/subscription.dart';
import '../../../domain/entities/goal_entity.dart';
import '../../../domain/entities/account_entity.dart';
import 'widgets/add_account_sheet.dart';
import 'widgets/goal_form_sheet.dart';

import 'widgets/add_fixed_expense_sheet.dart';

import 'widgets/goal_detail_sheet.dart';
import '../../../core/constants/app_categories.dart';
import '../../../core/constants/icon_mapper.dart';
import '../../../core/utils/currency_formatter.dart';

import 'widgets/accounts_section.dart';
import 'widgets/goals_section.dart';
import 'widgets/fixed_expenses_section.dart';
import 'widgets/reminders_summary_section.dart';

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
                          final subscriptionProvider =
                              Provider.of<SubscriptionProvider>(context,
                                  listen: false);

                          await transactionProvider
                              .markSubscriptionAsPaid(subToPay);

                          // Sincronizar saldos de cuenta en WalletProvider
                          if (mounted) {
                            await walletProvider.loadWalletData();
                            await subscriptionProvider.loadSubscriptions();
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
                AccountsSection(
                  onAddAccount: () => _showAddAccountSheet(context),
                  onEditAccount: (acc) =>
                      _showAddAccountSheet(context, accountToEdit: acc),
                ),

                const SizedBox(height: 40),

                // --- Goals Section ---
                GoalsSection(
                  onAddGoal: () => _showGoalFormDialog(context),
                  onEditGoal: (goal) =>
                      _showGoalFormDialog(context, toEdit: goal),
                  onShowDetails: (goal) => _showGoalDetails(context, goal),
                  onDraggingChanged: _setDragging,
                ),

                const SizedBox(height: 40),

                // --- Fixed Expenses Section ---
                FixedExpensesSection(
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

