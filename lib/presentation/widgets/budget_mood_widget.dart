import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/budget_mood.dart';
import '../providers/stats_provider.dart';
import '../providers/wallet_provider.dart';

class BudgetMoodWidget extends StatelessWidget {
  const BudgetMoodWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<StatsProvider, WalletProvider>(
      builder: (context, statsProvider, walletProvider, child) {
        final mood = statsProvider.budgetMood;

        IconData iconData;
        Color color;
        String message;

        switch (mood) {
          case BudgetMood.happy:
            iconData = Icons.sentiment_very_satisfied_rounded;
            color = const Color(0xFF00E676); // Verde vibrante
            message = "¡Vas muy bien!";
            break;
          case BudgetMood.neutral:
            iconData = Icons.sentiment_neutral_rounded;
            color = const Color(0xFFFFB300); // Amber vibrante
            message = "Cuidado con los gastos";
            break;
          case BudgetMood.sad:
            iconData = Icons.sentiment_very_dissatisfied_rounded;
            color = const Color(0xFFFF5252); // Rojo vibrante
            message = "¡Presupuesto excedido!";
            break;
        }

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            // Fondo con gradiente sutil para profundidad
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1E2435), Color(0xFF151A27)],
            ),
            // Sombra suave para elevación "flotante"
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Icono con efecto Glassmorphism (Fondo translúcido)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.1),
                      blurRadius: 10,
                      spreadRadius: 2,
                    )
                  ],
                ),
                child: Icon(
                  iconData,
                  size: 42,
                  color: color,
                ),
              ),

              const SizedBox(height: 16),

              // 2. Título Principal (Jerarquía Alta)
              Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              // 3. Subtítulo / Balance (Jerarquía Baja)
              Text(
                "Saldo Total: ${walletProvider.currencySymbol} ${walletProvider.totalBalance.toStringAsFixed(2)}",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }
}
