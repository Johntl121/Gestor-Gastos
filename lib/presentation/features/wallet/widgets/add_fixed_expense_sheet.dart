import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../data/models/subscription.dart';
import '../../../providers/transaction_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../../../core/constants/app_categories.dart';
import '../../../../core/constants/icon_mapper.dart';

class AddFixedExpenseSheet extends StatefulWidget {
  final Subscription? subscriptionToEdit;
  
  const AddFixedExpenseSheet({super.key, this.subscriptionToEdit});

  @override
  State<AddFixedExpenseSheet> createState() => _AddFixedExpenseSheetState();
}

class _AddFixedExpenseSheetState extends State<AddFixedExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();

  // Controllers
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();

  // State
  ExpenseFrequency _selectedFrequency = ExpenseFrequency.monthly;
  DateTime _selectedDate = DateTime.now();
  Color? _customColor;
  String? _customIconName;
  int _selectedCategoryId = 1; // 1 = Alimentación/Default
  int _currentPage = 0;

  final List<int> _availableColors = [
    0xFFF44336, 0xFFE91E63, 0xFF9C27B0, 0xFF673AB7, 
    0xFF3F51B5, 0xFF2196F3, 0xFF03A9F4, 0xFF00BCD4,
    0xFF009688, 0xFF4CAF50, 0xFF8BC34A, 0xFFCDDC39,
    0xFFFFEB3B, 0xFFFFC107, 0xFFFF9800, 0xFFFF5722
  ];

  final List<String> _availableIcons = [
    'live_tv', 'wifi', 'bolt', 'water_drop', 'phone_android', 
    'home', 'directions_car', 'fitness_center', 'school', 'gamepad'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.subscriptionToEdit != null) {
      final sub = widget.subscriptionToEdit!;
      _nameController.text = sub.name;
      _amountController.text = sub.amount.toString();
      _selectedFrequency = sub.frequency;
      _selectedDate = sub.paymentDate;
      // Tratar de inicializar con valores predeterminados de la categoría si eran nulos
      _customColor = sub.customColor != null ? Color(sub.customColor!) : AppCategories.getColor(sub.categoryId);
      _customIconName = sub.customIcon ?? AppCategories.expenseCategories[sub.categoryId]?['icon'] as String? ?? 'category';
      _selectedCategoryId = sub.categoryId;
    } else {
      _customColor = Color(_availableColors.first);
      _customIconName = _availableIcons.first;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_formKey.currentState!.validate()) {
      if (_customColor == null || _customIconName == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor, selecciona un icono y un color.'))
        );
        return;
      }
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentPage = 1;
      });
    }
  }

  void _previousStep() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() {
      _currentPage = 0;
    });
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
          accountToCharge: 1, 
          customIcon: _customIconName,
          customColor: _customColor?.toARGB32(),
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
          accountToCharge: 1, 
          customIcon: _customIconName,
          customColor: _customColor?.toARGB32(),
          categoryId: _selectedCategoryId,
        );
        provider.addSubscription(newSub);
      }
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final backgroundColor = isDarkMode ? const Color(0xFF1E2435) : Colors.white;
    final cardColor = isDarkMode ? Colors.black26 : Colors.grey[100]!;
    final txtColor = isDarkMode ? Colors.white : Colors.black87;
    final hintColor = isDarkMode ? Colors.white38 : Colors.grey;
    final currencySymbol = Provider.of<WalletProvider>(context).currencySymbol;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
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

            // Navigation Header
            Row(
              children: [
                if (_currentPage == 1)
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: txtColor),
                    onPressed: _previousStep,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                if (_currentPage == 1) const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    _currentPage == 0
                        ? (widget.subscriptionToEdit != null ? "Editar Gasto Fijo" : "Nuevo Gasto Fijo")
                        : "Clasificación Contable",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: txtColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(), // Deshabilitar swipe normal
                children: [
                  _buildStep1(isDarkMode, cardColor, txtColor, hintColor, currencySymbol),
                  _buildStep2(cardColor, txtColor, hintColor),
                ],
              ),
            ),

            // Action Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _currentPage == 0 ? _nextStep : _saveExpense,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 4,
                  shadowColor: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                ),
                child: Text(
                  _currentPage == 0 ? "Siguiente" : "Guardar Gasto Fijo",
                  style: const TextStyle(
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

  Widget _buildStep1(bool isDarkMode, Color cardColor, Color txtColor, Color hintColor, String? currencySymbol) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selector de Frecuencia
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
                _buildFrequencyOption("Mensual", ExpenseFrequency.monthly, isDarkMode),
                _buildFrequencyOption("Anual", ExpenseFrequency.yearly, isDarkMode),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Campos de Texto
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

          // Día de Pago
          Text(
            _selectedFrequency == ExpenseFrequency.monthly
                ? "Día de pago"
                : "Fecha de pago anual",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: txtColor),
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
                        _selectedDate = DateTime(_selectedDate.year, _selectedDate.month, day);
                      });
                    },
                    child: Container(
                      width: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? (_customColor ?? const Color(0xFF00E5FF)) : cardColor,
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
                          primary: _customColor ?? const Color(0xFF00E5FF),
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
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
                      style: TextStyle(fontSize: 14, color: txtColor, fontWeight: FontWeight.w500),
                    ),
                    Icon(Icons.calendar_today, color: _customColor ?? const Color(0xFF00E5FF), size: 18),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),

          // Personalización UI (Icono)
          Text("Elige un Icono", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: txtColor)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _availableIcons.map((iconName) {
              final isSelected = _customIconName == iconName;
              return GestureDetector(
                onTap: () => setState(() => _customIconName = iconName),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected ? (_customColor ?? const Color(0xFF00E5FF)).withValues(alpha: 0.2) : cardColor,
                    shape: BoxShape.circle,
                    border: isSelected ? Border.all(color: _customColor ?? const Color(0xFF00E5FF), width: 2) : Border.all(color: Colors.transparent, width: 2),
                  ),
                  child: Icon(
                    IconMapper.getIcon(iconName), 
                    color: isSelected ? (_customColor ?? const Color(0xFF00E5FF)) : hintColor, 
                    size: 24
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Personalización UI (Color)
          Text("Elige un Color", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: txtColor)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _availableColors.map((cValue) {
              final isSelected = _customColor?.toARGB32() == cValue;
              return GestureDetector(
                onTap: () => setState(() => _customColor = Color(cValue)),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Color(cValue),
                    shape: BoxShape.circle,
                    border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 40), // Margen inferior
        ],
      ),
    );
  }

  Widget _buildStep2(Color cardColor, Color txtColor, Color hintColor) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Para que tus gráficas sean exactas al realizar el pago, elige a qué categoría estadística pertenece o se alinea este gasto.",
            style: TextStyle(color: hintColor, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 24),
          
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 16,
              crossAxisSpacing: 12,
              childAspectRatio: 0.8,
            ),
            itemCount: AppCategories.expenseCategories.length,
            itemBuilder: (context, index) {
              final catId = AppCategories.expenseCategories.keys.elementAt(index);
              final catData = AppCategories.expenseCategories[catId]!;
              final isSelected = _selectedCategoryId == catId;
              
              final cColor = Color(catData['color'] as int);

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCategoryId = catId;
                  });
                },
                child: Column(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: isSelected ? cColor.withValues(alpha: 0.2) : cardColor,
                        shape: BoxShape.circle,
                        border: isSelected ? Border.all(color: cColor, width: 2) : Border.all(color: Colors.transparent, width: 2),
                      ),
                      child: Icon(
                        AppCategories.getIcon(catId),
                        color: isSelected ? cColor : hintColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      catData['name'] as String,
                      style: TextStyle(
                        fontSize: 10,
                        color: isSelected ? cColor : hintColor,
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
          const SizedBox(height: 40),
        ],
      ),
    );
  }

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
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            borderSide: BorderSide(color: _customColor ?? const Color(0xFF00E5FF), width: 1.5),
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

  Widget _buildFrequencyOption(String label, ExpenseFrequency val, bool isDarkMode) {
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
      "Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
      "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"
    ];
    return months[month - 1];
  }
}
