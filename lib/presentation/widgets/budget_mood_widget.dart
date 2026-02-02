import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/budget_mood.dart';
import '../providers/dashboard_provider.dart';

class BudgetMoodWidget extends StatelessWidget {
  const BudgetMoodWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, provider, child) {
        final mood = provider.budgetMood;

        IconData iconData;
        Color color;
        String message;

        switch (mood) {
          case BudgetMood.happy:
            iconData = Icons.sentiment_very_satisfied_rounded;
            color = Colors.green;
            message = "¡Vas muy bien!";
            break;
          case BudgetMood.neutral:
            iconData = Icons.sentiment_neutral_rounded;
            color = Colors.amber;
            message = "Cuidado con los gastos";
            break;
          case BudgetMood.sad:
            iconData = Icons.sentiment_very_dissatisfied_rounded;
            color = Colors.red;
            message = "¡Presupuesto excedido!";
            break;
        }

        return Container(
          padding: const EdgeInsets.all(20),
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
          ),
          child: Column(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return ScaleTransition(scale: animation, child: child);
                },
                child: Icon(
                  iconData,
                  key: ValueKey<BudgetMood>(mood),
                  size: 100,
                  color: color,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 5),
              if (provider.isLoading)
                const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Text(
                  "Saldo Total: S/ ${provider.balanceBreakdown?.total.toStringAsFixed(2) ?? '0.00'}",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
            ],
          ),
        );
      },
    );
  }
}
