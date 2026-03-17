import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../data/models/subscription.dart';
import '../../../providers/transaction_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../../../core/constants/app_categories.dart';

class AddFixedExpenseSheet extends StatefulWidget {
  final Subscription? subscriptionToEdit;
  
  const AddFixedExpenseSheet({super.key, this.subscriptionToEdit});

  @override
  State<AddFixedExpenseSheet> createState() => _AddFixedExpenseSheetState();
}

class _AddFixedExpenseSheetState extends State<AddFixedExpenseSheet> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();

  // State
  ExpenseFrequency _selectedFrequency = ExpenseFrequency.monthly;
  DateTime _selectedDate = DateTime.now();
  Color _selectedColor = const Color(0xFF00E5FF); 
  IconData _selectedIcon = Icons.home;
  int _selectedCategoryId = 9; // Suscripciones por defecto


  @override
  void initState() {
    super.initState();
    if (widget.subscriptionToEdit != null) {
      final sub = widget.subscriptionToEdit!;
      _nameController.text = sub.name;
      _amountController.text = sub.amount.toString();
      _selectedFrequency = sub.frequency;
      _selectedDate = sub.paymentDate;
      _selectedColor = Color(sub.colorValue);
      _selectedIcon = IconData(sub.iconCode, fontFamily: 'MaterialIcons');
      _selectedCategoryId = sub.categoryId;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Theme
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Colores del diseño
    final backgroundColor = isDarkMode ? const Color(0xFF1E2435) : Colors.white;
    final cardColor = isDarkMode ? Colors.black26 : Colors.grey[100]!;
    final txtColor = isDarkMode ? Colors.white : Colors.black87;
    final hintColor = isDarkMode ? Colors.white38 : Colors.grey;
    final currencySymbol = Provider.of<WalletProvider>(context).currencySymbol;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.white24 : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Título
            Text(
              widget.subscriptionToEdit != null ? "Editar Gasto Fijo" : "Nuevo Gasto Fijo",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: txtColor,
              ),
            ),
            const SizedBox(height: 20),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Selector de Frecuencia
                    Container(
                      height: 45,
                      width: double.infinity,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          _buildFrequencyOption(
                              "Mensual", ExpenseFrequency.monthly, isDarkMode),
                          _buildFrequencyOption(
                              "Anual", ExpenseFrequency.yearly, isDarkMode),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 2. Campos de Texto
                    _buildTextField(
                      controller: _nameController,
                      label: "Nombre (ej. Netflix)",
                      icon: Icons.subscriptions_outlined,
                      cardColor: cardColor,
                      txtColor: txtColor,
                      hintColor: hintColor,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _amountController,
                      label: "Monto",
                      icon: null,
                      currencySymbol: currencySymbol,
                      cardColor: cardColor,
                      txtColor: txtColor,
                      hintColor: hintColor,
                      isNumber: true,
                    ),
                    const SizedBox(height: 24),
                    const SizedBox(height: 24),

                    // --- NUEVA SECCIÓN: CATEGORÍA ---
                    Text("Categoría",
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: txtColor)),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.8,
                      ),
                      itemCount: AppCategories.expenseCategories.length,
                      itemBuilder: (context, index) {
                        final catId = AppCategories.expenseCategories.keys.elementAt(index);
                        final catData = AppCategories.expenseCategories[catId]!;
                        final isSelected = _selectedCategoryId == catId;
                        
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedCategoryId = catId;
                              _selectedIcon = AppCategories.getIcon(catId);
                              _selectedColor = AppCategories.getColor(catId);
                            });
                          },
                          child: Column(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: isSelected 
                                      ? _selectedColor.withValues(alpha: 0.2)
                                      : cardColor,
                                  shape: BoxShape.circle,
                                  border: isSelected 
                                      ? Border.all(color: _selectedColor, width: 2)
                                      : null,
                                ),
                                child: Icon(
                                  AppCategories.getIcon(catId),
                                  color: isSelected ? _selectedColor : hintColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                catData['name'],
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isSelected ? _selectedColor : hintColor,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // 4. Día de Pago
                    Text(
                      _selectedFrequency == ExpenseFrequency.monthly
                          ? "Día de pago"
                          : "Fecha de pago anual",
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: txtColor),
                    ),
                    const SizedBox(height: 12),
                    if (_selectedFrequency == ExpenseFrequency.monthly)
                      SizedBox(
                        height: 40,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: 31,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final day = index + 1;
                            final isSelected = _selectedDate.day == day;
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedDate = DateTime(_selectedDate.year,
                                      _selectedDate.month, day);
                                });
                              },
                              child: Container(
                                width: 40,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color:
                                      isSelected ? _selectedColor : cardColor,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  "$day",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isSelected ? Colors.white : txtColor,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: ColorScheme.dark(
                                    primary: _selectedColor,
                                    onPrimary: Colors.white,
                                    surface: const Color(0xFF1E2435),
                                    onSurface: Colors.white,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            setState(() => _selectedDate = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "${_selectedDate.day} de ${_getMonthName(_selectedDate.month)}",
                                style: TextStyle(
                                    fontSize: 14,
                                    color: txtColor,
                                    fontWeight: FontWeight.w500),
                              ),
                              Icon(Icons.calendar_today,
                                  color: _selectedColor, size: 18),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            // Botón Guardar
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saveExpense,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 4,
                  shadowColor: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                ),
                child: const Text(
                  "Guardar",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Helpers UI ---

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData? icon,
    String? currencySymbol,
    required Color cardColor,
    required Color txtColor,
    required Color hintColor,
    bool isNumber = false,
  }) {
    return SizedBox(
      height: 50,
      child: TextFormField(
        controller: controller,
        style: TextStyle(color: txtColor, fontSize: 14),
        keyboardType: isNumber
            ? const TextInputType.numberWithOptions(decimal: true)
            : null,
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: hintColor, fontSize: 13),
          filled: true,
          fillColor: cardColor,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _selectedColor, width: 1.5),
          ),
          prefixIcon: currencySymbol != null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(currencySymbol,
                        style: TextStyle(
                            color: hintColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                  ],
                )
              : (icon != null ? Icon(icon, color: hintColor, size: 18) : null),
        ),
        validator: (v) => v!.isEmpty ? "" : null,
      ),
    );
  }

  Widget _buildFrequencyOption(
      String label, ExpenseFrequency val, bool isDarkMode) {
    final isSelected = _selectedFrequency == val;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedFrequency = val),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDarkMode ? Colors.white : Colors.black87)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isSelected
                  ? (isDarkMode ? Colors.black87 : Colors.white)
                  : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      "Enero",
      "Febrero",
      "Marzo",
      "Abril",
      "Mayo",
      "Junio",
      "Julio",
      "Agosto",
      "Septiembre",
      "Octubre",
      "Noviembre",
      "Diciembre"
    ];
    return months[month - 1];
  }

  void _saveExpense() {
    if (_nameController.text.isNotEmpty && _amountController.text.isNotEmpty) {
      final name = _nameController.text;
      final amount = double.tryParse(_amountController.text) ?? 0.0;
      final provider = Provider.of<TransactionProvider>(context, listen: false);
      if (widget.subscriptionToEdit != null) {
        final updatedSub = widget.subscriptionToEdit!.copyWith(
          name: name,
          amount: amount,
          paymentDate: _selectedDate,
          frequency: _selectedFrequency,
          accountToCharge: 1, // Default, será sobreescrita al confirmar el pago real
          iconCode: _selectedIcon.codePoint,
          colorValue: _selectedColor.toARGB32(),
          categoryId: _selectedCategoryId,
        );
        provider.addSubscription(updatedSub);
      } else {
        final newSub = Subscription(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: name,
          amount: amount,
          paymentDate: _selectedDate,
          frequency: _selectedFrequency,
          accountToCharge: 1, // Default, será elegida en cada pago
          iconCode: _selectedIcon.codePoint,
          colorValue: _selectedColor.toARGB32(),
          categoryId: _selectedCategoryId,
        );
        provider.addSubscription(newSub);
      }
      Navigator.pop(context);
    }
  }
}
