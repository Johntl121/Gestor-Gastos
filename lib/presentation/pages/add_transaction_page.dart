import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/transaction_entity.dart';
import '../providers/dashboard_provider.dart';

class AddTransactionPage extends StatefulWidget {
  final TransactionEntity? transactionToEdit;
  final TransactionEntity? draftTransaction;

  const AddTransactionPage(
      {super.key, this.transactionToEdit, this.draftTransaction});

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  // State variables
  TransactionType _transactionType = TransactionType.expense;
  int _selectedSourceId = 1; // 1: Cash, 2: Bank, 3: Savings
  int _selectedDestId = 2; // Default Dest: Bank
  int _selectedCategoryId = 3; // Default Shopping

  @override
  void initState() {
    super.initState();
    if (widget.transactionToEdit != null) {
      final t = widget.transactionToEdit!;
      _transactionType = t.amount < 0
          ? TransactionType.expense
          : (t.type == TransactionType.transfer
              ? TransactionType.transfer
              : TransactionType.income);

      // Override if explicitly transfer in logic
      if (t.type == TransactionType.transfer ||
          t.description.toLowerCase().contains('transferencia')) {
        _transactionType = TransactionType.transfer;
      }

      _amountController.text = t.amount.abs().toString();
      _selectedCategoryId = t.categoryId;
      _selectedSourceId = t.accountId;
      _selectedDestId = t.destinationAccountId ?? 2;
      _noteController.text = t.note ?? '';
    } else if (widget.draftTransaction != null) {
      final t = widget.draftTransaction!;
      _transactionType = t.type;
      _amountController.text = t.amount.abs().toString();
      _selectedCategoryId = t.categoryId;
      // Default accounts or whatever was passed
      _selectedSourceId = t.accountId;
      _selectedDestId = t.destinationAccountId ?? 2;
      _noteController.text = t.note ?? '';
    }
  }

  // Data definitions
  final Map<int, String> _sourceNames = {
    1: 'Efectivo',
    2: 'Bancaria',
    3: 'Ahorros',
  };

  final Map<int, IconData> _sourceIcons = {
    1: Icons.account_balance_wallet,
    2: Icons.account_balance,
    3: Icons.savings,
  };

  final Map<int, Map<String, dynamic>> _expenseCategories = {
    // Alimentación
    1: {'name': 'Comida', 'icon': Icons.restaurant, 'color': Colors.orange},
    2: {
      'name': 'Mercado',
      'icon': Icons.shopping_cart,
      'color': Colors.lightGreen
    },
    // Vivienda
    3: {'name': 'Vivienda', 'icon': Icons.home, 'color': Colors.blueGrey},
    4: {
      'name': 'Servicios',
      'icon': Icons.bolt,
      'color': Colors.amber.shade700
    },
    // Transporte
    5: {
      'name': 'Transporte',
      'icon': Icons.directions_bus,
      'color': Colors.blue
    },
    6: {
      'name': 'Vehículo',
      'icon': Icons.directions_car,
      'color': Colors.redAccent
    },
    // Estilo de Vida
    7: {'name': 'Compras', 'icon': Icons.shopping_bag, 'color': Colors.pink},
    8: {'name': 'Cuidado', 'icon': Icons.spa, 'color': Colors.purple},
    9: {
      'name': 'Suscripciones',
      'icon': Icons.play_circle_filled,
      'color': Colors.red
    },
    // Salud
    10: {'name': 'Salud', 'icon': Icons.local_hospital, 'color': Colors.teal},
    11: {
      'name': 'Deportes',
      'icon': Icons.fitness_center,
      'color': Colors.green
    },
    // Ocio
    12: {
      'name': 'Entretenimiento',
      'icon': Icons.movie,
      'color': Colors.indigo
    },
    13: {'name': 'Viajes', 'icon': Icons.flight, 'color': Colors.cyan},
    // Crecimiento
    14: {'name': 'Educación', 'icon': Icons.school, 'color': Colors.brown},
    15: {'name': 'Tecnología', 'icon': Icons.computer, 'color': Colors.grey},
    // Financiero
    16: {'name': 'Deudas', 'icon': Icons.money_off, 'color': Colors.deepOrange},
    17: {'name': 'Ahorro', 'icon': Icons.savings, 'color': Colors.lime},
    // Otros
    20: {'name': 'Otros', 'icon': Icons.grid_view, 'color': Colors.blueGrey},
  };

