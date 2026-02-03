import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/datasources/transaction_local_data_source.dart';
import '../../injection_container.dart' as sl;
import '../providers/dashboard_provider.dart';
import 'onboarding_page.dart';
import '../../data/models/subscription.dart';
import '../../data/datasources/local_database.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  void _showAddSubscriptionDialog(BuildContext context) {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    final dayController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E2730),
          title: const Text("Nueva Suscripción",
              style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                    labelText: "Nombre (ej. Netflix)",
                    labelStyle: TextStyle(color: Colors.grey),
                    enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey))),
              ),
              TextField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                    labelText:
                        "Monto (${Provider.of<DashboardProvider>(context, listen: false).currencySymbol})",
                    labelStyle: TextStyle(color: Colors.grey),
                    enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey))),
              ),
              TextField(
                controller: dayController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                    labelText: "Día de Pago (1-31)",
                    labelStyle: TextStyle(color: Colors.grey),
                    enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey))),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancelar",
                    style: TextStyle(color: Colors.grey))),
            TextButton(
              onPressed: () {
                final name = nameController.text;
                final amount = double.tryParse(amountController.text) ?? 0.0;
                final day = int.tryParse(dayController.text) ?? 1;

                if (name.isNotEmpty && amount > 0) {
                  final sub = Subscription(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: name,
                    amount: amount,
                    renewalDay: day,
                  );
                  Provider.of<DashboardProvider>(context, listen: false)
                      .addSubscription(sub);
                  Navigator.pop(ctx);
                }
              },
              child:
                  const Text("Agregar", style: TextStyle(color: Colors.cyan)),
            ),
          ],
        );
      },
    );
  }

  void _showEditBudgetDialog(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final TextEditingController controller = TextEditingController(
      text: provider.budgetLimit.toString(),
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E2730),
          title: const Text("Editar Límite Mensual",
              style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              prefixText: '${provider.currencySymbol} ',
              prefixStyle: TextStyle(color: Colors.cyan),
              enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey)),
              focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.cyan)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child:
                  const Text("Cancelar", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                final newLimit = double.tryParse(controller.text);
                if (newLimit != null && newLimit > 0) {
                  provider.setBudgetLimit(newLimit);
                }
                Navigator.of(ctx).pop();
              },
              child:
                  const Text("Guardar", style: TextStyle(color: Colors.cyan)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Colors based on "Dark Theme" request
    const backgroundColor = Color(0xFF121C22);
    const cardColor = Color(0xFF1E2730); // Slightly lighter for cards
    const cyanColor = Color(0xFF00E5FF);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text("Configuración",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          children: [
            // 2. HEADER
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: cyanColor, width: 2)),
              child: const CircleAvatar(
                radius: 50,
                backgroundImage: NetworkImage(
                    'https://i.pravatar.cc/150?img=11'), // Placeholder
              ),
            ),
            const SizedBox(height: 12),
            Consumer<DashboardProvider>(builder: (context, provider, child) {
              return Text(provider.userName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold));
            }),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.circle, color: Colors.greenAccent, size: 10),
                SizedBox(width: 6),
                Text("Estado: Balanceado",
                    style: TextStyle(color: Colors.grey, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.grey),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                foregroundColor: Colors.white,
              ),
              child: const Text("Editar Perfil"),
            ),

            const SizedBox(height: 30),

            // 3. BUDGET CONFIGURATION
            Align(
                alignment: Alignment.centerLeft,
                child: Text("Configuración de Presupuesto",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold))),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("LÍMITE MENSUAL",
                          style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                      GestureDetector(
                          onTap: () => _showEditBudgetDialog(context),
                          child: const Icon(Icons.edit,
                              color: Colors.blueAccent, size: 20)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Consumer<DashboardProvider>(
                    builder: (context, provider, child) {
                      return Text(
                        "${provider.currencySymbol} ${provider.budgetLimit.toStringAsFixed(2)}",
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Tu estado emocional se actualiza en base a este límite.",
                    style: TextStyle(color: Colors.white30, fontSize: 11),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // 4. SUBSCRIPTION MANAGER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Suscripciones",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.cyan),
                  onPressed: () => _showAddSubscriptionDialog(context),
                )
              ],
            ),
            const SizedBox(height: 12),
            Consumer<DashboardProvider>(
              builder: (context, provider, child) {
                if (provider.subscriptions.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    width: double.infinity,
                    decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(16)),
                    child: const Text(
                      "No tienes suscripciones activas.\n¡Agrega una para controlar tus gastos fijos!",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }
                return Column(
                  children: provider.subscriptions.map((sub) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildSubscriptionItem(
                        id: sub.id,
                        name: sub.name,
                        renewal: "Día ${sub.renewalDay}",
                        price:
                            "${provider.currencySymbol} ${sub.amount.toStringAsFixed(2)}",
                        icon: Icons.subscriptions,
                        iconColor: Colors.purpleAccent,
                        cardColor: cardColor,
                        onDelete: () => provider.removeSubscription(sub.id),
                      ),
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 30),

            // 5. APP PREFERENCES
            Align(
                alignment: Alignment.centerLeft,
                child: Text("Preferencias de App",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold))),
            const SizedBox(height: 12),
            _buildPreferenceSwitch(
                "Modo Oscuro", true, Icons.dark_mode, cardColor),
            _buildPreferenceSwitch(
                "Notificaciones", true, Icons.notifications, cardColor),
            _buildPreferenceSwitch(
                "Face ID / Touch ID", false, Icons.fingerprint, cardColor),

            const SizedBox(height: 40),

            // 6. FOOTER
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () async {
                  // Full Reset (Fixes corruption)
                  final dataSource = sl.sl<TransactionLocalDataSource>();
                  await dataSource.clearAllData();
                  await LocalDatabase().clearAllTables();

                  if (context.mounted) {
                    // Reset Provider to clean in-memory state
                    Provider.of<DashboardProvider>(context, listen: false)
                        .resetState();

                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                          builder: (context) => const OnboardingPage()),
                      (route) => false,
                    );
                  }
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  foregroundColor: Colors.redAccent,
                ),
                icon: const Icon(Icons.restart_alt),
                label: const Text("Reiniciar App (Demo)"),
              ),
            ),
            const SizedBox(height: 16),
            const Text("Versión de App 1.0.0",
                style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionItem({
    required String id,
    required String name,
    required String renewal,
    required String price,
    required IconData icon,
    required Color iconColor,
    required Color cardColor,
    required VoidCallback onDelete,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                const SizedBox(height: 2),
                Text(renewal,
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          Text(price,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
          const SizedBox(width: 10),
          IconButton(
            icon: Icon(Icons.delete_outline,
                color: Colors.redAccent.withOpacity(0.7), size: 20),
            onPressed: onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          )
        ],
      ),
    );
  }

  Widget _buildPreferenceSwitch(
      String title, bool value, IconData icon, Color cardColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: (val) {},
        activeColor: Colors.cyan,
        title: Text(title,
            style: const TextStyle(color: Colors.white, fontSize: 14)),
        secondary: Icon(icon, color: Colors.grey),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
