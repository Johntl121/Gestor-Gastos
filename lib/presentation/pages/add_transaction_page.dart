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

  // 1 = Efectivo, 2 = Digital (Basado en el seed)
  int _selectedAccountId = 1;

  // Categorias (Basado en el seed)
  int _selectedCategoryId = 1;

  final Map<int, IconData> _categoryIcons = {
    1: Icons.fastfood, // Comida
    2: Icons.directions_bus, // Transporte
    3: Icons.movie, // Ocio
    4: Icons.category, // Varios
  };

  final Map<int, String> _categoryNames = {
    1: 'Comida',
    2: 'Transporte',
    3: 'Ocio',
    4: 'Varios',
  };

  final Map<int, Color> _categoryColors = {
    1: Colors.orange,
    2: Colors.blue,
    3: Colors.purple,
    4: Colors.grey,
  };

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _saveTransaction() {
    final amountText = _amountController.text;
    if (amountText.isEmpty) return;

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un monto válido')),
      );
      return;
    }

    final transaction = TransactionEntity(
      accountId: _selectedAccountId,
      categoryId: _selectedCategoryId,
      amount: amount,
      date: DateTime.now(),
      description: _categoryNames[_selectedCategoryId] ?? 'Gasto',
    );

    // Llamar al provider
    Provider.of<DashboardProvider>(context, listen: false)
        .addTransaction(transaction);

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title:
            const Text('Agregar Gasto', style: TextStyle(color: Colors.black)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Monto',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 10),

            // 1. Input de Monto Grande
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              decoration: const InputDecoration(
                hintText: '0.00',
                border: InputBorder.none,
                prefixText: 'S/ ',
                prefixStyle: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.black),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              autofocus: true,
            ),

            const SizedBox(height: 40),

            // 2. Selector de Cuenta
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  _buildAccountToggleOption('Efectivo', 1),
                  _buildAccountToggleOption('Digital', 2),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // 3. Selector de Categoría
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Categoría',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800]),
              ),
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCategoryOption(1),
                _buildCategoryOption(2),
                _buildCategoryOption(3),
                _buildCategoryOption(4),
              ],
            ),

            const SizedBox(height: 50),

            // 4. Botón Guardar
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _saveTransaction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 5,
                ),
                child: const Text(
                  'Guardar Gasto',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountToggleOption(String label, int id) {
    final isSelected = _selectedAccountId == id;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedAccountId = id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        spreadRadius: 1)
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.black : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryOption(int id) {
    final isSelected = _selectedCategoryId == id;
    final color = _categoryColors[id]!;

    return GestureDetector(
      onTap: () => setState(() => _selectedCategoryId = id),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withValues(alpha: 0.1)
                  : Colors.grey[50], // Fondo sutil si seleccionado
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? color : Colors.transparent,
                width: 2,
              ),
            ),
            child: Icon(
              _categoryIcons[id],
              color: isSelected ? color : Colors.grey[400],
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _categoryNames[id]!,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? color : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
