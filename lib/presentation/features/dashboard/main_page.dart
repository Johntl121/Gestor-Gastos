import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/entities/transaction_entity.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/gemini_client.dart';
import '../../../core/services/speech_service.dart';

// Providers
import '../../providers/ui_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/transaction_provider.dart';

// Pages
import 'home_page.dart';
import '../stats/stats_page.dart';
import '../transactions/history_page.dart';
import '../wallet/wallet_page.dart';
import '../transactions/add_transaction_page.dart';
import '../../../core/constants/app_categories.dart';
import '../../../core/constants/app_strings.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final SpeechService _speechService = SpeechService();

  void _initializeStartupConfig() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 1. Cargamos configuración básica del UI y Wallet (Cuentas, Balance)
      final walletProvider =
          Provider.of<WalletProvider>(context, listen: false);
      await walletProvider.initApp();

      if (!mounted) return;

      // 2. Cargamos transacciones (esto disparará el ProxyProvider hacia StatsProvider)
      final transactionProvider =
          Provider.of<TransactionProvider>(context, listen: false);
      try {
        await transactionProvider.loadTransactions();
      } catch (e) {
        debugPrint("Transaction load error: $e");
      }

      if (!mounted) return;

      // 3. Solicitamos permisos de notificaciones (Ahora no bloquea el inicio)
      // Lo hacemos al final para asegurar que la UI ya es interactiva
      await NotificationService().requestPermissions();
    });
  }

  late final List<Widget> _pages;
  late final TransactionProvider _transactionProvider;
  late final WalletProvider _walletProvider;

  @override
  void initState() {
    super.initState();
    _pages = [
      HomePage(onSeeAllPressed: () => _onItemTapped(2)),
      const StatsPage(),
      const HistoryPage(),
      const WalletPage(),
    ];
    _initializeStartupConfig();

    _transactionProvider =
        Provider.of<TransactionProvider>(context, listen: false);
    _walletProvider = Provider.of<WalletProvider>(context, listen: false);

    _transactionProvider.addListener(_onTransactionErrorChanged);
    _walletProvider.addListener(_onWalletErrorChanged);
  }

  @override
  void dispose() {
    _transactionProvider.removeListener(_onTransactionErrorChanged);
    _walletProvider.removeListener(_onWalletErrorChanged);
    super.dispose();
  }

  void _onTransactionErrorChanged() {
    if (_transactionProvider.errorMessage != null) {
      final msg = _transactionProvider.errorMessage!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg, style: const TextStyle(color: Colors.white)),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
          _transactionProvider.clearError();
        }
      });
    }
  }

  void _onWalletErrorChanged() {
    if (_walletProvider.errorMessage != null) {
      final msg = _walletProvider.errorMessage!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg, style: const TextStyle(color: Colors.white)),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
          _walletProvider.clearError();
        }
      });
    }
  }

  void _onItemTapped(int index) {
    Provider.of<UiProvider>(context, listen: false).setIndex(index);
  }

  // --- Voice Logic ---

  void _startVoiceTransaction(BuildContext context) {
    String currentText = "";
    bool hasAttemptedStart = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            if (!hasAttemptedStart) {
              hasAttemptedStart = true;

              _speechService.onStatusCallback = (status) {
                if (status == 'done' || status == 'notListening') {
                  if (context.mounted) {
                    setSheetState(() {});
                  }
                }
              };

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!_speechService.isListening) {
                  _speechService.listen(
                    (text) {
                      setSheetState(() => currentText = text);
                    },
                  );
                  setSheetState(() {});
                }
              });
            }

            return Container(
              height: 350,
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E2C),
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black45, blurRadius: 10, spreadRadius: 2)
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey[700],
                        borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 30),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _speechService.isListening
                          ? Colors.redAccent.withValues(alpha: 0.3)
                          : Colors.redAccent.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      boxShadow: _speechService.isListening
                          ? [
                              BoxShadow(
                                color: Colors.redAccent.withValues(alpha: 0.5),
                                blurRadius: 20,
                                spreadRadius: 5,
                              )
                            ]
                          : [],
                    ),
                    child: const Icon(Icons.mic,
                        size: 40, color: Colors.redAccent),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _speechService.isListening
                        ? "¡Habla ahora!"
                        : (currentText.isNotEmpty
                            ? "Revisa tu frase"
                            : "Te escucho..."),
                    style: TextStyle(
                      color:
                          _speechService.isListening || currentText.isNotEmpty
                              ? Colors.redAccent
                              : Colors.grey,
                      fontSize: _speechService.isListening ? 18 : 16,
                      fontWeight:
                          _speechService.isListening || currentText.isNotEmpty
                              ? FontWeight.bold
                              : FontWeight.normal,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Center(
                      child: SizedBox(
                        height: 120,
                        child: SingleChildScrollView(
                          child: Text(
                            currentText.isEmpty
                                ? "Ej: Gaste 20 soles en taxi"
                                : currentText,
                            textAlign: TextAlign.center,
                            maxLines: null,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: currentText.isEmpty
                                  ? Colors.grey[600]
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (!_speechService.isListening &&
                          currentText.isNotEmpty) ...[
                        TextButton.icon(
                          onPressed: () async {
                            await _speechService.stop();
                            setSheetState(() => currentText = "");
                            _speechService.listen((text) {
                              setSheetState(() => currentText = text);
                            });
                            setSheetState(() {});
                          },
                          icon: const Icon(Icons.refresh,
                              color: Colors.cyanAccent),
                          label: const Text("Volver a hablar",
                              style: TextStyle(color: Colors.cyanAccent)),
                        ),
                        const SizedBox(width: 15),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.tealAccent,
                            foregroundColor: Colors.black87,
                            elevation: 0,
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            _processVoiceCommand(currentText);
                          },
                          icon: const Icon(Icons.auto_awesome, size: 20),
                          label: const Text("✨ Analizar con IA",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ] else if (!_speechService.isListening &&
                          currentText.isEmpty) ...[
                        TextButton.icon(
                          onPressed: () async {
                            await _speechService.stop();
                            setSheetState(() => currentText = "");
                            _speechService.listen((text) {
                              setSheetState(() => currentText = text);
                            });
                            setSheetState(() {});
                          },
                          icon: const Icon(Icons.mic, color: Colors.cyanAccent),
                          label: const Text("Volver a intentar",
                              style: TextStyle(color: Colors.cyanAccent)),
                        ),
                      ] else ...[
                        GestureDetector(
                          onTap: () async {
                            await _speechService.stop();
                            setSheetState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                    color:
                                        Colors.redAccent.withValues(alpha: 0.4),
                                    blurRadius: 10)
                              ],
                            ),
                            child: const Icon(Icons.stop,
                                color: Colors.white, size: 30),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      _speechService.onStatusCallback = null;
      _speechService.stop();
    });
  }

  Future<void> _processVoiceCommand(String text) async {
    if (text.isEmpty) return;

    // Use WalletProvider to access accounts for context
    final walletProvider = Provider.of<WalletProvider>(context, listen: false);

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(
              child: Card(
                  color: Color(0xFF1E293B),
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.tealAccent),
                        SizedBox(height: 15),
                        Text("Analizando con IA... 🧠",
                            style: TextStyle(color: Colors.white))
                      ],
                    ),
                  )),
            ));

    final categories = AppCategories.allCategories.values
        .map((cat) => cat['name'] as String)
        .toList();

    final accountNames = walletProvider.accounts.map((a) => a.name).toList();

    final result =
        await GeminiClient().analyzeTransaction(text, categories, accountNames);

    if (!mounted) return;
    Navigator.pop(context);

    if (result != null) {
      final double amount = (result['monto'] is int)
          ? (result['monto'] as int).toDouble()
          : (result['monto'] as double? ?? 0.0);

      final String categoryName = result['categoria'] ?? "Otros";
      final String description = result['descripcion'] ?? categoryName;
      final String typeStr = result['tipo'] ?? "gasto";
      final String? detectedAccount = result['cuenta_origen_detectada'];

      TransactionType type = TransactionType.expense;
      if (typeStr == "ingreso") type = TransactionType.income;
      if (typeStr == "transferencia") type = TransactionType.transfer;

      int categoryId =
          type == TransactionType.income ? 25 : 20; // Default Otros
      final String normalizedCategory = categoryName.trim().toLowerCase();

      for (var entry in AppCategories.allCategories.entries) {
        final catName = (entry.value['name'] as String).toLowerCase();
        if (catName == normalizedCategory ||
            (normalizedCategory == "hogar" && catName == "vivienda") ||
            (normalizedCategory == "ocio" && catName == "entretenimiento") ||
            (normalizedCategory == "gastos varios" && catName == "otros")) {
          categoryId = entry.key;
          break;
        }
      }

      int accountId = walletProvider.accounts.isNotEmpty
          ? walletProvider.accounts.first.id
          : 1;

      if (detectedAccount != null) {
        try {
          final nom = detectedAccount.trim().toLowerCase();
          final match = walletProvider.accounts
              .firstWhere((acc) => acc.name.toLowerCase().trim() == nom);
          accountId = match.id;
        } catch (e) {
          debugPrint(
              "VoiceAI: Cuenta '$detectedAccount' no encontrada con certeza abs. Usando cuenta predeterminada.");
        }
      }

      final draft = TransactionEntity(
        accountId: accountId,
        categoryId: categoryId,
        amount: type == TransactionType.expense ? -amount.abs() : amount.abs(),
        date: DateTime.now(),
        description: categoryName,
        note: description.isNotEmpty && description != categoryName
            ? description
            : "Voz: $text",
        type: type,
        destinationAccountId: null,
      );

      showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.tealAccent),
                SizedBox(width: 10),
                Expanded(
                    child: Text("Resumen de Transacción",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold))),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: [
                      // Tipo
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Tipo:",
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 14)),
                          Text(
                              type == TransactionType.income
                                  ? "Ingreso"
                                  : (type == TransactionType.transfer
                                      ? "Transferencia"
                                      : "Gasto"),
                              style: TextStyle(
                                  color: type == TransactionType.income
                                      ? Colors.greenAccent
                                      : (type == TransactionType.transfer
                                          ? Colors.blueAccent
                                          : Colors.redAccent),
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Monto
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Monto:",
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 14)),
                          Text(
                              CurrencyFormatter.format(
                                  amount,
                                  walletProvider.accounts
                                      .firstWhere((a) => a.id == accountId,
                                          orElse: () =>
                                              walletProvider.accounts.first)
                                      .currencySymbol),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                              type == TransactionType.transfer
                                  ? "Origen:"
                                  : "Cuenta:",
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 14)),
                          Text(
                              detectedAccount ??
                                  walletProvider.accounts.first.name,
                              style: const TextStyle(
                                  color: Colors.blueAccent, fontSize: 15)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                              type == TransactionType.transfer
                                  ? "Destino:"
                                  : "Categoría:",
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 14)),
                          Text(categoryName,
                              style: const TextStyle(
                                  color: Colors.orangeAccent, fontSize: 15)),
                        ],
                      ),
                      const Divider(color: Colors.white12, height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Descripción:",
                              style:
                                  TextStyle(color: Colors.grey, fontSize: 14)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(description,
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 14),
                                maxLines: 5,
                                overflow: TextOverflow.visible),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actionsPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            actionsAlignment: MainAxisAlignment.spaceBetween,
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            AddTransactionPage(draftTransaction: draft)),
                  );
                },
                child: const Text("Editar detalles",
                    style: TextStyle(color: Colors.cyan)),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.tealAccent,
                  foregroundColor: Colors.black87,
                  elevation: 0,
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  final transactionProvider =
                      Provider.of<TransactionProvider>(context, listen: false);
                  final walletProvider =
                      Provider.of<WalletProvider>(context, listen: false);

                  await transactionProvider.addTransaction(draft);

                  // Sincronizar saldos en WalletProvider
                  if (mounted) {
                    await walletProvider.loadWalletData();
                  }

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content:
                              Text("Transacción guardada exitosamente 🚀")),
                    );
                  }
                },
                child: const Text("Guardar",
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No pude entender la transacción 😕")));
    }
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    final uiProvider = Provider.of<UiProvider>(context);
    final isDarkMode = uiProvider.isDarkMode;
    final currentIndex = uiProvider.currentIndex;
    const barColor = Color(0xFF1F2937);
    const activeColor = Colors.cyanAccent;
    const inactiveColor = Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF15202B) : Colors.grey[100],
      bottomNavigationBar: SafeArea(
        child: Container(
          height: 65,
          color: barColor,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Inicio
              _buildNavItem(
                icon: currentIndex == 0
                    ? Icons.home_rounded
                    : Icons.home_outlined,
                label: AppStrings.navHome,
                isActive: currentIndex == 0,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                onTap: () => _onItemTapped(0),
              ),
              // Estadísticas
              _buildNavItem(
                icon: currentIndex == 1
                    ? Icons.bar_chart_rounded
                    : Icons.bar_chart_outlined,
                label: 'Stats',
                isActive: currentIndex == 1,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                onTap: () => _onItemTapped(1),
              ),
              // Botón central "Añadir"
              GestureDetector(
                onTap: () => _showAddBottomSheet(context),
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Colors.cyan, Colors.blueAccent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.cyan.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.add_rounded,
                      color: Colors.white, size: 28),
                ),
              ),
              // Historial
              _buildNavItem(
                icon: currentIndex == 2
                    ? Icons.history_rounded
                    : Icons.history_outlined,
                label: AppStrings.navHistory,
                isActive: currentIndex == 2,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                onTap: () => _onItemTapped(2),
              ),
              // Billetera
              _buildNavItem(
                icon: currentIndex == 3
                    ? Icons.account_balance_wallet_rounded
                    : Icons.account_balance_wallet_outlined,
                label: 'Billetera',
                isActive: currentIndex == 3,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                onTap: () => _onItemTapped(3),
              ),
            ],
          ),
        ),
      ),
      body: IndexedStack(
        index: currentIndex,
        children: _pages,
      ),
    );
  }

  /// Barra inferior: ítem de navegación individual
  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required Color activeColor,
    required Color inactiveColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isActive ? activeColor : inactiveColor, size: 26),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: isActive ? activeColor : inactiveColor,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// BottomSheet premium con las opciones de nueva transacción
  void _showAddBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E293B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Nueva Transacción',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            // Opción Manual
            _buildSheetOption(
              ctx: ctx,
              icon: Icons.edit_note_rounded,
              iconColor: Colors.cyanAccent,
              title: 'Registro Manual',
              subtitle: 'Ingresa los detalles de tu transacción',
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddTransactionPage()),
                );
              },
            ),
            const SizedBox(height: 12),
            // Opción Voz
            _buildSheetOption(
              ctx: ctx,
              icon: Icons.mic_rounded,
              iconColor: Colors.tealAccent,
              title: 'Por Voz con IA',
              subtitle: 'Habla y la IA registrará tu gasto',
              onTap: () {
                Navigator.pop(ctx);
                _startVoiceTransaction(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetOption({
    required BuildContext ctx,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: Colors.white38, size: 20),
          ],
        ),
      ),
    );
  }
}
