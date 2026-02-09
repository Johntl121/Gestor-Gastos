import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/transaction_entity.dart';
import '../providers/dashboard_provider.dart';
import 'home_page.dart';
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

  void _showVoiceSimulator() {
    final TextEditingController voiceController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2A32),
        title: const Text('Simulador de Voz',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: voiceController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Ej: "Gaste 45 en pizza"',
            hintStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.tealAccent)),
          ),
          autofocus: true,
          onSubmitted: (val) {
            Navigator.pop(context);
            _processVoiceCommand(val);
          },
        ),
        actions: [
          TextButton(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('Procesar',
                style: TextStyle(color: Colors.tealAccent)),
            onPressed: () {
              Navigator.pop(context);
              _processVoiceCommand(voiceController.text);
            },
          ),
        ],
      ),
    );
  }

  void _processVoiceCommand(String text) {
    if (text.isEmpty) return;
    String lower = text.toLowerCase();

    // 1. Detect Type (Prioritized)
    TransactionType type = TransactionType.expense; // Default
    bool typeDetected = false;

    // Priority 1: INCOME (Strongest keywords - Receiving Money)
    if (lower.contains('recibi') ||
        lower.contains('recibí') ||
        lower.contains('gane') ||
        lower.contains('gané') ||
        lower.contains('me dieron') ||
        lower.contains('deposito') ||
        lower.contains('depósito') ||
        lower.contains('sueldo') ||
        lower.contains('cobre') ||
        lower.contains('cobré') ||
        lower.contains('aguinaldo') ||
        lower.contains('ingreso') ||
        lower.contains('ingresó') ||
        // Loans / Slang for receiving
        lower.contains('me empresto') ||
        lower.contains('me emprestó') ||
        lower.contains('me presto') ||
        lower.contains('me prestó') ||
        lower.contains('me prestaron') ||
        lower.contains('me devolvieron') ||
        lower.contains('me yapearon') ||
        lower.contains('me plinearon')) {
      type = TransactionType.income;
      typeDetected = true;
    }

    // Priority 2: TRANSFER
    if (!typeDetected &&
        (lower.contains('transferi') ||
            lower.contains('transferí') ||
            lower.contains('movi') ||
            lower.contains('moví') ||
            lower.contains('pase') ||
            lower.contains('pasé') ||
            lower.contains('envie') ||
            lower.contains('envié') ||
            lower.contains('entre cuentas'))) {
      type = TransactionType.transfer;
      typeDetected = true;
    }

    // Priority 3: EXPENSE (Common words + Sending Slang)
    if (!typeDetected) {
      if (lower.contains('gaste') ||
          lower.contains('gasté') ||
          lower.contains('compre') ||
          lower.contains('compré') ||
          lower.contains('pague') ||
          lower.contains('pagué') ||
          lower.contains('salida') ||
          lower.contains('costo') ||
          lower.contains('costó') ||
          // Loans / Slang for sending
          lower.contains('preste') ||
          lower.contains('presté') ||
          lower.contains('le preste') ||
          lower.contains('le presté') ||
          lower.contains('yapie') || // Sending Yape
          lower.contains('yapié') ||
          lower.contains('plinee') || // Sending Plin
          lower.contains('plineé')) {
        type = TransactionType.expense;
        typeDetected = true;
      }
    }

    // 2. Extract Amount
    double amount = 0.0;
    final RegExp numReg = RegExp(r'(\d+(\.\d+)?)');
    final match = numReg.firstMatch(text);
    if (match != null) {
      amount = double.tryParse(match.group(0)!) ?? 0.0;
    }

    // 3. Detect Account
    int accountId = 1; // Default: Cash

    // Bank Keywords (incl. Peruvian Slang)
    if (lower.contains('banco') ||
        lower.contains('tarjeta') ||
        lower.contains('débito') ||
        lower.contains('debito') ||
        lower.contains('yape') ||
        lower.contains('yapie') ||
        lower.contains('yapié') ||
        lower.contains('yapeo') ||
        lower.contains('yapear') ||
        lower.contains('plin') ||
        lower.contains('plinee') ||
        lower.contains('plineé') ||
        lower.contains('plineo') ||
        lower.contains('plinear') ||
        lower.contains('transferencia') ||
        lower.contains('transferí') ||
        lower.contains('web') ||
        lower.contains('app')) {
      accountId = 2; // Bank
    } else if (lower.contains('ahorros') ||
        lower.contains('ahorro') ||
        lower.contains('guardadito') ||
        lower.contains('chanchito')) {
      accountId = 3; // Savings
    }

    // 4. Detect Category & Title
    int categoryId = 11; // Default: Otros
    String categoryName = "Otros";

    if (type == TransactionType.expense) {
      if (lower.contains('comida') ||
          lower.contains('cena') ||
          lower.contains('almuerzo') ||
          lower.contains('desayuno') ||
          lower.contains('snack') ||
          lower.contains('golosinas') ||
          lower.contains('restaurante') ||
          lower.contains('pizza') ||
          lower.contains('hamburguesa')) {
        categoryId = 1;
        categoryName = "Comida";
      } else if (lower.contains('taxi') ||
          lower.contains('uber') ||
          lower.contains('bus') ||
          lower.contains('micro') ||
          lower.contains('pasaje') ||
          lower.contains('gasolina') ||
          lower.contains('transporte')) {
        categoryId = 2;
        categoryName = "Transporte";
      } else if (lower.contains('ropa') ||
          lower.contains('zapatos') ||
          lower.contains('zapatillas') ||
          lower.contains('pantalon') ||
          lower.contains('camisa')) {
        categoryId = 3;
        categoryName = "Compras";
      } else if (lower.contains('cine') ||
          lower.contains('juego') ||
          lower.contains('netflix') ||
          lower.contains('spotify') ||
          lower.contains('entrada') ||
          lower.contains('ocio')) {
        categoryId = 4;
        categoryName = "Ocio";
      } else if (lower.contains('farmacia') ||
          lower.contains('doctor') ||
          lower.contains('medicina') ||
          lower.contains('salud')) {
        categoryId = 5;
        categoryName = "Salud";
      } else if (lower.contains('casa') ||
          lower.contains('luz') ||
          lower.contains('agua') ||
          lower.contains('internet') ||
          lower.contains('alquiler') ||
          lower.contains('hogar')) {
        categoryId = 6;
        categoryName = "Hogar";
      } else if (lower.contains('curso') ||
          lower.contains('libro') ||
          lower.contains('clase') ||
          lower.contains('universidad')) {
        categoryId = 7;
        categoryName = "Educación";
      }
    } else if (type == TransactionType.income) {
      categoryName = "Ingreso";
    } else if (type == TransactionType.transfer) {
      categoryName = "Transferencia";
    }

    // 5. Construct Draft
    final draft = TransactionEntity(
      accountId: accountId,
      categoryId: categoryId,
      amount: type == TransactionType.expense ? -amount : amount,
      date: DateTime.now(),
      description: categoryName,
      note: "${text[0].toUpperCase()}${text.substring(1)}",
      type: type,
    );

    _showConfirmationDialog(draft);
  }

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
                      _showVoiceSimulator();
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
