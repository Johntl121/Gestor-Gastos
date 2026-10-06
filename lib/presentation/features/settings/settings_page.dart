import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
// Providers
import '../../providers/ui_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../../../data/datasources/preferences_local_data_source.dart';
import '../../../core/services/biometric_service.dart';
import '../../../../core/services/database_helper.dart';
import '../../../core/constants/app_strings.dart';
import '../../../injection_container.dart' as sl;

import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../auth/onboarding_page.dart';

import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../domain/usecases/create_backup_usecase.dart';
import '../../../../domain/usecases/restore_backup_usecase.dart';


class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Consume Providers
    final uiProvider = Provider.of<UiProvider>(context);
    final walletProvider = Provider.of<WalletProvider>(context);

    final isDarkMode = uiProvider.isDarkMode;
    final backgroundColor =
        isDarkMode ? const Color(0xFF15202B) : const Color(0xFFF5F7FA);
    final cardColor = isDarkMode ? const Color(0xFF1F2937) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subTextColor = isDarkMode ? Colors.grey : Colors.blueGrey;
    const cyanColor = Color(0xFF00E5FF);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(AppStrings.settingsTitle,
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
              child: GestureDetector(
                onTap: () => _showAvatarSelectionSheet(context),
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.transparent,
                      backgroundImage: uiProvider.profileImagePath != null
                          ? FileImage(File(uiProvider.profileImagePath!))
                          : null,
                      child: uiProvider.profileImagePath == null
                          ? Text(uiProvider.userAvatar,
                              style: const TextStyle(fontSize: 70))
                          : null,
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                          color: Colors.cyanAccent, shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt,
                          size: 18, color: Colors.black),
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(uiProvider.userName,
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
                            color: Colors.black.withValues(alpha: 0.05),
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
                    "${walletProvider.currencySymbol} ${walletProvider.budgetLimit.toStringAsFixed(2)}",
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
                    uiProvider.isDarkMode,
                    Icons.dark_mode,
                    cardColor,
                    textColor,
                    isDarkMode,
                    (val) =>
                        uiProvider.toggleTheme(val)), // Toggle passes boolean

                // PIN Lock Switch
                _buildPreferenceSwitch(
                    "Bloqueo con PIN",
                    uiProvider.isPinEnabled,
                    Icons.lock,
                    cardColor,
                    textColor,
                    isDarkMode, (val) {
                  if (val) {
                    // ON: Create PIN
                    _showPinDialog(context, isCreating: true,
                        onConfirmed: (pin) {
                      uiProvider.setPin(pin);
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("PIN Establecido ✅")));
                    });
                  } else {
                    // OFF: Verify to Disable
                    if (uiProvider.isPinEnabled) {
                      _showPinDialog(context, isCreating: false,
                          onConfirmed: (pin) async {
                        final isValid = await uiProvider.verifyPin(pin);
                        if (!context.mounted) return;
                        if (isValid) {
                          await uiProvider.removePin();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text("PIN Eliminado 🔓")));
                        } else {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(
                            content: Row(
                              children: [
                                Icon(Icons.error_outline,
                                    color: Colors.redAccent, size: 20),
                                SizedBox(width: 8),
                                Text("PIN Incorrecto ❌"),
                              ],
                            ),
                          ));
                        }
                      });
                    }
                  }
                }),

                if (uiProvider.isPinEnabled)
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
                          _showPinDialog(context, isCreating: false,
                              onConfirmed: (oldPin) async {
                            final isValid = await uiProvider.verifyPin(oldPin);
                            if (!context.mounted) return;
                            if (isValid) {
                              _showPinDialog(context, isCreating: true,
                                  onConfirmed: (newPin) async {
                                await uiProvider.setPin(newPin);
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text("PIN Actualizado")));
                              });
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("PIN Incorrecto")));
                            }
                          });
                        },
                      ),
                    ),
                  ),

                _buildPreferenceSwitch(
                    "Notificaciones",
                    uiProvider.enableNotifications,
                    Icons.notifications,
                    cardColor,
                    textColor,
                    isDarkMode, (val) async {
                  final status = await uiProvider.toggleNotifications(val);

                  if (!context.mounted) return;

                  // Using string matching to avoid importing NotificationCoordinator directly in UI if possible
                  if (status.toString() == 'NotificationStatus.scheduled') {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text("🔔 Notificaciones Activas")));
                  } else if (status.toString() == 'NotificationStatus.permissionDenied') {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text("❌ Permiso denegado por el sistema")));
                  } else if (status.toString() == 'NotificationStatus.timezoneUnavailable') {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text("❌ Error de zona horaria")));
                  }
                }),
                _buildPreferenceSwitch(
                    "Face ID / Touch ID",
                    uiProvider.enableBiometrics,
                    Icons.fingerprint,
                    cardColor,
                    textColor,
                    isDarkMode, (val) async {
                  if (val) {
                    final pin = await sl.sl<PreferencesLocalDataSource>().getSecurityPinAsync();
                    if (pin == null || pin.isEmpty) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text("❌ Configure un PIN de seguridad primero")));
                      return;
                    }
                    final biometricService = sl.sl<BiometricService>();
                    if (!await biometricService.isSupported()) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text("❌ Dispositivo no compatible con biometría")));
                      return;
                    }
                    if (!await biometricService.hasEnrolledBiometrics()) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text("❌ Debe enrolar su huella/rostro en los ajustes del dispositivo")));
                      return;
                    }
                  }
                  uiProvider.toggleBiometrics(val);
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
                            color: Colors.black.withValues(alpha: 0.05),
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
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.backup, color: Colors.cyan),
                    title: Text("Crear copia de seguridad", style: TextStyle(color: textColor)),
                    subtitle: Text("Guarda un respaldo cifrado de tus datos", style: TextStyle(color: subTextColor, fontSize: 12)),
                    onTap: () => _showCreateBackupDialog(context),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.settings_backup_restore, color: Colors.orangeAccent),
                    title: Text("Restaurar copia de seguridad", style: TextStyle(color: textColor)),
                    subtitle: Text("Recupera tus datos desde un archivo", style: TextStyle(color: subTextColor, fontSize: 12)),
                    onTap: () => _restoreBackup(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // 7. DANGER ZONE
            const Align(
                alignment: Alignment.centerLeft,
                child: Text("ZONA DE PELIGRO",
                    style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2))),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.3))),
              child: ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text("Restablecer Datos de Fábrica",
                    style: TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold)),
                subtitle: Text("Borrar transacciones, cuentas y reiniciar app.",
                    style: TextStyle(color: Colors.red[300], fontSize: 11)),
                onTap: () => _confirmReset(context),
              ),
            ),

            const SizedBox(height: 40),
            Text("Versión de App 1.0.0",
                style: TextStyle(color: subTextColor, fontSize: 12)),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
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
                    color: Colors.black.withValues(alpha: 0.05),
                    offset: const Offset(0, 4),
                    blurRadius: 10,
                  )
                ]),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeThumbColor: Colors.cyan,
        title: Text(title, style: TextStyle(color: textColor, fontSize: 14)),
        secondary:
            Icon(icon, color: isDarkMode ? Colors.grey : Colors.grey[600]),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context) {
    final uiProvider = Provider.of<UiProvider>(context, listen: false);
    final isDarkMode = uiProvider.isDarkMode;
    final backgroundColor = isDarkMode ? const Color(0xFF1E2730) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final hintColor = isDarkMode ? Colors.grey : Colors.grey[600];

    final controller = TextEditingController(text: uiProvider.userName);

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
                uiProvider.setUserName(controller.text.trim());
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
    final uiProvider = Provider.of<UiProvider>(context, listen: false);
    final isDarkMode = uiProvider.isDarkMode;
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

  void _exportData(BuildContext context) async {
    final provider = Provider.of<TransactionProvider>(context, listen: false);
    final transactions = provider.transactions;

    // Build CSV
    StringBuffer buffer = StringBuffer();
    buffer.writeln("Fecha,Tipo,Monto,Concepto,Nota");
    for (var t in transactions) {
      buffer.writeln(
          "${t.date.toIso8601String()},${t.type},${t.amount},${t.description},${t.note ?? ''}");
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString()));

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.tealAccent, size: 20),
            SizedBox(width: 8),
            Expanded(
                child: Text("¡Reporte Generado! Copiado al portapapeles. 📋")),
          ],
        ),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showEditBudgetDialog(BuildContext context) {
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    final uiProvider = Provider.of<UiProvider>(context, listen: false);
    final isDarkMode = uiProvider.isDarkMode;
    final backgroundColor = isDarkMode ? const Color(0xFF1E2730) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final hintColor = isDarkMode ? Colors.grey : Colors.grey[600];

    final TextEditingController controller = TextEditingController(
      text: walletProvider.budgetLimit.toString(),
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: backgroundColor,
          title:
              Text("Editar Límite Mensual", style: TextStyle(color: textColor)),
          content: SingleChildScrollView(
            child: TextField(
              controller: controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                prefixText: '${walletProvider.currencySymbol} ',
                prefixStyle: const TextStyle(color: Colors.cyan),
                enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                        color:
                            isDarkMode ? Colors.grey : Colors.grey.shade400)),
                focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.cyan)),
              ),
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
                  walletProvider.setBudgetLimit(newLimit);
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

  void _showAvatarSelectionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        final uiProvider = Provider.of<UiProvider>(context, listen: false);
        return Container(
          padding: const EdgeInsets.all(30),
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text("Elige tu avatar",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 30),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 4,
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 20,
                  children: [
                    '😎',
                    '🦸',
                    '🕵️',
                    '🤖',
                    '🦁',
                    '👽',
                    '🦊',
                    '🐱',
                    '🐼',
                    '🐨',
                    '🐯',
                    '🐮',
                    '🐷',
                    '🐸',
                    '🦄',
                    '🐲',
                    '👻',
                    '💀',
                    '👾',
                    '🧘',
                    '🚵',
                    '🤸',
                    '🧖',
                    '🧟',
                    '🧛',
                    '🧝',
                    '🧞',
                    '🧜',
                    '⚽',
                    '🏀',
                    '🎮',
                    '🎵',
                    '🎨',
                    '📷'
                  ]
                      .map((emoji) => GestureDetector(
                            onTap: () {
                              uiProvider
                                  .setUserAvatar(emoji); // Update immediately
                              Navigator.pop(context);
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(emoji,
                                  style: const TextStyle(fontSize: 32)),
                            ),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _pickImage(context, ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text("Cámara"),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: const Color(0xFF00E5FF),
                          side: const BorderSide(
                              color: Color(0xFF00E5FF), width: 1),
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 0),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _pickImage(context, ImageSource.gallery),
                      icon: const Icon(Icons.photo_library),
                      label: const Text("Galería"),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: const Color(0xFF00E5FF),
                          side: const BorderSide(
                              color: Color(0xFF00E5FF), width: 1),
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 0),
                    ),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    final uiProvider = Provider.of<UiProvider>(context, listen: false);
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 60,
      );

      if (pickedFile != null) {
        final directory = await getApplicationDocumentsDirectory();
        final String fileName =
            'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final String savedPath = path.join(directory.path, fileName);
        await File(pickedFile.path).copy(savedPath);

        // Update via Provider
        if (context.mounted) {
          await uiProvider.setProfileImagePath(savedPath);
          if (!context.mounted) return;
          Navigator.pop(context); // Close Sheet
        }
      }
    } catch (e) {
      debugPrint("Image Pick Error: $e");
    }
  }

  void _confirmReset(BuildContext context) {
    final uiProvider = Provider.of<UiProvider>(context, listen: false);
    final isDarkMode = uiProvider.isDarkMode;
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

              // Clear All Data via Preferences and Database
              await sl.sl<PreferencesLocalDataSource>().clearAllPreferences();
              await sl.sl<LocalDatabase>().clearAllTables();

              // Refresh Providers to clear UI state
              if (context.mounted) {
                Provider.of<WalletProvider>(context, listen: false)
                    .refreshData();
                Provider.of<TransactionProvider>(context, listen: false)
                    .refreshData();
              }

              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const OnboardingPage()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text("BORRAR TODO",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showCreateBackupDialog(BuildContext context) {
    final uiProvider = Provider.of<UiProvider>(context, listen: false);
    final isDarkMode = uiProvider.isDarkMode;
    final backgroundColor = isDarkMode ? const Color(0xFF1E2730) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;

    final passController = TextEditingController();
    final confirmController = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          final passwordsMatch = passController.text == confirmController.text;
          final isNotEmpty = passController.text.isNotEmpty;
          final canSave = passwordsMatch && isNotEmpty && !isSaving;

          return AlertDialog(
            backgroundColor: backgroundColor,
            title: Text("Contraseña de Copia", style: TextStyle(color: textColor)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: passController,
                  obscureText: true,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    labelText: "Contraseña",
                    labelStyle: TextStyle(color: isDarkMode ? Colors.grey : Colors.grey[600]),
                  ),
                  onChanged: (val) => setState(() {}),
                ),
                TextField(
                  controller: confirmController,
                  obscureText: true,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    labelText: "Confirmar Contraseña",
                    labelStyle: TextStyle(color: isDarkMode ? Colors.grey : Colors.grey[600]),
                    errorText: (isNotEmpty && !passwordsMatch) ? "Las contraseñas no coinciden" : null,
                  ),
                  onChanged: (val) => setState(() {}),
                ),
                if (isSaving) const Padding(padding: EdgeInsets.only(top: 20), child: const CircularProgressIndicator()),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: Text("Cancelar", style: TextStyle(color: isDarkMode ? Colors.grey : Colors.grey[600])),
              ),
              ElevatedButton(
                onPressed: canSave ? () async {
                  setState(() => isSaving = true);
                  final createUseCase = sl.sl<CreateBackupUseCase>();
                  final result = await createUseCase(CreateBackupParams(password: passController.text));

                  if (!context.mounted) return;
                  Navigator.pop(ctx);

                  result.fold(
                    (failure) {
                      String msg = "Error al crear la copia.";
                      if (failure.message.contains("BackupTooLargeException")) {
                        msg = "La copia de seguridad supera el tamaño compatible con esta versión.";
                      }
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                    },
                    (backupResult) async {
                      if (backupResult.transactionAttachmentsMissing > 0) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Copia creada, pero ${backupResult.transactionAttachmentsMissing} recibos no pudieron incluirse.")));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copia de seguridad creada correctamente.")));
                      }

                      try {
                        final box = context.findRenderObject() as RenderBox?;
                        await Share.shareXFiles(
                          [XFile(backupResult.backupFilePath)],
                          text: 'Mi copia de seguridad de Gestor Gastos',
                          sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
                        );
                      } catch (e) {
                        debugPrint("Error sharing: \$e");
                      }
                    }
                  );
                } : null,
                child: const Text("Aceptar"),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _restoreBackup(BuildContext context) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['gestorbackup'],
    );

    if (result == null || result.files.isEmpty) return;
    final filePath = result.files.single.path;
    if (filePath == null) return;

    if (!context.mounted) return;

    _showRestorePasswordDialog(context, filePath);
  }

  void _showRestorePasswordDialog(BuildContext context, String filePath) {
    final uiProvider = Provider.of<UiProvider>(context, listen: false);
    final isDarkMode = uiProvider.isDarkMode;
    final backgroundColor = isDarkMode ? const Color(0xFF1E2730) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;

    final passController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: backgroundColor,
        title: Text("Contraseña de Copia", style: TextStyle(color: textColor)),
        content: TextField(
          controller: passController,
          obscureText: true,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            labelText: "Contraseña",
            labelStyle: TextStyle(color: isDarkMode ? Colors.grey : Colors.grey[600]),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancelar", style: TextStyle(color: isDarkMode ? Colors.grey : Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              final password = passController.text;
              if (password.isNotEmpty) {
                Navigator.pop(ctx);
                _showDestructiveWarningDialog(context, filePath, password);
              }
            },
            child: const Text("Aceptar"),
          ),
        ],
      ),
    );
  }

  void _showDestructiveWarningDialog(BuildContext context, String filePath, String password) {
    final uiProvider = Provider.of<UiProvider>(context, listen: false);
    final isDarkMode = uiProvider.isDarkMode;
    final backgroundColor = isDarkMode ? const Color(0xFF1E2730) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    bool isRestoring = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: backgroundColor,
            title: Text("Advertencia destructiva", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Restaurar una copia de seguridad sobrescribirá todos tus datos actuales. Esta acción no se puede deshacer.",
                  style: TextStyle(color: textColor),
                ),
                if (isRestoring) const Padding(padding: EdgeInsets.only(top: 20), child: const CircularProgressIndicator()),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isRestoring ? null : () => Navigator.pop(ctx),
                child: Text("Cancelar", style: TextStyle(color: isDarkMode ? Colors.grey : Colors.grey[600])),
              ),
              ElevatedButton(
                onPressed: isRestoring ? null : () async {
                  setState(() => isRestoring = true);
                  final restoreUseCase = sl.sl<RestoreBackupUseCase>();
                  final result = await restoreUseCase(filePath, password);

                  if (!context.mounted) return;
                  Navigator.pop(ctx); // Cierra advertencia

                  result.fold(
                    (failure) {
                      String msg = "Error al restaurar la copia.";
                      if (failure.message.contains("RollbackFailedException")) {
                        msg = "ERROR CRÍTICO: Fallo al restaurar y fallo al recuperar. La app podría estar inconsistente.";
                      } else if (failure.message.contains("RestoreFailedException")) {
                        msg = "No se pudo completar la restauración. Se ha vuelto a la versión anterior.";
                      }
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                    },
                    (restoreResult) {
                      if (restoreResult.warnings.isNotEmpty || restoreResult.attachmentsMissing > 0) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Restaurado con advertencias (adjuntos faltantes).")));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copia restaurada exitosamente.")));
                      }
                      // Recargar la app
                      Provider.of<WalletProvider>(context, listen: false).refreshData();
                      Provider.of<TransactionProvider>(context, listen: false).refreshData();
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => const OnboardingPage()),
                        (route) => false,
                      );
                    }
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                child: const Text("Sí, restaurar", style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        }
      ),
    );
  }
}
