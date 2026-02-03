import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dashboard_provider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

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
            decoration: const InputDecoration(
              prefixText: 'S/ ',
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
            const Text("Alex Johnson",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
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
                        "S/ ${provider.budgetLimit.toStringAsFixed(2)}",
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
            Align(
                alignment: Alignment.centerLeft,
                child: Text("Suscripciones",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold))),
            const SizedBox(height: 12),
            _buildSubscriptionItem(
              name: "Netflix Premium",
              renewal: "Renueva Sep 12",
              price: "S/ 45.00",
              icon: Icons.movie,
              iconColor: Colors.redAccent,
              cardColor: cardColor,
            ),
            const SizedBox(height: 10),
            _buildSubscriptionItem(
              name: "Spotify Familiar",
              renewal: "Renueva Sep 18",
              price: "S/ 26.00",
              icon: Icons.music_note,
              iconColor: Colors.greenAccent,
              cardColor: cardColor,
            ),
            const SizedBox(height: 10),
            _buildSubscriptionItem(
              name: "iCloud+ 2TB",
              renewal: "Renueva Sep 01",
              price: "S/ 39.00",
              icon: Icons.cloud,
              iconColor: Colors.blueAccent,
              cardColor: cardColor,
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
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  foregroundColor: Colors.redAccent,
                ),
                icon: const Icon(Icons.logout),
                label: const Text("Cerrar Sesión"),
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
    required String name,
    required String renewal,
    required String price,
    required IconData icon,
    required Color iconColor,
    required Color cardColor,
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
