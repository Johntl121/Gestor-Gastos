import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../domain/entities/goal_entity.dart';
import '../../../providers/wallet_provider.dart';
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
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final progress = (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0);
    final isCompleted = progress >= 1.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with Edit
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 48), // Spacer
              Icon(
                  isCompleted
                      ? Icons.emoji_events
                      : IconData(goal.iconCode, fontFamily: 'MaterialIcons'),
                  size: 64,
                  color: isCompleted ? Colors.amber : Color(goal.colorValue)),
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.grey),
                onPressed: () {
                  Navigator.pop(context); // Close Detail Sheet
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => GoalFormSheet(goalToEdit: goal),
                  );
                },
              )
            ],
          ),

          const SizedBox(height: 16),
          Text(goal.name,
              style: TextStyle(
                  color: theme.textTheme.headlineMedium?.color,
                  fontSize: 24,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text("Progreso: ${(progress * 100).toInt()}%",
              style: TextStyle(color: Colors.grey[400], fontSize: 16)),
          const SizedBox(height: 24),

          // Progress Bar
          Stack(
            children: [
              Container(
                  height: 12,
                  decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(6))),
              Container(
                  height: 12,
                  width: MediaQuery.of(context).size.width * 0.8 * progress,
                  decoration: BoxDecoration(
                      color:
                          isCompleted ? Colors.amber : Color(goal.colorValue),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: isCompleted
                          ? [
                              BoxShadow(
                                  color: Colors.amber.withOpacity(0.6),
                                  blurRadius: 10)
                            ]
                          : null)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("S/ ${goal.currentAmount.toStringAsFixed(2)}",
                  style: const TextStyle(color: Colors.grey)),
              Text("Meta: S/ ${goal.targetAmount.toStringAsFixed(2)}",
                  style: const TextStyle(color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 40),

          // Actions
          if (isCompleted) ...[
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () => _confirmPurchase(context),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 10,
                    shadowColor: Colors.amber.withOpacity(0.5)),
                child: const Text("¡COMPRAR AHORA!",
                    style: TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
                onPressed: () => _confirmDeleteGoal(context),
                child: const Text("Retirar dinero (Sin registrar gasto)",
                    style: TextStyle(
                        color: Colors.grey, // Adjusted visible color
                        decoration: TextDecoration.underline)))
          ] else ...[
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Show Deposit Dialog
                  showDialog(
                      context: context,
                      builder: (ctx) => GoalDepositDialog(
                          goal: goal, onConfettiTrigger: onConfettiTrigger));
                  // We don't close the sheet immediately, user might want to see update.
                  // But typically dialog closes and we stay on sheet or close sheet.
                  // Original code: Navigator.pop(ctx); Navigator.pop(context); inside dialog Logic.
                  // But here dialog is independent.
                  // If dialog pops context, it pops dialog.
                  // If we want to close sheet after success, onConfettiTrigger handles the visual,
                  // but we might want to close sheet too?
                  // Original logic closed both.
                  // My Dialog code: Navigator.pop(context) closes dialog.
                  // If we want valid flow, maybe the dialog should return 'success'.
                },
                icon: const Icon(Icons.savings, color: Colors.white),
                label: const Text("Depositar / Ahorrar",
                    style: TextStyle(color: Colors.white, fontSize: 16)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16))),
              ),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () => _confirmDeleteGoal(context),
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              label: const Text("Eliminar Meta",
                  style: TextStyle(color: Colors.redAccent)),
            )
          ]
        ],
      ),
    );
  }

  void _confirmPurchase(BuildContext context) {
    showDialog(
        context: context,
        builder: (c) => AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              title: const Text("¡Felicidades! 🎉",
                  style: TextStyle(color: Colors.white)),
              content: Text(
                  "¿Deseas registrar la compra de '${goal.name}' por S/ ${goal.targetAmount}?",
                  style: const TextStyle(color: Colors.white70)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c),
                    child: const Text("Rechazar",
                        style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                    onPressed: () {
                      Provider.of<WalletProvider>(context, listen: false)
                          .purchaseGoal(goal.id.toString());
                      Navigator.pop(c); // Dialog
                      Navigator.pop(context); // BottomSheet
                    },
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                    child: const Text("¡SÍ, COMPRAR!",
                        style: TextStyle(
                            color: Colors.black, fontWeight: FontWeight.bold)))
              ],
            ));
  }

  void _confirmDeleteGoal(BuildContext context) {
    if (goal.currentAmount > 0) {
      // Pre-fetch check
      final provider = Provider.of<WalletProvider>(context, listen: false);
      int selectedRefundAccount = 2;

      if (provider.accounts.isNotEmpty) {
        if (!provider.accounts.any((a) => a.id == selectedRefundAccount)) {
          selectedRefundAccount = provider.accounts.first.id;
        }
      } else {
        selectedRefundAccount = -1;
      }

      showDialog(
          context: context,
          builder: (ctx) => StatefulBuilder(builder: (context, setState) {
                // context here is dialog context
                return AlertDialog(
                  backgroundColor: Theme.of(context).cardColor,
                  title: Text(
                    "Eliminar Meta con Saldo",
                    style: TextStyle(
                        color: Theme.of(context).textTheme.titleLarge?.color),
                  ),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Esta meta tiene ahorrados S/ ${goal.currentAmount.toStringAsFixed(2)}. Selecciona una cuenta para devolver el dinero antes de eliminarla.",
                          style: TextStyle(
                              color:
                                  Theme.of(context).textTheme.bodyMedium?.color,
                              fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        if (selectedRefundAccount == -1)
                          const Text("No hay cuentas para devolver fondos.",
                              style: TextStyle(color: Colors.red))
                        else
                          DropdownButtonFormField<int>(
                            isExpanded: true,
                            value: selectedRefundAccount,
                            dropdownColor: Theme.of(context).cardColor,
                            items: provider.accounts.map((acc) {
                              return DropdownMenuItem<int>(
                                value: acc.id,
                                child: Row(
                                  children: [
                                    Icon(
                                        IconData(acc.iconCode,
                                            fontFamily: 'MaterialIcons'),
                                        size: 18,
                                        color: Color(acc.colorValue)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        "${acc.name} (${acc.currencySymbol} ${acc.currentBalance.toStringAsFixed(2)})",
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        style: TextStyle(
                                            fontSize: 14,
                                            color: Theme.of(context)
                                                .textTheme
                                                .bodyLarge
                                                ?.color),
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
                          )
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text("Cancelar",
                            style: TextStyle(color: Colors.grey))),
                    ElevatedButton(
                        onPressed: () async {
                          await provider.deleteGoal(goal.id.toString(),
                              refund: true,
                              refundAccountId: selectedRefundAccount);
                          Navigator.pop(ctx);
                          if (context.mounted) {
                            Navigator.pop(context); // Close Detail Sheet
                          }
                          // The `context` in StatefulBuilder is the builder context.
                          // To close Sheet, we need the parent context passed to _confirmDeleteGoal or finding it.
                          // Actually, passed `context` to _confirmDeleteGoal is Sheet's context.
                          // But we are in a Dialog.
                          // Navigator.pop(ctx) closes Dialog.
                          // We need to close Sheet too.
                          // We should pass the Sheet context to navigate pop.
                          // We should pass the Sheet context to pop it.
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent),
                        child: const Text("Eliminar y Devolver",
                            style: TextStyle(color: Colors.white)))
                  ],
                );
              }));
    } else {
      // Standard Delete (No funds)
      showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
                backgroundColor: Theme.of(context).cardColor,
                title: Text("¿Eliminar Meta?",
                    style: TextStyle(
                        color: Theme.of(context).textTheme.titleLarge?.color)),
                content: Text("Esta acción no se puede deshacer.",
                    style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Cancelar",
                          style: TextStyle(color: Colors.grey))),
                  ElevatedButton(
                      onPressed: () {
                        Provider.of<WalletProvider>(context, listen: false)
                            .deleteGoal(goal.id.toString());
                        Navigator.pop(ctx); // Close Dialog
                        if (context.mounted) {
                          Navigator.pop(context); // Close BottomSheet
                        }
                      },
                      style:
                          ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text("Eliminar",
                          style: TextStyle(color: Colors.white)))
                ],
              ));
    }
  }
}
