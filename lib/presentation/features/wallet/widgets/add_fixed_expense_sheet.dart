import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // Controllers
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  late final TextEditingController _dayController;
  final FocusNode _dayFocusNode = FocusNode();

  // State
  ExpenseFrequency _selectedFrequency = ExpenseFrequency.monthly;
  DateTime _selectedDate = DateTime.now();
  Color? _customColor;
  String? _customIconName;
  int _selectedCategoryId = 4; // Default a algo, ej. Servicios

  // --- Smart Icons Configuration ---
  final Map<String, int> _smartIconsMap = {
    'wifi': 4, // Servicios
    'bolt': 4,
    'water_drop': 4,
    'phone_android': 4,
    'live_tv': 7, // Entretenimiento
    'sports_esports': 7,
    'music_note': 7,
    'home': 2, // Vivienda
    'cleaning_services': 2,
    'directions_bus': 3, // Transporte
    'local_gas_station': 3,
    'directions_car': 3,
    'school': 6, // Educación
    'shopping_cart': 1, // Alimentación
    'restaurant': 1,
    'medical_services': 5, // Salud
    'fitness_center': 5,
    'content_cut': 5,
    'pets': 10, // Mascotas -> Otros Gastos
  };

  final List<int> _availableColors = [
    0xFFF44336, 0xFFE91E63, 0xFF9C27B0, 0xFF673AB7, 
    0xFF3F51B5, 0xFF2196F3, 0xFF03A9F4, 0xFF00BCD4,
    0xFF009688, 0xFF4CAF50, 0xFF8BC34A, 0xFFCDDC39,
    0xFFFFEB3B, 0xFFFFC107, 0xFFFF9800, 0xFFFF5722
  ];

  late final List<String> _availableIcons;

  @override
  void initState() {
    super.initState();
    _availableIcons = [
      ..._smartIconsMap.keys,
      'tune' // Comodín al final
    ];

    if (widget.subscriptionToEdit != null) {
      final sub = widget.subscriptionToEdit!;
      _nameController.text = sub.name;
      _amountController.text = sub.amount.toString();
      _selectedFrequency = sub.frequency;
      _selectedDate = sub.paymentDate;
      _customColor = sub.customColor != null ? Color(sub.customColor!) : AppCategories.getColor(sub.categoryId);
      _customIconName = sub.customIcon ?? AppCategories.expenseCategories[sub.categoryId]?['icon'] as String? ?? 'grid_view';
      _selectedCategoryId = sub.categoryId;
    } else {
      _customColor = Color(_availableColors.first);
      _customIconName = _availableIcons.first;
      _selectedCategoryId = _smartIconsMap[_customIconName] ?? 10;
    }

    _dayController = TextEditingController(text: _selectedDate.day.toString());
    _dayFocusNode.addListener(_onDayFieldUnfocused);
  }

  @override
  void dispose() {
    _dayFocusNode.removeListener(_onDayFieldUnfocused);
    _dayFocusNode.dispose();
    _dayController.dispose();
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _onDayFieldUnfocused() {
    if (_dayFocusNode.hasFocus) return;
    final parsed = int.tryParse(_dayController.text);
    final clamped = (parsed == null || parsed < 1) ? 1 : (parsed > 31 ? 31 : parsed);
    _dayController.text = clamped.toString();
    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month, clamped);
    });
  }

  void _updateDay(int delta) {
    final current = int.tryParse(_dayController.text) ?? _selectedDate.day;
    final newDay = (current + delta).clamp(1, 31);
    _dayController.text = newDay.toString();
    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month, newDay);
    });
  }

  void _onIconSelected(String iconName) {
    setState(() {
      _customIconName = iconName;
      if (iconName != 'tune' && _smartIconsMap.containsKey(iconName)) {
        // Auto-asignación de categoría basada en icono inteligente
        _selectedCategoryId = _smartIconsMap[iconName]!;
      }
    });
  }

  void _saveExpense() {
    if (_formKey.currentState!.validate()) {
      if (_customColor == null || _customIconName == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor, selecciona un icono y un color.'))
        );
        return;
      }

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
          categoryId: _selectedCategoryId, // Obtenida pasiva o manualmente
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

            // Header
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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Botón Decrementar
                            Material(
                              color: Colors.transparent,
                              shape: const CircleBorder(),
                              clipBehavior: Clip.hardEdge,
                              child: IconButton(
                                onPressed: () => _updateDay(-1),
                                icon: Icon(Icons.remove, color: _customColor ?? const Color(0xFF00E5FF), size: 22),
                                splashRadius: 20,
                                tooltip: 'Disminuir día',
                              ),
                            ),
                            // Campo numérico editable
                            SizedBox(
                              width: 64,
                              child: TextFormField(
                                controller: _dayController,
                                focusNode: _dayFocusNode,
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                style: TextStyle(
                                  color: txtColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(2),
                                ],
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                                  isDense: true,
                                ),
                              ),
                            ),
                            // Botón Incrementar
                            Material(
                              color: Colors.transparent,
                              shape: const CircleBorder(),
                              clipBehavior: Clip.hardEdge,
                              child: IconButton(
                                onPressed: () => _updateDay(1),
                                icon: Icon(Icons.add, color: _customColor ?? const Color(0xFF00E5FF), size: 22),
                                splashRadius: 20,
                                tooltip: 'Aumentar día',
                              ),
                            ),
                          ],
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

                    // --- Módulo de íconos inteligentes ---
                    Text("Elige un ícono", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: txtColor)),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 6,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1,
                      ),
                      itemCount: _availableIcons.length,
                      itemBuilder: (context, index) {
                        final iconName = _availableIcons[index];
                        final isSelected = _customIconName == iconName;
                        return GestureDetector(
                          onTap: () => _onIconSelected(iconName),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected ? (_customColor ?? const Color(0xFF00E5FF)).withValues(alpha: 0.2) : cardColor,
                              shape: BoxShape.circle,
                              border: isSelected ? Border.all(color: _customColor ?? const Color(0xFF00E5FF), width: 2) : Border.all(color: Colors.transparent, width: 2),
                            ),
                            child: Icon(
                              IconMapper.getIcon(iconName), 
                              color: isSelected ? (_customColor ?? const Color(0xFF00E5FF)) : hintColor, 
                              size: 20,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // FeedBack Sutil o Manual Dropdown
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: _customIconName == 'tune'
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: DropdownButton<int>(
                                value: AppCategories.expenseCategories.containsKey(_selectedCategoryId) ? _selectedCategoryId : AppCategories.expenseCategories.keys.first,
                                isExpanded: true,
                                underline: const SizedBox(),
                                dropdownColor: isDarkMode ? const Color(0xFF1E2435) : Colors.white,
                                icon: Icon(Icons.keyboard_arrow_down, color: txtColor),
                                items: AppCategories.expenseCategories.entries.map((entry) {
                                  return DropdownMenuItem<int>(
                                    value: entry.key,
                                    child: Row(
                                      children: [
                                        Icon(AppCategories.getIcon(entry.key), size: 20, color: Color(entry.value['color'] as int)),
                                        const SizedBox(width: 12),
                                        Text(entry.value['name'] as String, style: TextStyle(color: txtColor)),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (catId) {
                                  if (catId != null) {
                                    setState(() {
                                      _selectedCategoryId = catId;
                                    });
                                  }
                                },
                              ),
                            )
                          : Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Icon(Icons.info_outline, size: 14, color: isDarkMode ? Colors.grey[500] : Colors.grey[600]),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Categoría asignada: ${AppCategories.getName(_selectedCategoryId)}",
                                    style: TextStyle(
                                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600], 
                                      fontSize: 13,
                                      fontStyle: FontStyle.italic
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                    const SizedBox(height: 24),

                    // Personalización UI (Color Independiente)
                    Text("Elige un Color", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: txtColor)),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 6,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1,
                      ),
                      itemCount: _availableColors.length,
                      itemBuilder: (context, index) {
                        final cValue = _availableColors[index];
                        final isSelected = _customColor?.toARGB32() == cValue;
                        return GestureDetector(
                          onTap: () => setState(() => _customColor = Color(cValue)),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Color(cValue),
                              shape: BoxShape.circle,
                              border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 40), 
                  ],
                ),
              ),
            ),

            // Action Button Final
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
                  "Guardar Gasto Fijo",
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
