import 'package:flutter/material.dart';
import '../../../../data/models/subscription.dart';
import '../../../../domain/entities/account_entity.dart';

class FixedExpenseCard extends StatelessWidget {
  final Subscription subscription;
  final AccountEntity? account;
  final VoidCallback onTap;
  final VoidCallback onPay;
  final VoidCallback onDelete;

  const FixedExpenseCard({
    super.key,
    required this.subscription,
    this.account,
    required this.onTap,
    required this.onPay,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Calcular estado
    final isPaid = subscription.isPaid;
    final isOverdue = !isPaid &&
        subscription.nextDueDate.isBefore(DateTime.now()) &&
        !_isSameDay(subscription.nextDueDate, DateTime.now());

    // Estado Texto y Color
    String statusText;
    Color statusColor;

    if (isOverdue) {
      statusText = "Vencido";
      statusColor = const Color(0xFFFF5252); // Rojo Coral
    } else if (!isPaid) {
      final d = subscription.nextDueDate;
      statusText = "Vence el ${d.day}/${d.month}";
      statusColor = isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;
    } else {
      statusText = "Pagado";
      statusColor = isDarkMode ? Colors.grey[400]! : Colors.grey[500]!; // Gris
    }

    final itemColor = Color(subscription.colorValue);

    // Dynamic Gradient based on "Dark Mode Premium" rule
    // Gradient: Top slightly lighter, Bottom slightly darker for volume.
    // Base colors: Top 0xFF252B42 -> Bottom 0xFF1A1F2E looks good for dark mode.
    // For light mode, we might want a clean white gradient or solid white.
    // Let's stick to the prompt's request which focused on "Dark Mode Premium".

    final gradient = isDarkMode
        ? const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF252B42), // Gris azulado medio oscuro
              Color(0xFF1A1F2E), // Tono ligeramente más oscuro
            ],
          )
        : const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFFFFF),
              Color(0xFFF5F7FA),
            ],
          );

    return AnimatedOpacity(
      opacity: isPaid ? 0.6 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 15, offset: Offset(0, 8))
        ],
        border: isPaid
            ? Border.all(
                color: Colors.green.withValues(alpha: 0.5),
                width: 1.0)
            : Border.all(
                color: Colors.white.withValues(alpha: 0.05), width: 0.5),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onPay,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Icono Vivo (Glassmorphism sutil)
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: itemColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    IconData(subscription.iconCode,
                        fontFamily: 'MaterialIcons'),
                    color: itemColor,
                    size: 25,
                  ),
                ),

                const SizedBox(width: 16), // Espaciado entre elementos

                // 2. Información Central
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Título
                      Text(
                        subscription.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: isDarkMode
                                ? Colors.white
                                : const Color(0xFF2D3436),
                            letterSpacing: -0.3),
                      ),
                      const SizedBox(height: 4), // Spacer vertical
                      // Subtítulo: Fecha o Pagado
                      if (isPaid)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle, size: 14, color: Colors.green),
                            const SizedBox(width: 4),
                            Text(
                              "Pagado",
                              style: TextStyle(
                                  fontSize: 12,
                                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                            ),
                          ],
                        )
                      else
                        Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                isOverdue ? FontWeight.w600 : FontWeight.w400,
                            color: isOverdue
                                ? statusColor
                                : (isDarkMode
                                    ? Colors.grey[400]
                                    : Colors.grey[600]),
                          ),
                        ),
                    ],
                  ),
                ),

                // 3. Monto
                Text(
                  "S/ ${subscription.amount.toStringAsFixed(0)}",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: isPaid 
                          ? (isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400) 
                          : itemColor, 
                      letterSpacing: -0.5),
                ),
                
                const SizedBox(width: 4),
                
                // 4. Menú de Gestión
                _buildActionMenu(context, isDarkMode),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildActionMenu(BuildContext context, bool isDarkMode) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: Icon(Icons.more_vert,
          size: 22, color: isDarkMode ? Colors.white24 : Colors.grey[400]),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: const Color(0xFF1E293B),
      elevation: 6,
      onSelected: (value) {
        if (value == 'edit') onTap();
        if (value == 'delete') onDelete();
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_rounded, color: Colors.cyanAccent, size: 20),
              SizedBox(width: 12),
              Text("Editar",
                  style: TextStyle(color: Colors.white, fontSize: 14)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          height: 48,
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded,
                  color: Colors.redAccent, size: 20),
              SizedBox(width: 12),
              Text("Eliminar",
                  style: TextStyle(color: Colors.white, fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