  final Map<int, Map<String, dynamic>> _incomeCategories = {
    18: {
      'name': 'Sueldo',
      'icon': Icons.monetization_on,
      'color': Colors.green.shade800
    },
    19: {'name': 'Negocio', 'icon': Icons.work, 'color': Colors.blue.shade900},
    21: {
      'name': 'Inversiones',
      'icon': Icons.trending_up,
      'color': Colors.purple
    },
    22: {
      'name': 'Regalos',
      'icon': Icons.card_giftcard,
      'color': Colors.pinkAccent
    },
    23: {'name': 'Ventas', 'icon': Icons.storefront, 'color': Colors.orange},
    24: {'name': 'Préstamos', 'icon': Icons.handshake, 'color': Colors.teal},
    25: {'name': 'Otros', 'icon': Icons.category, 'color': Colors.blueGrey},
  };

  Color get _activeColor {
    switch (_transactionType) {
      case TransactionType.expense:
        return Colors.redAccent;
      case TransactionType.transfer:
        return const Color(0xFF64B5F6); // Soft Blue
      case TransactionType.income:
        return Colors.green; // Emerald Green
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _saveTransaction() {
    final amountText = _amountController.text;
    if (amountText.isEmpty) return;

    double? amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un monto válido')),
      );
      return;
    }

    // Validation for Transfer
    if (_transactionType == TransactionType.transfer &&
        _selectedSourceId == _selectedDestId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Cuenta de origen y destino no pueden ser iguales')),
      );
      return;
    }

    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final note = _noteController.text.trim();

    if (_transactionType == TransactionType.transfer) {
      // Handle Transfer Logic
      provider.addTransfer(
        amount: amount,
        sourceAccountId: _selectedSourceId,
        destinationAccountId: _selectedDestId,
        note: note.isNotEmpty ? note : null,
      );
    } else {
      // Handle Expense/Income logic
      if (_transactionType == TransactionType.expense) {
        amount = amount * -1;
      }

      final activeMap = _transactionType == TransactionType.income
          ? _incomeCategories
          : _expenseCategories;
      final catName = activeMap[_selectedCategoryId]?['name'] ?? 'Transacción';

      if (widget.transactionToEdit != null) {
        // Update Mode
        final updatedTransaction = TransactionEntity(
          id: widget.transactionToEdit!.id,
          accountId: _selectedSourceId,
          categoryId: _selectedCategoryId,
          amount: amount,
          date: widget.transactionToEdit!.date,
          description: catName,
          note: note.isNotEmpty ? note : null,
          type: _transactionType, // Explicit type update
        );
        provider.updateTransaction(updatedTransaction);
      } else {
        // Add Mode
        final transaction = TransactionEntity(
          accountId: _selectedSourceId,
          categoryId: _selectedCategoryId,
          amount: amount,
          date: DateTime.now(),
          description: catName,
          note: note.isNotEmpty ? note : null,
          type: _transactionType, // Explicit type
        );
        provider.addTransaction(transaction);
      }
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DashboardProvider>(context);
    final isDarkMode = provider.isDarkMode;

    // Theme Colors
    final backgroundColor =
        isDarkMode ? const Color(0xFF15202B) : const Color(0xFFF5F7FA);
    final surfaceColor = isDarkMode ? const Color(0xFF1F2937) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subTextColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];
    final categoryInactiveBg =
        isDarkMode ? const Color(0xFF1F2937) : Colors.grey[100]!;

