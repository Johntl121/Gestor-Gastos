import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/entities/transaction_entity.dart';
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

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  bool _isSpeedDialOpen = false;
  final SpeechService _speechService = SpeechService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final walletProvider =
          Provider.of<WalletProvider>(context, listen: false);
      walletProvider.initApp();

      final transactionProvider =
          Provider.of<TransactionProvider>(context, listen: false);
      try {
        // Attempt to load transactions if the provider has such method exposed,
        // otherwise it might be in constructor.
        // Based on typical patterns, it's safer to just let WalletProvider handle its part.
        // However, if TransactionProvider is empty, we should load it.
        // Let's assume loadTransactions exists or is public.
        transactionProvider.loadTransactions();
      } catch (e) {
        // If method doesn't exist, ignore.
      }
    });
  }

  List<Widget> get _pages => [
        HomePage(onSeeAllPressed: () => _onItemTapped(2)),
        const StatsPage(),
        const HistoryPage(),
        const WalletPage(),
      ];

  void _onItemTapped(int index) {
    Provider.of<UiProvider>(context, listen: false).setIndex(index);
  }

  // --- Voice Logic ---

  void _startVoiceTransaction(BuildContext context) {
    String currentText = "";
    bool isListening = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            if (isListening && !_speechService.isListening) {
              _speechService.listen(
                (text) {
                  setSheetState(() => currentText = text);
                },
              );
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
                  const Text(
                    "Te escucho...",
                    style: TextStyle(
                        color: Colors.grey, fontSize: 14, letterSpacing: 1),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: SingleChildScrollView(
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
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () {
                      _speechService.stop();
                      Navigator.pop(context);
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

      int categoryId = 11;
      switch (categoryName) {
        case "Comida":
          categoryId = 1;
          break;
        case "Transporte":
          categoryId = 2;
          break;
        case "Compras":
          categoryId = 3;
          break;
        case "Ocio":
          categoryId = 4;
          break;
        case "Salud":
          categoryId = 5;
          break;
        case "Hogar":
          categoryId = 6;
          break;
        case "Educación":
          categoryId = 7;
          break;
      }

      int accountId = walletProvider.accounts.isNotEmpty
          ? walletProvider.accounts.first.id
          : 1;

      if (detectedAccount != null) {
        try {
          final match = walletProvider.accounts.firstWhere((acc) =>
              acc.name.toLowerCase().contains(detectedAccount.toLowerCase()));
          accountId = match.id;
        } catch (e) {
          debugPrint(
              "VoiceAI: Cuenta '$detectedAccount' no encontrada. Usando default.");
        }
      }

      final draft = TransactionEntity(
        accountId: accountId,
        categoryId: categoryId,
        amount: type == TransactionType.expense ? -amount.abs() : amount.abs(),
        date: DateTime.now(),
        description: description,
        note: "Voz: $text",
        type: type,
        destinationAccountId: null,
      );

      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => AddTransactionPage(draftTransaction: draft)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No pude entender la transacción 😕")));
    }
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    // Listen to UiProvider for Dark Mode and Current Index
    final uiProvider = Provider.of<UiProvider>(context);

    return Scaffold(
      backgroundColor:
          uiProvider.isDarkMode ? const Color(0xFF15202B) : Colors.grey[100],
      body: Stack(
        fit: StackFit.expand,
        children: [
          _pages[uiProvider.currentIndex],
          if (_isSpeedDialOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _isSpeedDialOpen = false),
                child: Container(
                  color: Colors.black.withOpacity(0.6),
                ),
              ),
            ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                color: const Color(0xFF1F2937),
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
                  _buildDockItem(
                      Icons.home_rounded, 0, uiProvider.currentIndex),
                  _buildDockItem(
                      Icons.bar_chart_rounded, 1, uiProvider.currentIndex),
                  const SizedBox(width: 60),
                  _buildDockItem(
                      Icons.history_rounded, 2, uiProvider.currentIndex),
                  _buildDockItem(Icons.account_balance_wallet_rounded, 3,
                      uiProvider.currentIndex),
                ],
              ),
            ),
          ),
          if (_isSpeedDialOpen)
            Positioned(
              bottom: 110,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
          Positioned(
            bottom: 25,
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
                            : Colors.cyan.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: AnimatedRotation(
                    turns: _isSpeedDialOpen ? 0.125 : 0,
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

  Widget _buildDockItem(IconData icon, int index, int currentIndex) {
    final isSelected = currentIndex == index;
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
        ),
      ),
    );
  }
}
