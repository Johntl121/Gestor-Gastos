import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/reminder_provider.dart';
import '../../../../domain/entities/reminder.dart';
import 'widgets/reminder_card.dart';

class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key});

  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ReminderProvider>(context, listen: false).loadReminders();
    });
  }

  void _confirmDelete(BuildContext context, ReminderProvider provider, Reminder reminder) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Eliminar Recordatorio"),
        content: const Text("¿Estás seguro de eliminar este recordatorio? Esta acción no se puede deshacer."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
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
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error al eliminar el recordatorio")));
          }
        },
        (_) {},
      );
    }
  }

  void _toggleActive(BuildContext context, ReminderProvider provider, Reminder reminder) async {
    final res = await provider.toggleActive(reminder.id, !reminder.active);
    res.fold(
      (failure) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
        }
      },
      (_) {},
    );
  }

  void _completeOneTime(BuildContext context, ReminderProvider provider, Reminder reminder) async {
    final res = await provider.completeOneTime(reminder.id);
    res.fold(
      (failure) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
        }
      },
      (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Recordatorio completado 🎉")));
        }
      },
    );
  }

  Widget _buildSection(String title, List<Reminder> items, ReminderProvider provider) {
    if (items.isEmpty) return const SizedBox.shrink();
    
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 24, bottom: 12),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final reminder = items[index];
            return ReminderCard(
              reminder: reminder,
              onTap: () {}, // MVP: No details yet
              onComplete: () => _completeOneTime(context, provider, reminder),
              onToggleActive: () => _toggleActive(context, provider, reminder),
              onDelete: () => _confirmDelete(context, provider, reminder),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = theme.scaffoldBackgroundColor;
    final textColor = theme.textTheme.titleLarge?.color ?? Colors.black;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        title: Text("Todos los Recordatorios", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Consumer<ReminderProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.reminders.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.reminders.isEmpty) {
            return Center(
              child: Text(
                "No tienes recordatorios creados.",
                style: TextStyle(color: Colors.grey[500]),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSection("Vencidos", provider.overdue, provider),
                _buildSection("Próximos", provider.upcoming, provider),
                _buildSection("Inactivos", provider.inactive, provider),
                _buildSection("Completados", provider.completed, provider),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }
}
