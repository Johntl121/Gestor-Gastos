import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../core/services/ai_service.dart';
import '../providers/dashboard_provider.dart';
import 'home_page.dart';
import '../../core/services/speech_service.dart';
import 'add_transaction_page.dart';
import 'stats_page.dart';
import 'history_page.dart';
import 'wallet_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;
  bool _isSpeedDialOpen = false;
  final SpeechService _speechService = SpeechService();

  List<Widget> get _pages => [
        HomePage(onSeeAllPressed: () => _onItemTapped(2)),
        const StatsPage(),
        const HistoryPage(),
        const WalletPage(),
      ];

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  // --- Voice Logic ---

  void _startVoiceTransaction(BuildContext context) {
    // Variable local para actualizar la UI del sheet sin reconstruir toda la página
    String currentText = "";
    // Estado para animación simple (opcional)
    bool isListening = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // Para ver bordes redondeados
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            // Iniciamos la escucha solo si es la primera vez (hack simple)
            // Idealmente esto se maneja fuera, pero para este fix rápido:
            if (isListening && !_speechService.isListening) {
              _speechService.listen(
                (text) {
                  setSheetState(() => currentText = text);
                },
              );
            }

            return Container(
              height: 350, // Altura fija cómoda
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E2C), // Tu color de fondo oscuro
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
                  // 1. Barra superior pequeña (drag handle)
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey[700],
                        borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 30),
                  // 2. Icono Animado (Simulado)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mic,
                        size: 40, color: Colors.redAccent),
                  ),
                  const SizedBox(height: 20),
                  // 3. Título de Estado
                  const Text(
                    "Te escucho...",
                    style: TextStyle(
                        color: Colors.grey, fontSize: 14, letterSpacing: 1),
                  ),
                  const SizedBox(height: 10),
                  // 4. EL TEXTO IMPORTANTE (Sin duplicados)
                  Expanded(
                    child: Center(
                      child: Text(
                        currentText.isEmpty
                            ? "Ej: Gaste 20 soles en taxi"
                            : currentText,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: currentText.isEmpty ? 22 : 28,
                          fontWeight: FontWeight.bold,
                          color: currentText.isEmpty
                              ? Colors.grey[600]
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                  // 5. Botón de Detener (Más elegante)
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () {
                      _speechService.stop();
                      Navigator.pop(context); // Cierra el sheet
                      if (currentText.isNotEmpty) {
                        _processVoiceCommand(currentText);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.redAccent.withOpacity(0.4),
                              blurRadius: 10)
                        ],
                      ),
                      child:
                          const Icon(Icons.stop, color: Colors.white, size: 30),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      // Asegurar que se detenga si el usuario cierra deslizando
      _speechService.stop();
    });
  }

  Future<void> _processVoiceCommand(String text) async {
    if (text.isEmpty) return;

    // Show Loading
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

    // Available Lists (Hardcoded or from Provider)
    final categories = [
      "Comida",
      "Transporte",
      "Compras",
      "Ocio",
      "Salud",
      "Hogar",
      "Educación",
      "Otros",
      "Ingreso",
      "Transferencia"
    ];
    final accounts = ["Efectivo", "Banco", "Ahorros"];

    // AI Analysis
    final result =
        await AIService().analyzeTransaction(text, categories, accounts);

    // Close Loading
    Navigator.pop(context);

    if (result != null) {
      // Parse Result
      final double amount = (result['amount'] is int)
          ? (result['amount'] as int).toDouble()
          : (result['amount'] as double? ?? 0.0);

      final String categoryName = result['category'] ?? "Otros";
      final String accountName = result['account'] ?? "Efectivo";
      final String title = result['title'] ?? categoryName;
      final String typeStr = result['type'] ?? "expense";

      TransactionType type = TransactionType.expense;
      if (typeStr == "income") type = TransactionType.income;
      if (typeStr == "transfer") type = TransactionType.transfer;

      // Map IDs (simple mapping)
      int categoryId = 11; // Otros
      if (categoryName == "Comida") categoryId = 1;
      if (categoryName == "Transporte") categoryId = 2;
      if (categoryName == "Compras") categoryId = 3;
      if (categoryName == "Ocio") categoryId = 4;
      if (categoryName == "Salud") categoryId = 5;
      if (categoryName == "Hogar") categoryId = 6;
      if (categoryName == "Educación") categoryId = 7;

      int accountId = 1; // Efectivo
      if (accountName == "Banco") accountId = 2;
      if (accountName == "Ahorros") accountId = 3;

      // Create Draft
      final draft = TransactionEntity(
        accountId: accountId,
        categoryId: categoryId,
        amount: type == TransactionType.expense ? -amount.abs() : amount.abs(),
        date: DateTime.now(),
        description: title,
        note: "IA: $text", // Keep original text as note or metadata
        type: type,
      );

      // Navigate to Edit Page (AddTransactionPage)
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => AddTransactionPage(draftTransaction: draft)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No pude entender la transacción 😕")),
      );
    }
  }

  // ignore: unused_element
  void _showConfirmationDialog(TransactionEntity initialDraft) {
    // We create a mutable copy of the draft properties needed for edition in dialog
    TransactionEntity draft = initialDraft;
    int selectedAccountId = draft.accountId;

    final isExpense = draft.type == TransactionType.expense;
    final color = isExpense
        ? Colors.redAccent
        : (draft.type == TransactionType.income
            ? Colors.greenAccent
            : Colors.white70);

    showDialog(
      context: context,
      builder: (context) {
        bool isAccountSelectorExpanded = false;

        return StatefulBuilder(
          builder: (context, setState) {
            // Helper for Header Data
            IconData currentIcon = Icons.payments;
            Color currentColor = Colors.amber;
            String currentName = "Efectivo";
            if (selectedAccountId == 2) {
              currentIcon = Icons.credit_card;
              currentColor = Colors.blueAccent;
              currentName = "Banco";
            } else if (selectedAccountId == 3) {
              currentIcon = Icons.savings;
              currentColor = Colors.purpleAccent;
              currentName = "Ahorros";
            }

            // Helper Widget Builder for Options
            Widget buildOption(int id, String name, IconData icon, Color c) {
              final isSelected = selectedAccountId == id;
              return InkWell(
                onTap: () {
                  setState(() {
                    selectedAccountId = id;
                    isAccountSelectorExpanded = false;
                    // Update Draft
                    draft = TransactionEntity(
                        id: draft.id,
                        accountId: selectedAccountId,
                        categoryId: draft.categoryId,
                        amount: draft.amount,
                        date: draft.date,
                        description: draft.description,
                        note: draft.note,
                        type: draft.type,
                        destinationAccountId: draft.destinationAccountId);
                  });
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: isSelected
                      ? Colors.white.withOpacity(0.05)
                      : Colors.transparent,
                  child: Row(
                    children: [
                      Icon(icon, color: c, size: 20),
                      const SizedBox(width: 12),
                      Text(name,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 15)),
                      const Spacer(),
                      if (isSelected) Icon(Icons.check, color: color, size: 18)
                    ],
                  ),
                ),
              );
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF1E2A32),
              title: Row(
                children: [
                  Icon(
                      draft.type == TransactionType.transfer
                          ? Icons.swap_horiz
                          : (isExpense
                              ? Icons.arrow_downward
                              : Icons.arrow_upward),
                      color: color),
                  const SizedBox(width: 8),
                  Text(
                    draft.type == TransactionType.transfer
                        ? 'Transferencia'
                        : (isExpense ? 'Gasto Detectado' : 'Ingreso Detectado'),
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Consumer<DashboardProvider>(
                        builder: (context, provider, _) {
                          return Text(
                              "${provider.currencySymbol} ${draft.amount.abs().toStringAsFixed(2)}",
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold));
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text("Cuenta:", style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 5),

                    // EXPANDABLE ACCOUNT SELECTOR (INLINE)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      decoration: BoxDecoration(
                        color: Colors.grey[850], // Darker background
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // HEADER (Always Visible)
                          InkWell(
                            onTap: () {
                              setState(() {
                                isAccountSelectorExpanded =
                                    !isAccountSelectorExpanded;
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              child: Row(
                                children: [
                                  Icon(currentIcon,
                                      color: currentColor, size: 24),
                                  const SizedBox(width: 12),
                                  Text(currentName,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600)),
                                  const Spacer(),
                                  AnimatedRotation(
                                    turns:
                                        isAccountSelectorExpanded ? 0.5 : 0.0,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                    child: const Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        color: Colors.grey),
                                  )
                                ],
                              ),
                            ),
                          ),

                          // EXPANDABLE BODY
                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            alignment: Alignment.topCenter,
                            child: isAccountSelectorExpanded
                                ? Column(
                                    children: [
                                      const Divider(
                                          height: 1,
                                          thickness: 1,
                                          color: Colors.white10),
                                      buildOption(1, "Efectivo", Icons.payments,
                                          Colors.amber),
                                      buildOption(2, "Banco", Icons.credit_card,
                                          Colors.blue),
                                      buildOption(3, "Ahorros", Icons.savings,
                                          Colors.purpleAccent),
                                    ],
                                  )
                                : const SizedBox(width: double.infinity),
                          )
                        ],
                      ),
                    ),

                    const SizedBox(height: 15),
                    Text("Nota: ${draft.note}",
                        style: TextStyle(
                            color: Colors.grey[400],
                            fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Editar Manualmente'),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              AddTransactionPage(draftTransaction: draft)),
                    );
                  },
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: color),
                  child: const Text('✅ Confirmar',
                      style: TextStyle(color: Colors.white)),
                  onPressed: () {
                    Navigator.pop(context);
                    _saveQuickTransaction(draft);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _saveQuickTransaction(TransactionEntity draft) {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    if (draft.type == TransactionType.transfer) {
      provider.addTransfer(
        amount: draft.amount.abs(),
        sourceAccountId: 1, // Default Source
        destinationAccountId: 2, // Default Dest
        note: draft.note,
      );
    } else {
      provider.addTransaction(draft);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Transacción guardada exitosamente'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    final isDarkMode =
        Provider.of<DashboardProvider>(context, listen: false).isDarkMode;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF15202B) : Colors.grey[100],
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Page Content
          _pages[_currentIndex],

          // 2. Backdrop (Dims only when Speed Dial is open)
          if (_isSpeedDialOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _isSpeedDialOpen = false),
                child: Container(
                  color: Colors.black.withOpacity(0.6),
                ),
              ),
            ),

          // 3. Custom Floating Navigation Dock
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                color: const Color(0xFF1F2937), // Dark control center
                borderRadius: BorderRadius.circular(35),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 15,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildDockItem(Icons.home_rounded, 0),
                  _buildDockItem(Icons.bar_chart_rounded, 1),
                  const SizedBox(width: 60), // Space for FAB
                  _buildDockItem(Icons.history_rounded, 2),
                  _buildDockItem(Icons.account_balance_wallet_rounded, 3),
                ],
              ),
            ),
          ),

          // 4. Speed Dial Options
          if (_isSpeedDialOpen)
            Positioned(
              bottom: 110,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Voice Option
                  _buildSpeedDialOption(
                    icon: Icons.mic_rounded,
                    label: "Por Voz",
                    color: Colors.tealAccent,
                    onTap: () {
                      setState(() => _isSpeedDialOpen = false);
                      _startVoiceTransaction(context);
                    },
                  ),
                  const SizedBox(height: 16),
                  // Manual Option
                  _buildSpeedDialOption(
                    icon: Icons.edit_note_rounded,
                    label: "Manual",
                    color: Colors.cyanAccent,
                    onTap: () {
                      setState(() => _isSpeedDialOpen = false);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const AddTransactionPage()),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),

          // 5. Main "Super FAB"
          Positioned(
            bottom: 25, // Lowered for better alignment
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isSpeedDialOpen = !_isSpeedDialOpen;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 64,
                  width: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: _isSpeedDialOpen
                          ? [Colors.redAccent, Colors.red]
                          : [Colors.cyan, Colors.blueAccent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _isSpeedDialOpen
                            ? Colors.redAccent.withOpacity(0.3)
                            : Colors.cyan.withOpacity(0.3), // Reduced opacity
                        blurRadius: 15, // Softer blur
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: AnimatedRotation(
                    turns: _isSpeedDialOpen ? 0.125 : 0, // 45 degrees
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.add_rounded,
                        color: Colors.white, size: 36),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedDialOption(
      {required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onTap}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
            ],
          ),
          child: Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.black87)),
        ),
        const SizedBox(width: 12),
        // Mini FAB
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 50,
            width: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(
                    color: color.withOpacity(0.5),
                    blurRadius: 8,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Icon(icon, color: Colors.black87, size: 24),
          ),
        ),
      ],
    );
  }

  Widget _buildDockItem(IconData icon, int index) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected
              ? Colors.cyanAccent.withOpacity(0.1)
              : Colors.transparent,
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.cyanAccent : Colors.grey,
          size: 28,
          shadows: isSelected
              ? [
                  BoxShadow(
                      color: Colors.cyanAccent.withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 1)
                ]
              : null,
        ),
      ),
    );
  }
}
