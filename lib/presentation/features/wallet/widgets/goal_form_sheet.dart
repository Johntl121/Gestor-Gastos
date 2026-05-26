import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../domain/entities/goal_entity.dart';
import '../../../providers/wallet_provider.dart';
import '../../../../core/constants/app_categories.dart';
import '../../../../core/constants/icon_mapper.dart';

class GoalFormSheet extends StatefulWidget {
  final GoalEntity? goalToEdit;

  const GoalFormSheet({super.key, this.goalToEdit});

  @override
  State<GoalFormSheet> createState() => _GoalFormSheetState();
}

class _GoalFormSheetState extends State<GoalFormSheet> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();

  // State
  Color? _customColor;
  String? _selectedIconName;
  int _selectedCategoryId = 8; // Default: Compras
  DateTime? _selectedDeadline;
  int? _selectedAccountId;

  // --- Smart Icons para Metas de Ahorro ---
  final Map<String, int> _smartIconsMap = {
    'star': 8,              // Compras (genérico)
    'computer': 8,          // Compras / Tecnología
    'phone_android': 8,     // Compras / Tecnología
    'flight': 7,            // Entretenimiento / Viajes
    'directions_car': 3,    // Transporte
    'home': 2,              // Vivienda
    'school': 6,            // Educación
    'shopping_bag': 8,      // Compras
    'gamepad': 7,           // Entretenimiento
    'sports_esports': 7,    // Entretenimiento
    'music_note': 7,        // Entretenimiento
    'live_tv': 7,           // Entretenimiento
    'medical_services': 5,  // Salud
    'fitness_center': 5,    // Salud
    'pets': 10,             // Otros Gastos
    'restaurant': 1,        // Alimentación
    'spa': 5,               // Salud
    'savings': 8,           // Compras / Ahorro
    'work': 10,             // Otros Gastos
  };

  final List<int> _availableColors = [
    0xFFF44336, 0xFFE91E63, 0xFF9C27B0, 0xFF673AB7,
    0xFF3F51B5, 0xFF2196F3, 0xFF03A9F4, 0xFF00BCD4,
    0xFF009688, 0xFF4CAF50, 0xFF8BC34A, 0xFFCDDC39,
    0xFFFFEB3B, 0xFFFFC107, 0xFFFF9800, 0xFFFF5722,
  ];

  late final List<String> _availableIcons;

  @override
  void initState() {
    super.initState();
    _availableIcons = [
      ..._smartIconsMap.keys,
      'tune', // Comodín: selección manual de categoría
    ];

    if (widget.goalToEdit != null) {
      final goal = widget.goalToEdit!;
      _nameController.text = goal.name;
      _amountController.text = goal.targetAmount.toStringAsFixed(0);
      _customColor = goal.color;
      _selectedIconName = goal.iconName ?? _availableIcons.first;
      _selectedCategoryId = goal.categoryId ?? _smartIconsMap[_selectedIconName] ?? 8;
      _selectedDeadline = goal.deadline;
      _selectedAccountId = goal.accountId;
    } else {
      _customColor = Color(_availableColors.first);
      _selectedIconName = _availableIcons.first;
      _selectedCategoryId = _smartIconsMap[_selectedIconName] ?? 8;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _onIconSelected(String iconName) {
    setState(() {
      _selectedIconName = iconName;
      if (iconName != 'tune' && _smartIconsMap.containsKey(iconName)) {
        _selectedCategoryId = _smartIconsMap[iconName]!;
      }
    });
  }

  void _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDeadline ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2035),
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
      setState(() => _selectedDeadline = picked);
    }
  }

  String? _buildSavingsTip(String currencySymbol) {
    if (_selectedDeadline == null) return null;
    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) return null;

    final existingSaved = widget.goalToEdit?.currentAmount ?? 0;
    final remaining = amount - existingSaved;
    if (remaining <= 0) return null;

    final daysLeft = _selectedDeadline!.difference(DateTime.now()).inDays;
    if (daysLeft <= 0) return null;

    final monthsLeft = daysLeft / 30.0;
    final monthlySaving = remaining / monthsLeft;

    return "💡 Tip: Ahorra $currencySymbol ${monthlySaving.toStringAsFixed(2)} al mes";
  }

  void _saveGoal() {
    if (_formKey.currentState!.validate()) {
      if (_customColor == null || _selectedIconName == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona un ícono y un color.')),
        );
        return;
      }

      if (_selectedAccountId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona una cuenta destino (alcancía).')),
        );
        return;
      }

      final name = _nameController.text.trim();
      final amount = double.tryParse(_amountController.text) ?? 0;
      final iconData = IconMapper.getIcon(_selectedIconName);
      final provider = Provider.of<WalletProvider>(context, listen: false);

      if (widget.goalToEdit == null) {
        // CREATE
        provider.addGoal(
          name,
          amount,
          iconData.codePoint,
          _customColor!.toARGB32(),
          iconName: _selectedIconName,
          deadline: _selectedDeadline,
          accountId: _selectedAccountId,
          categoryId: _selectedCategoryId,
        );
      } else {
        // UPDATE
        final updated = GoalEntity(
          id: widget.goalToEdit!.id,
          name: name,
          targetAmount: amount,
          currentAmount: widget.goalToEdit!.currentAmount,
          iconCode: iconData.codePoint,
          iconName: _selectedIconName,
          colorValue: _customColor!.toARGB32(),
          isCompleted: widget.goalToEdit!.currentAmount >= amount,
          deadline: _selectedDeadline,
          accountId: _selectedAccountId,
          categoryId: _selectedCategoryId,
        );
        provider.updateGoal(updated);
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
    final accentColor = _customColor ?? const Color(0xFF00E5FF);

    final walletProvider = Provider.of<WalletProvider>(context);
    final currencySymbol = walletProvider.currencySymbol;
    final accounts = walletProvider.accounts;

    // Auto-seleccionar primera cuenta si no hay selección
    if (_selectedAccountId == null && accounts.isNotEmpty) {
      _selectedAccountId = accounts.first.id;
    }

    final savingsTip = _buildSavingsTip(currencySymbol);

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.emoji_events, color: accentColor, size: 24),
                const SizedBox(width: 10),
                Text(
                  widget.goalToEdit != null ? "Editar Meta" : "Nueva Meta",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: txtColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── BLOQUE 1: IDENTIDAD ───
                    _buildSectionLabel("Identidad", Icons.badge_outlined, txtColor),
                    const SizedBox(height: 12),

                    // Nombre
                    _buildTextField(
                      controller: _nameController,
                      label: "¿Qué quieres lograr?",
                      icon: Icons.flag_outlined,
                      cardColor: cardColor,
                      txtColor: txtColor,
                      hintColor: hintColor,
                      accentColor: accentColor,
                    ),
                    const SizedBox(height: 20),

                    // Smart Icons Grid
                    Text("Elige un ícono",
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: txtColor)),
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
                        final isSelected = _selectedIconName == iconName;
                        return GestureDetector(
                          onTap: () => _onIconSelected(iconName),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? accentColor.withValues(alpha: 0.2)
                                  : cardColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? accentColor : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              IconMapper.getIcon(iconName),
                              color: isSelected ? accentColor : hintColor,
                              size: 20,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),

                    // Categoría feedback o dropdown manual
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: _selectedIconName == 'tune'
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: DropdownButton<int>(
                                value: AppCategories.expenseCategories.containsKey(_selectedCategoryId)
                                    ? _selectedCategoryId
                                    : AppCategories.expenseCategories.keys.first,
                                isExpanded: true,
                                underline: const SizedBox(),
                                dropdownColor: isDarkMode ? const Color(0xFF1E2435) : Colors.white,
                                icon: Icon(Icons.keyboard_arrow_down, color: txtColor),
                                items: AppCategories.expenseCategories.entries.map((entry) {
                                  return DropdownMenuItem<int>(
                                    value: entry.key,
                                    child: Row(
                                      children: [
                                        Icon(AppCategories.getIcon(entry.key),
                                            size: 20, color: Color(entry.value['color'] as int)),
                                        const SizedBox(width: 12),
                                        Text(entry.value['name'] as String,
                                            style: TextStyle(color: txtColor)),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (catId) {
                                  if (catId != null) {
                                    setState(() => _selectedCategoryId = catId);
                                  }
                                },
                              ),
                            )
                          : Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0),
                              child: Row(
                                children: [
                                  Icon(Icons.auto_awesome, size: 14,
                                      color: accentColor.withValues(alpha: 0.7)),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Categoría asignada: ${AppCategories.getName(_selectedCategoryId)}",
                                    style: TextStyle(
                                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                      fontSize: 13,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                    const SizedBox(height: 20),

                    // Color Picker
                    Text("Elige un color",
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: txtColor)),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 8,
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
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: Color(cValue),
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(color: Colors.white, width: 3)
                                  : null,
                              boxShadow: isSelected
                                  ? [BoxShadow(color: Color(cValue).withValues(alpha: 0.6), blurRadius: 8)]
                                  : null,
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, size: 16, color: Colors.white)
                                : null,
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 28),

                    // ─── BLOQUE 2: FINANZAS ───
                    _buildSectionLabel("Finanzas", Icons.savings_outlined, txtColor),
                    const SizedBox(height: 12),

                    // Monto Objetivo
                    _buildTextField(
                      controller: _amountController,
                      label: "Monto Objetivo",
                      icon: null,
                      currencySymbol: currencySymbol,
                      cardColor: cardColor,
                      txtColor: txtColor,
                      hintColor: hintColor,
                      accentColor: accentColor,
                      isNumber: true,
                      onChanged: (_) => setState(() {}), // Recalcular tip
                    ),
                    const SizedBox(height: 16),

                    // Fecha Límite
                    GestureDetector(
                      onTap: _pickDeadline,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: _selectedDeadline != null
                              ? Border.all(color: accentColor.withValues(alpha: 0.5), width: 1)
                              : null,
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, color: accentColor, size: 18),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _selectedDeadline != null
                                    ? "Fecha límite: ${_selectedDeadline!.day}/${_selectedDeadline!.month}/${_selectedDeadline!.year}"
                                    : "Agregar fecha límite (opcional)",
                                style: TextStyle(
                                  color: _selectedDeadline != null ? txtColor : hintColor,
                                  fontSize: 14,
                                  fontWeight: _selectedDeadline != null ? FontWeight.w500 : FontWeight.normal,
                                ),
                              ),
                            ),
                            if (_selectedDeadline != null)
                              GestureDetector(
                                onTap: () => setState(() => _selectedDeadline = null),
                                child: Icon(Icons.close, size: 18, color: hintColor),
                              ),
                          ],
                        ),
                      ),
                    ),

                    // Savings Tip
                    if (savingsTip != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          savingsTip,
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 28),

                    // ─── BLOQUE 3: LA BÓVEDA (CUENTA DESTINO) ───
                    _buildSectionLabel("La Bóveda", Icons.lock_outline, txtColor),
                    const SizedBox(height: 8),
                    Text(
                      "¿En qué cuenta guardarás el dinero para esta meta?",
                      style: TextStyle(color: hintColor, fontSize: 12),
                    ),
                    const SizedBox(height: 12),

                    if (accounts.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning_amber, color: Colors.redAccent, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text("No tienes cuentas. Crea una primero.",
                                  style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonFormField<int>(
                          initialValue: accounts.any((a) => a.id == _selectedAccountId)
                              ? _selectedAccountId
                              : accounts.first.id,
                          isExpanded: true,
                          dropdownColor: isDarkMode ? const Color(0xFF1E2435) : Colors.white,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          items: accounts.map((acc) {
                            return DropdownMenuItem<int>(
                              value: acc.id,
                              child: Row(
                                children: [
                                  Icon(
                                    IconData(acc.iconCode, fontFamily: 'MaterialIcons'),
                                    size: 20,
                                    color: Color(acc.colorValue),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      "${acc.name} (${acc.currencySymbol} ${acc.currentBalance.toStringAsFixed(2)})",
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 14, color: txtColor),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedAccountId = val);
                            }
                          },
                          validator: (val) => val == null ? "Selecciona una cuenta" : null,
                        ),
                      ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            // Action Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saveGoal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 6,
                  shadowColor: accentColor.withValues(alpha: 0.4),
                ),
                child: Text(
                  widget.goalToEdit == null ? "🚀 Crear Meta" : "💾 Guardar Cambios",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String title, IconData icon, Color txtColor) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: (_customColor ?? const Color(0xFF00E5FF)).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: _customColor ?? const Color(0xFF00E5FF)),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: txtColor,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(height: 1, color: Colors.grey.withValues(alpha: 0.2)),
        ),
      ],
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
    required Color accentColor,
    bool isNumber = false,
    ValueChanged<String>? onChanged,
  }) {
    return SizedBox(
      height: 52,
      child: TextFormField(
        controller: controller,
        style: TextStyle(color: txtColor, fontSize: 14),
        keyboardType: isNumber
            ? const TextInputType.numberWithOptions(decimal: true)
            : null,
        inputFormatters: isNumber
            ? [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))]
            : null,
        textAlignVertical: TextAlignVertical.center,
        onChanged: onChanged,
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
            borderSide: BorderSide(color: accentColor, width: 1.5),
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
        validator: (v) => v == null || v.isEmpty ? "" : null,
      ),
    );
  }
}