    // Bottom Area
    final bottomAreaColor = backgroundColor;
    final inputFillColor =
        isDarkMode ? const Color(0xFF1F2937) : Colors.grey[100]!;
    final bottomBorderColor = isDarkMode ? Colors.white10 : Colors.grey[300]!;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: textColor, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
            widget.transactionToEdit != null ? 'Editar' : 'Nueva Transacción',
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 10),

                  // 1. TOGGLE TYPE (Top)
                  Container(
                    height: 50,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(25),
                      border: isDarkMode
                          ? null
                          : Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        _buildTypeTab(
                            "Gasto", TransactionType.expense, isDarkMode),
                        _buildTypeTab("Transferencia", TransactionType.transfer,
                            isDarkMode),
                        _buildTypeTab(
                            "Ingreso", TransactionType.income, isDarkMode),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // 2. AMOUNT HERO
                  _buildHeroInput(provider.currencySymbol, isDarkMode),

                  const SizedBox(height: 20),

                  // 3. SOURCE / DEST (If Transfer)
                  if (_transactionType == TransactionType.transfer) ...[
                    // Origin
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text("DESDE (ORIGEN)",
                          style: TextStyle(
                              color: subTextColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1)),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildAccountChip(1,
                              isSource: true, isDarkMode: isDarkMode),
                          const SizedBox(width: 10),
                          _buildAccountChip(2,
                              isSource: true, isDarkMode: isDarkMode),
                          const SizedBox(width: 10),
                          _buildAccountChip(3,
                              isSource: true, isDarkMode: isDarkMode),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Destination
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text("HACIA (DESTINO)",
                          style: TextStyle(
                              color: subTextColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1)),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildAccountChip(1,
                              isSource: false, isDarkMode: isDarkMode),
                          const SizedBox(width: 10),
                          _buildAccountChip(2,
                              isSource: false, isDarkMode: isDarkMode),
                          const SizedBox(width: 10),
                          _buildAccountChip(3,
                              isSource: false, isDarkMode: isDarkMode),
                        ],
                      ),
                    ),
                  ] else ...[
                    // STANDARD EXPENSE/INCOME
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text("CUENTA",
                          style: TextStyle(
                              color: subTextColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1)),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildAccountChip(1,
                              isSource: true, isDarkMode: isDarkMode),
                          const SizedBox(width: 10),
                          _buildAccountChip(2,
                              isSource: true, isDarkMode: isDarkMode),
                          const SizedBox(width: 10),
                          _buildAccountChip(3,
                              isSource: true, isDarkMode: isDarkMode),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    // 4. CATEGORY GRID
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text("CATEGORÍA",
                          style: TextStyle(
                              color: subTextColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1)),
                    ),
                    const SizedBox(height: 16),

                    // Determine which map to show
                    Builder(builder: (context) {
                      final activeMap =
                          _transactionType == TransactionType.income
                              ? _incomeCategories
                              : _expenseCategories;
                      final keys = activeMap.keys.toList();

                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5, // Cleaner Grid
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.70,
                        ),
                        itemCount: keys.length,
                        itemBuilder: (context, index) {
                          final catId = keys[index];
                          // Pass the map to the item builder so it looks up correctly
                          return _buildCategoryItem(
                              catId, categoryInactiveBg, isDarkMode, activeMap);
                        },
                      );
                    }),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          _buildStickyBottomArea(context, isDarkMode, bottomAreaColor,
              inputFillColor, bottomBorderColor)
        ],
      ),
    );
  }

  Widget _buildTypeTab(String text, TransactionType type, bool isDarkMode) {
    final isSelected = _transactionType == type;
    final inactiveTextColor = isDarkMode ? Colors.grey : Colors.grey[600];

    return Expanded(
      child: GestureDetector(
        onTap: () => _onTypeChanged(type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? _activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? Colors.white : inactiveTextColor,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  void _onTypeChanged(TransactionType type) {
    if (_transactionType != type) {
      setState(() {
        _transactionType = type;
        // Reset category to the first one in the new list to avoid invalid ID
        // Or set to null if preferred, but let's default to first for valid UI
        if (type == TransactionType.income) {
          _selectedCategoryId = _incomeCategories.keys.first;
        } else {
          _selectedCategoryId = _expenseCategories.keys.first;
        }
      });
    }
  }

  Widget _buildHeroInput(String currency, bool isDarkMode) {
    final amountColor = isDarkMode ? Colors.white : Colors.black87;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              currency,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: _activeColor,
              ),
            ),
            const SizedBox(width: 8),
            IntrinsicWidth(
              child: TextField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: amountColor,
                ),
                cursorColor: _activeColor,
                decoration: InputDecoration(
                  hintText: '0.00',
                  hintStyle: TextStyle(
                      color: isDarkMode ? Colors.white24 : Colors.black12),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                autofocus: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAccountChip(int id,
      {required bool isSource, required bool isDarkMode}) {
    final selectId = isSource ? _selectedSourceId : _selectedDestId;
    final isSelected = selectId == id;
    final inactiveTextColor =
        isDarkMode ? Colors.grey[400] : Colors.grey[800]; // Darker Grey
    final inactiveBorderColor =
        isDarkMode ? Colors.transparent : Colors.grey[400]!; // Darker Border
    final inactiveBgColor =
        isDarkMode ? const Color(0xFF1F2937) : Colors.grey[100]!; // Grey tint

    // Account Colors
    Color chipColor;
    Color contentColor = Colors.white;
    switch (id) {
      case 1:
        chipColor = Colors.amber;
        contentColor = Colors.black;
        break;
      case 2:
        chipColor = const Color(0xFF64B5F6); // Light Blue 300
        contentColor = Colors.black;
        break;
      case 3:
        chipColor = const Color(0xFFE040FB); // Purple Accent
        contentColor = Colors.black;
        break;
      default:
        chipColor = _activeColor;
        contentColor = Colors.white; // Default fallback
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSource) {
            _selectedSourceId = id;
          } else {
            _selectedDestId = id;
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? chipColor : inactiveBgColor,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? null
              : Border.all(color: inactiveBorderColor, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(_sourceIcons[id],
                size: 18, color: isSelected ? contentColor : inactiveTextColor),
            const SizedBox(width: 8),
            Text(
              _sourceNames[id]!,
              style: TextStyle(
                  color: isSelected ? contentColor : inactiveTextColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryItem(int id, Color inactiveBgColor, bool isDarkMode,
      Map<int, Map<String, dynamic>> activeMap) {
    final isSelected = _selectedCategoryId == id;
    final catData = activeMap[id]!;
    final color = _activeColor;
    final inactiveIconColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];

    return GestureDetector(
      onTap: () => setState(() => _selectedCategoryId = id),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? color.withOpacity(0.2) : inactiveBgColor,
              shape: BoxShape.circle,
              border: isSelected ? Border.all(color: color, width: 2) : null,
            ),
            child: Icon(
              catData['icon'] as IconData,
              color: isSelected ? color : inactiveIconColor,
              size: 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            catData['name'] as String,
            style: TextStyle(
                color: isSelected ? color : Colors.grey,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          )
        ],
      ),
    );
  }

  Widget _buildStickyBottomArea(BuildContext context, bool isDarkMode,
      Color bgColor, Color inputFillColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.only(left: 24, right: 24, top: 20, bottom: 20),
      decoration: BoxDecoration(
          color: bgColor, border: Border(top: BorderSide(color: borderColor))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Minimalist Note Field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
                color: inputFillColor, borderRadius: BorderRadius.circular(16)),
            child: TextField(
              controller: _noteController,
              style:
                  TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                icon: const Icon(Icons.edit_note, color: Colors.grey),
                hintText: "Nota (Opcional)",
                hintStyle: TextStyle(color: Colors.grey[600]),
                border: InputBorder.none,
                isCollapsed: false,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Save Button
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _saveTransaction,
              style: ElevatedButton.styleFrom(
                backgroundColor: _activeColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Guardar Transacción',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
