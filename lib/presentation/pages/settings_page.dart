import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/dashboard_provider.dart';
import 'onboarding_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(builder: (context, provider, child) {
      final isDarkMode = provider.isDarkMode;
      final backgroundColor =
          isDarkMode ? const Color(0xFF15202B) : const Color(0xFFF5F7FA);
      final cardColor = isDarkMode ? const Color(0xFF1F2937) : Colors.white;
      final textColor = isDarkMode ? Colors.white : Colors.black;
      final subTextColor = isDarkMode ? Colors.grey : Colors.blueGrey;
      const cyanColor = Color(0xFF00E5FF);

      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          title: Text("Configuración",
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: textColor),
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
              Text(provider.userName,
                  style: TextStyle(
                      color: textColor,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text("Estado: Balanceado",
                  style: TextStyle(color: subTextColor, fontSize: 14)),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => _showEditProfileDialog(context),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                      color: isDarkMode ? Colors.grey : Colors.grey.shade400),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  foregroundColor: textColor,
                ),
                child: const Text("Editar Perfil"),
              ),

              const SizedBox(height: 30),

              // 3. BUDGET CONFIGURATION
              Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Configuración de Presupuesto",
                      style: TextStyle(
                          color: textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold))),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: isDarkMode
                        ? []
                        : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              offset: const Offset(0, 4),
                              blurRadius: 10,
                            )
                          ]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("LÍMITE MENSUAL",
                            style: TextStyle(
                                color: subTextColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                        GestureDetector(
                            onTap: () => _showEditBudgetDialog(context),
                            child: const Icon(Icons.edit,
                                color: Colors.blueAccent, size: 20)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "${provider.currencySymbol} ${provider.budgetLimit.toStringAsFixed(2)}",
                      style: TextStyle(
                          color: textColor,
                          fontSize: 28,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Tu estado emocional se actualiza en base a este límite.",
                      style: TextStyle(
                          color: isDarkMode ? Colors.white30 : Colors.grey,
                          fontSize: 11),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // 4. SUBSCRIPTION MANAGER
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Suscripciones",
                      style: TextStyle(
                          color: textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.cyan),
                    onPressed: () => _showAddSubscriptionDialog(context),
                  )
                ],
              ),
              const SizedBox(height: 12),
              // Placeholder List
              Container(
                padding: const EdgeInsets.all(20),
                width: double.infinity,
                decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: isDarkMode
                        ? []
                        : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              offset: const Offset(0, 4),
                              blurRadius: 10,
                            )
                          ]),
                child: Text(
                  "Tus suscripciones aparecerán aquí en futuras versiones.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: subTextColor),
                ),
              ),

              const SizedBox(height: 30),

              // 5. APP PREFERENCES
              Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Preferencias de App",
                      style: TextStyle(
                          color: textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold))),
              const SizedBox(height: 12),
              Column(
                children: [
                  _buildPreferenceSwitch(
                      "Modo Oscuro",
                      provider.isDarkMode,
                      Icons.dark_mode,
                      cardColor,
                      textColor,
                      isDarkMode,
                      (val) => provider.toggleTheme(
                          val)), // Toggle passes boolean, which provider uses to switch

                  // PIN Lock Switch
                  _buildPreferenceSwitch(
                      "Bloqueo con PIN",
                      provider.isPinEnabled,
                      Icons.lock,
                      cardColor,
                      textColor,
                      isDarkMode, (val) {
                    if (val) {
                      // ON: Create PIN
                      _showPinDialog(context, isCreating: true,
                          onConfirmed: (pin) {
                        provider.setPin(pin);
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("PIN Establecido ✅")));
                      });
                    } else {
                      // OFF: Verify to Disable
                      if (provider.isPinEnabled) {
                        _showPinDialog(context, isCreating: false,
                            onConfirmed: (pin) {
                          if (provider.verifyPin(pin)) {
                            provider.removePin();
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text("PIN Eliminado 🔓")));
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text("PIN Incorrecto ❌"),
                                    backgroundColor: Colors.red));
                          }
                        });
                      }
                    }
                  }),

                  if (provider.isPinEnabled)
                    Padding(
                      padding: const EdgeInsets.only(left: 16, bottom: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          icon: Icon(Icons.lock_reset,
                              size: 16, color: subTextColor),
                          label: Text("Cambiar PIN",
                              style: TextStyle(color: subTextColor)),
                          onPressed: () {
                            _showPinDialog(context, isCreating: true,
                                onConfirmed: (pin) {
                              provider.setPin(pin);
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text("PIN Actualizado")));
                            });
                          },
                        ),
                      ),
                    ),

                  _buildPreferenceSwitch(
                      "Notificaciones",
                      provider.enableNotifications,
                      Icons.notifications,
                      cardColor,
                      textColor,
                      isDarkMode, (val) {
                    provider.toggleNotifications(val);
                    if (val)
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text("🔔 Notificaciones Activas")));
                  }),
                  _buildPreferenceSwitch(
                      "Face ID / Touch ID",
                      provider.enableBiometrics,
                      Icons.fingerprint,
                      cardColor,
                      textColor,
                      isDarkMode, (val) {
                    provider.toggleBiometrics(val);
                    if (val)
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text("👆 Biometría Vinculada (Simulado)")));
                  }),
                ],
              ),

              const SizedBox(height: 30),

              // 6. DATA & SECURITY
              Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Datos y Seguridad",
                      style: TextStyle(
                          color: textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold))),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: isDarkMode
                        ? []
                        : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              offset: const Offset(0, 4),
                              blurRadius: 10,
                            )
                          ]),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.file_download,
                          color: Colors.tealAccent),
                      title: Text("Exportar Datos (CSV)",
                          style: TextStyle(color: textColor)),
                      subtitle: Text("Copia tus gastos al portapapeles",
                          style: TextStyle(color: subTextColor, fontSize: 12)),
                      onTap: () => _exportData(context),
                    ),
                    Divider(color: Colors.grey.withOpacity(0.2), height: 1),
                    ListTile(
                      leading: const Icon(Icons.delete_forever,
                          color: Colors.redAccent),
                      title: const Text("Reiniciar App / Borrar Todo",
                          style: TextStyle(color: Colors.redAccent)),
                      onTap: () => _confirmReset(context),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),
              Text("Versión de App 1.1.0",
                  style: TextStyle(color: subTextColor, fontSize: 12)),
              const SizedBox(height: 20),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildPreferenceSwitch(
      String title,
      bool value,
      IconData icon,
      Color cardColor,
      Color textColor,
      bool isDarkMode,
      Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isDarkMode
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, 4),
                    blurRadius: 10,
                  )
                ]),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.cyan,
        title: Text(title, style: TextStyle(color: textColor, fontSize: 14)),
        secondary:
            Icon(icon, color: isDarkMode ? Colors.grey : Colors.grey[600]),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final isDarkMode = provider.isDarkMode;
    final backgroundColor = isDarkMode ? const Color(0xFF1E2730) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final hintColor = isDarkMode ? Colors.grey : Colors.grey[600];

    final controller = TextEditingController(text: provider.userName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: backgroundColor,
        title: Text("Editar Perfil", style: TextStyle(color: textColor)),
        content: TextField(
          controller: controller,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            labelText: "Nombre de Usuario",
            labelStyle: TextStyle(color: hintColor),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                    color: isDarkMode ? Colors.grey : Colors.grey.shade400)),
            focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.cyan)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancelar", style: TextStyle(color: hintColor)),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                provider.setUserName(controller.text.trim());
              }
              Navigator.pop(ctx);
            },
            child: const Text("Guardar", style: TextStyle(color: Colors.cyan)),
          ),
        ],
      ),
    );
  }

  void _showPinDialog(BuildContext context,
      {required bool isCreating, Function(String)? onConfirmed}) {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final isDarkMode = provider.isDarkMode;
    final backgroundColor = isDarkMode ? const Color(0xFF1E2730) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;

    String currentPin = "";
    final digits = [
      '1',
      '2',
      '3',
      '4',
      '5',
      '6',
      '7',
      '8',
      '9',
      'C',
      '0',
      'OK'
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: backgroundColor,
            title: Text(
                isCreating ? "Crea tu PIN (4 dígitos)" : "Ingresa tu PIN",
                style: TextStyle(color: textColor, fontSize: 18)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // PIN Display
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: CircleAvatar(
                          radius: 10,
                          backgroundColor: index < currentPin.length
                              ? Colors.cyan
                              : (isDarkMode
                                  ? Colors.grey[700]
                                  : Colors.grey[300]),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 20),
                // Keypad
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: digits.map((digit) {
                    return SizedBox(
                      width: 60,
                      height: 60,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor:
                              isDarkMode ? Colors.grey[800] : Colors.grey[200],
                          shape: const CircleBorder(),
                        ),
                        onPressed: () {
                          if (digit == 'C') {
                            if (currentPin.isNotEmpty) {
                              setState(() => currentPin = currentPin.substring(
                                  0, currentPin.length - 1));
                            }
                          } else if (digit == 'OK') {
                            if (currentPin.length == 4) {
                              Navigator.pop(ctx);
                              if (onConfirmed != null) onConfirmed(currentPin);
                            }
                          } else {
                            if (currentPin.length < 4) {
                              setState(() => currentPin += digit);
                            }
                          }
                        },
                        child: Text(digit,
                            style: TextStyle(
                                color: isDarkMode ? Colors.white : Colors.black,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showAddSubscriptionDialog(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("🚀 Próximamente: Gestión avanzada en Billetera"),
        backgroundColor: Colors.purpleAccent,
      ),
    );
  }

  void _exportData(BuildContext context) async {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final transactions = provider.transactions;

    // Build CSV
    StringBuffer buffer = StringBuffer();
    buffer.writeln("Fecha,Tipo,Monto,Concepto,Nota");
    for (var t in transactions) {
      buffer.writeln(
          "${t.date.toIso8601String()},${t.type},${t.amount},${t.description},${t.note ?? ''}");
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString()));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("¡Reporte Generado! Copiado al portapapeles. 📋"),
          backgroundColor: Colors.teal,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _showEditBudgetDialog(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final isDarkMode = provider.isDarkMode;
    final backgroundColor = isDarkMode ? const Color(0xFF1E2730) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final hintColor = isDarkMode ? Colors.grey : Colors.grey[600];

    final TextEditingController controller = TextEditingController(
      text: provider.budgetLimit.toString(),
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: backgroundColor,
          title:
              Text("Editar Límite Mensual", style: TextStyle(color: textColor)),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              prefixText: '${provider.currencySymbol} ',
              prefixStyle: const TextStyle(color: Colors.cyan),
              enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                      color: isDarkMode ? Colors.grey : Colors.grey.shade400)),
              focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.cyan)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text("Cancelar", style: TextStyle(color: hintColor)),
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

  void _confirmReset(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final isDarkMode = provider.isDarkMode;
    final backgroundColor = isDarkMode ? const Color(0xFF1E2730) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subTextColor = isDarkMode ? Colors.white70 : Colors.black54;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: backgroundColor,
        title: Text("¿Estás seguro?",
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        content: Text(
          "Esta acción borrará TODAS tus transacciones, cuentas y metas. Es irreversible.",
          style: TextStyle(color: subTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancelar",
                style: TextStyle(
                    color: isDarkMode ? Colors.grey : Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx); // Close Dialog

              final provider =
                  Provider.of<DashboardProvider>(context, listen: false);
              await provider.resetAllData();

              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                      builder: (context) => const OnboardingPage()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text("BORRAR TODO",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
