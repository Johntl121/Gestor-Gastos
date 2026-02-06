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
                      child: Text("S/ ${draft.amount.abs().toStringAsFixed(2)}",
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold)),
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
    return Scaffold(
      body: _pages[_currentIndex],
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: "voice_btn",
            onPressed: _showVoiceSimulator,
            backgroundColor: Colors.tealAccent,
            child: const Icon(Icons.mic, color: Colors.black),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: "add_btn",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const AddTransactionPage()),
              );
            },
            backgroundColor: Colors.cyan,
            elevation: 4,
            shape: const CircleBorder(),
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: const Color(0xFF15202B),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            _buildNavItem(Icons.home_filled, 0),
            _buildNavItem(Icons.bar_chart, 1),
            const SizedBox(width: 48), // Space for FAB
            _buildNavItem(Icons.history, 2),
            _buildNavItem(Icons.account_balance_wallet_rounded, 3),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, int index) {
    final isSelected = _currentIndex == index;
    return IconButton(
      icon: Icon(
        icon,
        color: isSelected ? Colors.cyan : Colors.grey,
        size: 28,
      ),
      onPressed: () => _onItemTapped(index),
    );
  }
}
