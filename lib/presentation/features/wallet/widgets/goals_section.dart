import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../domain/entities/goal_entity.dart';
import '../../../providers/wallet_provider.dart';
import '../../../providers/goal_provider.dart';
import 'goal_card.dart';

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

class GoalsSection extends StatelessWidget {
  final VoidCallback onAddGoal;
  final void Function(GoalEntity) onEditGoal;
  final void Function(GoalEntity) onShowDetails;
  final void Function(bool) onDraggingChanged;

  const GoalsSection({
    super.key,
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

    return Consumer2<WalletProvider, GoalProvider>(
      builder: (context, walletProvider, goalProvider, _) {
        final goals = goalProvider.goals;
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
                    goalProvider.reorderGoals(oldIndex, newIndex);
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
                            final success = await goalProvider.deleteGoal(goal.id.toString());
                            if (success && context.mounted) {
                              context.read<WalletProvider>().loadWalletData();
                            }
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
