import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../domain/entities/reminder.dart';
import '../../../providers/reminder_provider.dart';
import '../../reminders/reminders_page.dart';
import '../../reminders/widgets/reminder_card.dart';
import '../../reminders/widgets/reminder_form_sheet.dart';

class RemindersSummarySection extends StatelessWidget {
  const RemindersSummarySection({super.key});

  void _completeOneTime(BuildContext context, ReminderProvider provider,
      Reminder reminder) async {
    final res = await provider.completeOneTime(reminder.id);
    res.fold(
      (failure) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(failure.message)));
        }
      },
      (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Recordatorio completado 🎉")));
        }
      },
    );
  }

  void _toggleActive(BuildContext context, ReminderProvider provider,
      Reminder reminder) async {
    final res = await provider.toggleActive(reminder.id, !reminder.active);
    res.fold(
      (failure) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(failure.message)));
        }
      },
      (_) {},
    );
  }

  void _confirmDelete(BuildContext context, ReminderProvider provider,
      Reminder reminder) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Eliminar Recordatorio"),
        content: const Text(
            "¿Estás seguro de eliminar este recordatorio? Esta acción no se puede deshacer."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Eliminar"),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final res = await provider.deleteReminder(reminder.id);
      res.fold(
        (failure) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text("Error al eliminar el recordatorio")));
          }
        },
        (_) {},
      );
    }
  }

  void _showReminderForm(BuildContext context, [Reminder? reminder]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReminderFormSheet(existingReminder: reminder),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Consumer<ReminderProvider>(
      builder: (context, provider, child) {
        // Collect up to 3 active reminders: overdue first, then upcoming
        final activeOverdue = provider.overdue.where((r) => r.active).toList();
        final activeUpcoming =
            provider.upcoming.where((r) => r.active).toList();

        final combined = [...activeOverdue, ...activeUpcoming];
        final displayItems = combined.take(3).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    "Recordatorios",
                    style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const RemindersPage()),
                      );
                    },
                    child: const Text(
                      "Ver todos",
                      style: TextStyle(
                          color: Colors.cyan, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _showReminderForm(context),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                          color: const Color(0xFF00E5FF),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00E5FF)
                                  .withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            )
                          ]),
                      child: const Icon(Icons.add,
                          color: Colors.black87, size: 26),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            if (provider.isLoading && displayItems.isEmpty)
              const Center(child: CircularProgressIndicator())
            else if (displayItems.isEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: SizedBox(
                  width: double.infinity,
                  child: Center(
                    child: Text(
                      "No tienes recordatorios próximos.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: isDarkMode ? Colors.grey : Colors.grey[600]),
                    ),
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: displayItems.length,
                  itemBuilder: (context, index) {
                    final reminder = displayItems[index];
                    return ReminderCard(
                      reminder: reminder,
                      onTap: () => _showReminderForm(context, reminder),
                      onComplete: () =>
                          _completeOneTime(context, provider, reminder),
                      onToggleActive: () =>
                          _toggleActive(context, provider, reminder),
                      onDelete: () =>
                          _confirmDelete(context, provider, reminder),
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
