import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../domain/entities/goal_entity.dart';
import '../../../providers/wallet_provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../../../core/constants/app_categories.dart';
import '../../../../core/constants/app_constants.dart';
import 'goal_deposit_dialog.dart';
import 'goal_form_sheet.dart';

class GoalDetailSheet extends StatelessWidget {
  final GoalEntity goal;
  final VoidCallback onConfettiTrigger;

  const GoalDetailSheet({
    super.key,
    required this.goal,
    required this.onConfettiTrigger,
  });

  @override
  Widget build(BuildContext context) {
    return Selector<WalletProvider, GoalEntity?>(
      selector: (context, provider) =>
          provider.goals.where((g) => g.id == goal.id).firstOrNull,
      builder: (context, updatedGoal, child) {
        final currentGoal = updatedGoal ?? goal;
        final theme = Theme.of(context);
        final isDarkMode = theme.brightness == Brightness.dark;
        final walletProvider =
            Provider.of<WalletProvider>(context, listen: false);
        final currencySymbol = walletProvider.currencySymbol;

        final progress = currentGoal.progress;
        final isCompleted = progress >= 1.0;
        final goalColor =
            isCompleted ? const Color(0xFFFFD700) : currentGoal.color;

        // Datos de la cuenta alcancía
        final vaultAccount = currentGoal.accountId != null
            ? walletProvider.accounts
                .where((a) => a.id == currentGoal.accountId)
                .firstOrNull
            : null;

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.white24 : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),

                // ─── HERO: Ícono con Glow ───
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 48),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: goalColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: goalColor.withValues(alpha: 0.4),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        isCompleted ? Icons.emoji_events : goal.icon,
                        size: 44,
                        color: goalColor,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.edit_outlined,
                          color: isDarkMode ? Colors.grey[400] : Colors.grey),
                      onPressed: () {
                        Navigator.pop(context);
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (ctx) =>
                              GoalFormSheet(goalToEdit: currentGoal),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Nombre
                Text(
                  currentGoal.name,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black87,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 6),

                // Textos motivacionales
                if (isCompleted)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: goalColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "🏆 ¡Meta Alcanzada!",
                      style: TextStyle(
                        color: goalColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  )
                else
                  Text(
                    "Progreso: ${(progress * 100).toInt()}%",
                    style: TextStyle(
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),

                const SizedBox(height: 24),

                // ─── BARRA DE PROGRESO GRUESA ───
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    children: [
                      Container(
                        height: 18,
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.black26 : Colors.grey[200],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOut,
                        height: 18,
                        width:
                            (MediaQuery.of(context).size.width - 48) * progress,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isCompleted
                                ? [Colors.amber, const Color(0xFFFFD700)]
                                : [goalColor.withValues(alpha: 0.7), goalColor],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: goalColor.withValues(alpha: 0.4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ─── STATS ROW ───
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatChip(
                      "Has ahorrado",
                      "$currencySymbol ${(currentGoal.isCompleted ? currentGoal.targetAmount : currentGoal.currentAmount).toStringAsFixed(2)}",
                      Colors.green,
                      isDarkMode,
                    ),
                    _buildStatChip(
                      "Faltan",
                      "$currencySymbol ${currentGoal.remainingAmount.toStringAsFixed(2)}",
                      isCompleted ? goalColor : Colors.orange,
                      isDarkMode,
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // ─── DEADLINE INFO ───
                if (currentGoal.deadline != null) ...[
                  _buildDeadlineInfo(
                      currentGoal, currencySymbol, goalColor, isDarkMode),
                  const SizedBox(height: 14),
                ],

                // ─── VAULT INFO ───
                if (vaultAccount != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: goalColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: goalColor.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lock_outline, size: 16, color: goalColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Alcancía: ${vaultAccount.name}",
                            style: TextStyle(
                              color: isDarkMode
                                  ? Colors.grey[300]
                                  : Colors.grey[700],
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          "${vaultAccount.currencySymbol} ${vaultAccount.currentBalance.toStringAsFixed(2)}",
                          style: TextStyle(
                            color: isDarkMode
                                ? Colors.grey[400]
                                : Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 28),

                // ─── ACTIONS ───
                if (isCompleted && !currentGoal.isCompleted) ...[
                  // Meta alcanzó 100% pero aún no se ha "comprado"
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: () => _confirmPurchase(context, currentGoal),
                      icon:
                          const Icon(Icons.shopping_cart, color: Colors.black),
                      label: const Text("¡COMPRAR AHORA!",
                          style: TextStyle(
                              color: Colors.black,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 10,
                        shadowColor: Colors.amber.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => _confirmDeleteGoal(context, currentGoal),
                    child: Text("Retirar dinero (Sin registrar gasto)",
                        style: TextStyle(
                            color: isDarkMode ? Colors.grey[500] : Colors.grey,
                            decoration: TextDecoration.underline)),
                  ),
                ] else if (currentGoal.isCompleted) ...[
                  // Meta ya fue comprada — mostrar trofeo
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: goalColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: goalColor.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.emoji_events, size: 40, color: goalColor),
                        const SizedBox(height: 8),
                        Text(
                          "¡Compra realizada con éxito!",
                          style: TextStyle(
                            color: goalColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Esta meta está en tu Muro de Trofeos 🏅",
                          style: TextStyle(
                            color: isDarkMode
                                ? Colors.grey[400]
                                : Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Meta en progreso
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => GoalDepositDialog(
                            goal: currentGoal,
                            onConfettiTrigger: onConfettiTrigger,
                          ),
                        );
                      },
                      icon: const Icon(Icons.savings, color: Colors.white),
                      label: const Text("Depositar / Ahorrar",
                          style: TextStyle(color: Colors.white, fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: goalColor,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 6,
                        shadowColor: goalColor.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () => _confirmDeleteGoal(context, currentGoal),
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.redAccent, size: 20),
                    label: const Text("Eliminar Meta",
                        style: TextStyle(color: Colors.redAccent)),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatChip(
      String label, String value, Color color, bool isDarkMode) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 11,
                )),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildDeadlineInfo(
      GoalEntity goal, String currency, Color goalColor, bool isDarkMode) {
    final days = goal.daysRemaining ?? 0;
    final isOverdue = days < 0;
    final isToday = days == 0;

    String deadlineText;
    Color deadlineColor;
    IconData deadlineIcon;

    if (isOverdue) {
      deadlineText = "Vencida hace ${-days} día${-days == 1 ? '' : 's'}";
      deadlineColor = Colors.redAccent;
      deadlineIcon = Icons.warning_amber;
    } else if (isToday) {
      deadlineText = "¡Hoy es el día!";
      deadlineColor = Colors.amber;
      deadlineIcon = Icons.today;
    } else {
      deadlineText = "Faltan $days día${days == 1 ? '' : 's'}";
      deadlineColor = goalColor;
      deadlineIcon = Icons.schedule;
    }

    final tip = goal.suggestedMonthlySavings;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: deadlineColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: deadlineColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(deadlineIcon, size: 16, color: deadlineColor),
              const SizedBox(width: 8),
              Text(deadlineText,
                  style: TextStyle(
                    color: deadlineColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  )),
            ],
          ),
          if (tip != null && !isOverdue && goal.remainingAmount > 0) ...[
            const SizedBox(height: 6),
            Text(
              "💡 Ahorra $currency ${tip.toStringAsFixed(2)} al mes para llegar a tiempo",
              style: TextStyle(
                color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _confirmPurchase(BuildContext context, GoalEntity currentGoal) {
    final provider = Provider.of<WalletProvider>(context, listen: false);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final goalColor = currentGoal.color;
    final currencySymbol = provider.currencySymbol;

    // Categoría pre-llenada desde Smart Icon
    int selectedCategoryId =
        currentGoal.categoryId ?? AppConstants.shoppingCategoryId;

    // Nombre de la cuenta alcancía
    final vaultAccount = currentGoal.accountId != null
        ? provider.accounts
            .where((a) => a.id == currentGoal.accountId)
            .firstOrNull
        : null;
    final vaultName = vaultAccount?.name ?? 'Cuenta Alcancía';

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (builderCtx, setState) {
          return AlertDialog(
            backgroundColor:
                isDarkMode ? const Color(0xFF1E293B) : Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withValues(alpha: 0.3),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.emoji_events,
                      color: Colors.amber, size: 32),
                ),
                const SizedBox(height: 12),
                Text("¡Felicidades! 🎉",
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold,
                    )),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "¿Registrar la compra de '${goal.name}'?",
                  style: TextStyle(
                    color: isDarkMode ? Colors.white70 : Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 16),

                // Monto
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: goalColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Monto:",
                          style: TextStyle(
                            color: isDarkMode
                                ? Colors.grey[400]
                                : Colors.grey[600],
                          )),
                      Text(
                        "$currencySymbol ${(goal.isCompleted ? goal.targetAmount : goal.currentAmount).toStringAsFixed(2)}",
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Cuenta origen (La Alcancía — estática)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: goalColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lock_outline, size: 16, color: goalColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text("Desde: $vaultName",
                            style: TextStyle(
                              color: isDarkMode
                                  ? Colors.grey[300]
                                  : Colors.grey[700],
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            )),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Categoría (editable)
                Text("Categoría del gasto:",
                    style: TextStyle(
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    )),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButton<int>(
                    value: AppCategories.expenseCategories
                            .containsKey(selectedCategoryId)
                        ? selectedCategoryId
                        : AppCategories.expenseCategories.keys.first,
                    isExpanded: true,
                    underline: const SizedBox(),
                    dropdownColor:
                        isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                    items: AppCategories.expenseCategories.entries.map((entry) {
                      return DropdownMenuItem<int>(
                        value: entry.key,
                        child: Row(
                          children: [
                            Icon(AppCategories.getIcon(entry.key),
                                size: 18,
                                color: Color(entry.value['color'] as int)),
                            const SizedBox(width: 10),
                            Text(entry.value['name'] as String,
                                style: TextStyle(
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.black87,
                                  fontSize: 14,
                                )),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (catId) {
                      if (catId != null) {
                        setState(() => selectedCategoryId = catId);
                      }
                    },
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: Text("Cancelar",
                    style: TextStyle(
                        color: isDarkMode ? Colors.grey : Colors.grey[600])),
              ),
              ElevatedButton(
                onPressed: () async {
                  onConfettiTrigger();
                  await provider.purchaseGoal(currentGoal.id.toString(),
                      categoryId: selectedCategoryId);

                  if (context.mounted) {
                    Provider.of<TransactionProvider>(context, listen: false)
                        .loadTransactions();
                    Navigator.pop(c);
                  }
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("¡SÍ, COMPRAR!",
                    style: TextStyle(
                        color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDeleteGoal(BuildContext context, GoalEntity currentGoal) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (currentGoal.currentAmount > 0) {
      final provider = Provider.of<WalletProvider>(context, listen: false);
      int selectedRefundAccount =
          provider.accounts.isNotEmpty ? provider.accounts.first.id : -1;

      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor:
                  isDarkMode ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Text("Eliminar Meta con Saldo",
                  style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black87)),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Esta meta tiene ahorrados ${CurrencyFormatter.format(currentGoal.currentAmount, currentGoal.accountId != null ? provider.accounts.firstWhere((a) => a.id == currentGoal.accountId, orElse: () => provider.accounts.first).currencySymbol : provider.currencySymbol)}. Selecciona una cuenta para devolver el dinero.",
                      style: TextStyle(
                        color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (selectedRefundAccount == -1)
                      const Text("No hay cuentas para devolver fondos.",
                          style: TextStyle(color: Colors.red))
                    else
                      DropdownButtonFormField<int>(
                        isExpanded: true,
                        initialValue: selectedRefundAccount,
                        dropdownColor:
                            isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                        items: provider.accounts.map((acc) {
                          return DropdownMenuItem<int>(
                            value: acc.id,
                            child: Row(
                              children: [
                                Icon(
                                  IconData(acc.iconCode,
                                      fontFamily: 'MaterialIcons'),
                                  size: 18,
                                  color: Color(acc.colorValue),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "${acc.name} (${CurrencyFormatter.format(acc.currentBalance, acc.currencySymbol)})",
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDarkMode
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => selectedRefundAccount = val);
                          }
                        },
                        decoration: InputDecoration(
                          labelText: "Devolver a:",
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancelar",
                      style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await provider.deleteGoal(currentGoal.id.toString(),
                        refund: true, refundAccountId: selectedRefundAccount);
                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent),
                  child: const Text("Eliminar y Devolver",
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("¿Eliminar Meta?",
              style:
                  TextStyle(color: isDarkMode ? Colors.white : Colors.black87)),
          content: Text("Esta acción no se puede deshacer.",
              style: TextStyle(
                  color: isDarkMode ? Colors.grey[300] : Colors.grey[700])),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  const Text("Cancelar", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Provider.of<WalletProvider>(context, listen: false)
                    .deleteGoal(currentGoal.id.toString());
                Navigator.pop(ctx);
                if (context.mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child:
                  const Text("Eliminar", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
  }
}
