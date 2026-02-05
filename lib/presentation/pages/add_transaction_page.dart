import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/transaction_entity.dart';
import '../providers/dashboard_provider.dart';

class AddTransactionPage extends StatefulWidget {
  final TransactionEntity? transactionToEdit;

  const AddTransactionPage({super.key, this.transactionToEdit});

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

  final Map<int, Map<String, dynamic>> _categories = {
    1: {'name': 'Comida', 'icon': Icons.restaurant, 'color': Colors.orange},
    2: {
      'name': 'Transporte',
      'icon': Icons.directions_car,
      'color': Colors.blue
    },
    3: {'name': 'Compras', 'icon': Icons.shopping_bag, 'color': Colors.cyan},
    4: {'name': 'Ocio', 'icon': Icons.movie, 'color': Colors.purple},
    5: {'name': 'Salud', 'icon': Icons.favorite, 'color': Colors.pink},
    6: {'name': 'Hogar', 'icon': Icons.home, 'color': Colors.brown},
    7: {'name': 'Educación', 'icon': Icons.school, 'color': Colors.indigo},
    8: {'name': 'Regalos', 'icon': Icons.card_giftcard, 'color': Colors.red},
    9: {'name': 'Mascotas', 'icon': Icons.pets, 'color': Colors.amber},
    10: {'name': 'Servicios', 'icon': Icons.bolt, 'color': Colors.yellow},
    11: {'name': 'Otros', 'icon': Icons.grid_view, 'color': Colors.grey},
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

      final catName =
          _categories[_selectedCategoryId]?['name'] ?? 'Transacción';

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
    const backgroundColor = Color(0xFF121C22);
    const darkSurface = Color(0xFF1E2A32);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
            widget.transactionToEdit != null ? 'Editar' : 'Nueva Transacción',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
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
                      color: darkSurface,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Row(
                      children: [
                        _buildTypeTab("Gasto", TransactionType.expense),
                        _buildTypeTab(
                            "Transferencia", TransactionType.transfer),
                        _buildTypeTab("Ingreso", TransactionType.income),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // 2. AMOUNT HERO
                  _buildHeroInput(
                      Provider.of<DashboardProvider>(context, listen: false)
                          .currencySymbol),

                  const SizedBox(height: 30),

                  // 3. SOURCE / DEST (If Transfer)
                  if (_transactionType == TransactionType.transfer) ...[
                    // Origin
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text("DESDE (ORIGEN)",
                          style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1)),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildAccountChip(1, isSource: true),
                          const SizedBox(width: 10),
                          _buildAccountChip(2, isSource: true),
                          const SizedBox(width: 10),
                          _buildAccountChip(3, isSource: true),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Destination
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text("HACIA (DESTINO)",
                          style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1)),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildAccountChip(1, isSource: false),
                          const SizedBox(width: 10),
                          _buildAccountChip(2, isSource: false),
                          const SizedBox(width: 10),
                          _buildAccountChip(3, isSource: false),
                        ],
                      ),
                    ),
                  ] else ...[
                    // STANDARD EXPENSE/INCOME
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text("CUENTA",
                          style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1)),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildAccountChip(1, isSource: true),
                          const SizedBox(width: 10),
                          _buildAccountChip(2, isSource: true),
                          const SizedBox(width: 10),
                          _buildAccountChip(3, isSource: true),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    // 4. CATEGORY GRID
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text("CATEGORÍA",
                          style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1)),
                    ),
                    const SizedBox(height: 16),

                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5, // Cleaner Grid
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.70,
                      ),
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final catId = index + 1;
                        return _buildCategoryItem(catId, darkSurface);
                      },
                    ),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // FOOTER: Note & Save
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildTypeTab(String text, TransactionType type) {
    final isSelected = _transactionType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _transactionType = type),
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
              color: isSelected ? Colors.white : Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroInput(String currency) {
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
                  color: _activeColor,
                ),
                cursorColor: _activeColor,
                decoration: InputDecoration(
                  hintText: '0.00',
                  hintStyle: TextStyle(color: _activeColor.withOpacity(0.3)),
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

  Widget _buildAccountChip(int id, {required bool isSource}) {
    final selectedId = isSource ? _selectedSourceId : _selectedDestId;
    final isSelected = selectedId == id;
    final color = _activeColor;

    return ChoiceChip(
      label: Text(_sourceNames[id]!),
      selected: isSelected,
      onSelected: (bool selected) {
        if (selected) {
          setState(() {
            if (isSource) {
              _selectedSourceId = id;
            } else {
              _selectedDestId = id;
            }
          });
        }
      },
      avatar: Icon(_sourceIcons[id],
          size: 18, color: isSelected ? color : Colors.grey),
      selectedColor: color.withOpacity(0.2),
      backgroundColor: Colors.transparent,
      side: BorderSide(
        color: isSelected ? color : Colors.grey.withOpacity(0.3),
        width: 1.5,
      ),
      labelStyle: TextStyle(
          color: isSelected ? color : Colors.grey,
          fontWeight: FontWeight.bold,
          fontSize: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      showCheckmark: false,
    );
  }

  Widget _buildCategoryItem(int id, Color darkSurface) {
    final isSelected = _selectedCategoryId == id;
    final catData = _categories[id]!;
    final color = _activeColor;

    return GestureDetector(
      onTap: () => setState(() => _selectedCategoryId = id),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? color.withOpacity(0.2) : darkSurface,
              shape: BoxShape.circle,
              border: isSelected ? Border.all(color: color, width: 2) : null,
            ),
            child: Icon(
              catData['icon'] as IconData,
              color: isSelected ? color : Colors.grey[400],
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

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF1E2A32),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Note Field
          TextField(
            controller: _noteController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
                hintText: "Añadir nota...",
                hintStyle: TextStyle(color: Colors.grey[600]),
                prefixIcon: const Icon(Icons.edit_note, color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF121C22),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
          ),
          const SizedBox(height: 20),
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
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 4,
                shadowColor: _activeColor.withOpacity(0.4),
              ),
              child: const Text(
                'Guardar Transacción',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
