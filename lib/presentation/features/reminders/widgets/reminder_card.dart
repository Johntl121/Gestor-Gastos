import 'package:flutter/material.dart';
import '../../../../domain/entities/reminder.dart';
import '../../../../core/constants/app_categories.dart';
import '../../../../core/utils/currency_formatter.dart';

class ReminderCard extends StatelessWidget {
  final Reminder reminder;
  final VoidCallback onTap;
  final VoidCallback? onComplete;
  final VoidCallback onToggleActive;
  final VoidCallback? onEdit;
  final VoidCallback onDelete;

  const ReminderCard({
    super.key,
    required this.reminder,
    required this.onTap,
    this.onComplete,
    required this.onToggleActive,
    this.onEdit,
    required this.onDelete,
  });

  IconData _getIcon() {
    if (reminder.categoryId != null) {
      return AppCategories.getIcon(reminder.categoryId!);
    }
    switch (reminder.type) {
      case ReminderType.payment:
        return Icons.payment_rounded;
      case ReminderType.income:
        return Icons.attach_money_rounded;
      case ReminderType.general:
        return Icons.event_rounded;
    }
  }

  Color _getColor() {
    if (reminder.categoryId != null) {
      return AppCategories.getColor(reminder.categoryId!);
    }
    switch (reminder.type) {
      case ReminderType.payment:
        return Colors.redAccent;
      case ReminderType.income:
        return Colors.green;
      case ReminderType.general:
        return Colors.blueAccent;
    }
  }

  String _getRecurrenceText() {
    switch (reminder.recurrence) {
      case ReminderRecurrence.daily:
        return "Diario";
      case ReminderRecurrence.weekly:
        return "Semanal";
      case ReminderRecurrence.monthly:
        return "Mensual";
      case ReminderRecurrence.yearly:
        return "Anual";
      case ReminderRecurrence.none:
        return "Una sola vez";
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final now = DateTime.now();
    final status = reminder.getStatus(now);
    final itemColor = _getColor();

    String statusText = "";
    Color statusColor = isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;
    FontWeight statusWeight = FontWeight.w400;

    if (status == ReminderStatus.completed) {
      statusText = "Completado";
    } else if (status == ReminderStatus.inactive) {
      statusText = "Inactivo";
    } else if (status == ReminderStatus.overdue) {
      statusText = "Vencido";
      statusColor = const Color(0xFFFF5252);
      statusWeight = FontWeight.w600;
    } else {
      final nextOcc = reminder.getNextOccurrence(now);
      if (nextOcc != null) {
        if (nextOcc.year == now.year &&
            nextOcc.month == now.month &&
            nextOcc.day == now.day) {
          statusText = "¡Hoy!";
          statusColor = Colors.orange;
          statusWeight = FontWeight.bold;
        } else {
          final dDay = nextOcc.day.toString().padLeft(2, '0');
          final dMonth = nextOcc.month.toString().padLeft(2, '0');
          statusText = "$dDay/$dMonth";
        }
      }
    }

    final isInactiveOrCompleted = status == ReminderStatus.completed || status == ReminderStatus.inactive;

    final gradient = isDarkMode
        ? const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF252B42), Color(0xFF1A1F2E)],
          )
        : const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFFFF), Color(0xFFF5F7FA)],
          );

    return AnimatedOpacity(
      opacity: isInactiveOrCompleted ? 0.6 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
                color: Colors.black26, blurRadius: 15, offset: Offset(0, 8))
          ],
          border: status == ReminderStatus.completed
              ? Border.all(
                  color: Colors.green.withValues(alpha: 0.5), width: 1.0)
              : status == ReminderStatus.overdue
                  ? Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.6), width: 1.5)
                  : Border.all(
                      color: Colors.white.withValues(alpha: 0.05), width: 0.5),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 1. Icono Vivo
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: itemColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getIcon(),
                      color: itemColor,
                      size: 25,
                    ),
                  ),

                  const SizedBox(width: 16),

                  // 2. Información Central
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Título
                        Text(
                          reminder.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            decoration: status == ReminderStatus.completed
                                ? TextDecoration.lineThrough
                                : null,
                            color: isDarkMode
                                ? Colors.white
                                : const Color(0xFF2D3436),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Subtítulo: Estado y Recurrencia
                        Row(
                          children: [
                            if (status == ReminderStatus.completed) ...[
                              const Icon(Icons.check_circle, size: 14, color: Colors.green),
                              const SizedBox(width: 4),
                            ] else if (status == ReminderStatus.overdue) ...[
                              Icon(Icons.warning_rounded, size: 14, color: statusColor),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              "$statusText • ${_getRecurrenceText()}",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: statusWeight,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // 3. Monto (Opcional)
                  if (reminder.amount != null && reminder.amount! > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Text(
                        CurrencyFormatter.format(reminder.amount!, reminder.currencyCode ?? "S/"),
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isInactiveOrCompleted
                                ? (isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400)
                                : itemColor,
                            letterSpacing: -0.5),
                      ),
                    ),

                  // 4. Botón Completar (solo si es onetime y activo)
                  if (reminder.recurrence == ReminderRecurrence.none && 
                      reminder.active && 
                      reminder.completedAt == null &&
                      onComplete != null)
                    IconButton(
                      icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                      onPressed: onComplete,
                    ),

                  // 5. Menú de Gestión
                  _buildActionMenu(context, isDarkMode, status),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionMenu(BuildContext context, bool isDarkMode, ReminderStatus status) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: Icon(Icons.more_vert,
          size: 22, color: isDarkMode ? Colors.white24 : Colors.grey[400]),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: const Color(0xFF1E293B),
      elevation: 6,
      onSelected: (value) {
        if (value == 'edit' && onEdit != null) onEdit!();
        if (value == 'toggleActive') onToggleActive();
        if (value == 'delete') onDelete();
      },
      itemBuilder: (context) => [
        if (onEdit != null)
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
        if (status != ReminderStatus.completed)
          PopupMenuItem(
            value: 'toggleActive',
            child: Row(
              children: [
                Icon(reminder.active ? Icons.pause_circle_outline : Icons.play_circle_outline, 
                     color: Colors.orangeAccent, size: 20),
                const SizedBox(width: 12),
                Text(reminder.active ? "Desactivar" : "Activar",
                    style: const TextStyle(color: Colors.white, fontSize: 14)),
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
}
