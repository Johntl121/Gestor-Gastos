import 'package:flutter/material.dart';
import '../../../../data/models/subscription.dart';

class FixedExpenseCard extends StatelessWidget {
  final Subscription subscription;
  final VoidCallback onTap;
  final VoidCallback onPay;
  final VoidCallback onDelete;

  const FixedExpenseCard({
    super.key,
    required this.subscription,
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
      statusColor = const Color(0xFF00E676); // Verde
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black26, blurRadius: 15, offset: const Offset(0, 8))
        ],
        border: isPaid
            ? Border.all(
                color: const Color(0xFF00E676).withOpacity(0.3), width: 1.0)
            : Border.all(color: Colors.white.withOpacity(0.05), width: 0.5),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onPay,
          child: Stack(
            children: [
              // Contenido Principal con Padding Generoso (Regla 2)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    // 1. Icono Vivo (Glassmorphism sutil)
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: itemColor.withOpacity(0.15),
                        shape: BoxShape.circle,
                        // No border in this new clean style unless needed
                      ),
                      child: Icon(
                        IconData(subscription.iconCode,
                            fontFamily: 'MaterialIcons'),
                        color: itemColor,
                        size: 26,
                      ),
                    ),

                    const SizedBox(width: 16), // Espaciado entre elementos

                    // 2. Información Central
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Título: Grande, Blanco/Negro, w600 (Regla 3)
                          Text(
                            subscription.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 18,
                                color: isDarkMode
                                    ? Colors.white
                                    : const Color(0xFF2D3436),
                                letterSpacing: -0.3),
                          ),
                          const SizedBox(height: 6), // Spacer vertical
                          // Subtítulo: Fecha (Regla 3 - 14px Grey)
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

                    // 3. Datos Clave (Derecha)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Monto: Grande, Bold, Color Dinámico (Regla 3)
                        Text(
                          "S/ ${subscription.amount.toStringAsFixed(0)}",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                              color: itemColor, // Color dinámico para resaltar
                              letterSpacing: -0.5),
                        ),
                        const SizedBox(height: 6),
                        // Cuenta: Pequeño, Gris (Regla 3)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_getAccountName(subscription.accountToCharge),
                                style: TextStyle(
                                    color: isDarkMode
                                        ? Colors.grey[400]
                                        : Colors.grey[600],
                                    fontSize:
                                        13, // Slightly adjusted for balance
                                    fontWeight: FontWeight.w500)),
                            const SizedBox(width: 4),
                            Icon(
                              _getAccountIcon(subscription.accountToCharge),
                              size: 14,
                              color: isDarkMode
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(
                        width: 24), // Espacio para el menú (Stack overlays it)
                  ],
                ),
              ),

              // 4. Menú de Gestión (Top Right)
              Positioned(
                top: 8,
                right: 4,
                child: _buildActionMenu(context, isDarkMode),
              ),
            ],
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

  IconData _getAccountIcon(int accountId) {
    switch (accountId) {
      case 1:
        return Icons.payments_outlined;
      case 2:
        return Icons.account_balance_outlined;
      case 3:
        return Icons.savings_outlined;
      default:
        return Icons.wallet;
    }
  }

  String _getAccountName(int accountId) {
    switch (accountId) {
      case 1:
        return "Efectivo";
      case 2:
        return "Banco";
      case 3:
        return "Ahorros";
      default:
        return "Cta";
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
