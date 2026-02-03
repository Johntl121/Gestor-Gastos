import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/transaction_entity.dart';
import '../providers/dashboard_provider.dart';

class AddTransactionPage extends StatefulWidget {
  const AddTransactionPage({super.key});

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  final TextEditingController _amountController = TextEditingController();

  // State variables
  bool _isExpense = true;
  int _selectedSourceId = 1; // 1: Cash, 2: Bank, 3: Savings
  int _selectedCategoryId = 3; // Default Shopping

  // Data definitions
  final Map<int, String> _sourceNames = {
    1: 'Efectivo',
    2: 'Banco',
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
    3: {
      'name': 'Compras',
      'icon': Icons.shopping_bag,
      'color': Colors.tealAccent
    }, // Cyan for Shopping in design
    4: {'name': 'Ocio', 'icon': Icons.movie, 'color': Colors.purpleAccent},
    5: {'name': 'Salud', 'icon': Icons.medical_services, 'color': Colors.green},
    6: {'name': 'Servicios', 'icon': Icons.home, 'color': Colors.amber},
    7: {'name': 'Regalos', 'icon': Icons.card_giftcard, 'color': Colors.pink},
    8: {'name': 'Otros', 'icon': Icons.grid_view, 'color': Colors.indigo},
  };

  @override
  void dispose() {
    _amountController.dispose();
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

    // Apply sign based on type
    if (_isExpense) {
      amount = amount * -1;
    }

    final transaction = TransactionEntity(
      accountId:
          _selectedSourceId, // Mapping source to accountId simply for MVP
      categoryId: _selectedCategoryId,
      amount: amount,
      date: DateTime.now(),
      description: _categories[_selectedCategoryId]?['name'] ?? 'Transacción',
    );

    // Call provider
    Provider.of<DashboardProvider>(context, listen: false)
        .addTransaction(transaction);

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    // Colors
    const backgroundColor = Color(0xFF121C22);
    const cyanColor = Color(0xFF00E5FF); // Vibrant Cyan
    const darkSurface = Color(0xFF1E2A32); // Slightly lighter for elements

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Entrada Rápida',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: darkSurface,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.camera_alt, color: cyanColor, size: 20),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),

                  // 1. AMOUNT HERO & VOICE
                  _buildHeroInput(cyanColor, darkSurface),

                  const SizedBox(height: 30),

                  // 2. TOGGLE TYPE
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: darkSurface,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      children: [
                        _buildTypeToggle("GASTO", true, cyanColor),
                        _buildTypeToggle("INGRESO", false, cyanColor),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // 3. SOURCE CHIPS
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text("CUENTA",
                        style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildSourceChip(1, cyanColor, darkSurface),
                      const SizedBox(width: 10),
                      _buildSourceChip(2, cyanColor, darkSurface),
                      const SizedBox(width: 10),
                      _buildSourceChip(3, cyanColor, darkSurface),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // 4. CATEGORY GRID
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text("CATEGORÍA",
                        style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 16),

                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 20,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final catId = index + 1;
                      return _buildCategoryItem(catId, cyanColor, darkSurface);
                    },
                  ),

                  const SizedBox(height: 100), // Space for footer
                ],
              ),
            ),
          ),

          // FOOTER: SAVE BUTTON
          _buildFooter(cyanColor),
        ],
      ),
    );
  }

  Widget _buildHeroInput(Color cyanColor, Color darkSurface) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'S/ ',
              style: TextStyle(
                fontSize: 60,
                fontWeight: FontWeight.bold,
                color: cyanColor,
              ),
            ),
            IntrinsicWidth(
              child: TextField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 60,
                  fontWeight: FontWeight.bold,
                  color: cyanColor,
                  height: 1,
                ),
                decoration: InputDecoration(
                  hintText: '0.00',
                  hintStyle: TextStyle(color: cyanColor.withOpacity(0.5)),
                  border: InputBorder.none,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                autofocus: true,
              ),
            ),
            // Cursor line animation mock
            Container(
              width: 2,
              height: 60,
              color: cyanColor.withOpacity(0.5),
            )
          ],
        ),
        const SizedBox(height: 20),
        Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: cyanColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: cyanColor.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 2)
                  ]),
              child: const Icon(Icons.mic, color: Colors.black, size: 28),
            ),
            const SizedBox(height: 8),
            Text("VOZ",
                style: TextStyle(
                    color: cyanColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0))
          ],
        )
      ],
    );
  }

  Widget _buildTypeToggle(
      String text, bool isOptionExpense, Color activeColor) {
    final isSelected = _isExpense == isOptionExpense;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _isExpense = isOptionExpense;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.transparent
                : Colors
                    .transparent, // Background handled by parent or custom if needed
            // For the design, the selected part usually has a background.
            // Let's approximate the 'SegmentedControl' look
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
                color: isSelected
                    ? activeColor.withOpacity(0.15)
                    : Colors.transparent, // Highlight logic
                borderRadius: BorderRadius.circular(24),
                border: isSelected
                    ? Border.all(color: activeColor.withOpacity(0.3))
                    : null // Optional border
                ),
            // Actually, the request said: "Selected State: Dark Cyan Background and Bright White Text"
            // Let's adhere to that more strictly
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF004D40)
                    : Colors.transparent, // Dark teal/cyan bg for selected
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                text,
                style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSourceChip(int id, Color activeColor, Color darkSurface) {
    final isSelected = _selectedSourceId == id;
    return GestureDetector(
      onTap: () => setState(() => _selectedSourceId = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : darkSurface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(_sourceIcons[id],
                color: isSelected ? Colors.black : Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              _sourceNames[id]!,
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryItem(int id, Color activeColor, Color darkSurface) {
    final isSelected = _selectedCategoryId == id;
    final catData = _categories[id]!;

    return GestureDetector(
      onTap: () => setState(() => _selectedCategoryId = id),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: darkSurface,
                shape: BoxShape.circle,
                border: isSelected
                    ? Border.all(color: activeColor, width: 2)
                    : null,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                            color: activeColor.withOpacity(0.4), blurRadius: 8)
                      ]
                    : null),
            child: Icon(
              catData['icon'] as IconData,
              color: catData['color'] as Color,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            catData['name'] as String,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          )
        ],
      ),
    );
  }

  Widget _buildFooter(Color mainColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 30),
      decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
            const Color(0xFF121C22).withOpacity(0.0),
            const Color(0xFF121C22),
          ])),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: _saveTransaction,
              style: ElevatedButton.styleFrom(
                backgroundColor: mainColor,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text(
                    'Guardar',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(width: 10),
                  Icon(Icons.arrow_forward, size: 24)
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.edit_note, color: Colors.grey, size: 20),
              label: const Text("Añadir nota o archivo",
                  style: TextStyle(color: Colors.grey)))
        ],
      ),
    );
  }
}
