import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../../domain/entities/reminder.dart';
import '../../../providers/reminder_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../../../core/constants/app_categories.dart';
import '../../../../core/constants/app_currencies.dart';

class ReminderFormSheet extends StatefulWidget {
  final Reminder? existingReminder;

  const ReminderFormSheet({super.key, this.existingReminder});

  @override
  State<ReminderFormSheet> createState() => _ReminderFormSheetState();
}

class _ReminderFormSheetState extends State<ReminderFormSheet> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();

  ReminderType _selectedType = ReminderType.payment;
  String? _selectedCurrency;
  int? _selectedCategoryId;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  ReminderRecurrence _selectedRecurrence = ReminderRecurrence.none;

  @override
  void initState() {
    super.initState();

    if (widget.existingReminder != null) {
      final r = widget.existingReminder!;
      _titleController.text = r.title;
      _descriptionController.text = r.description ?? '';
      _amountController.text = r.amount?.toString() ?? '';
      _selectedType = r.type;
      _selectedCurrency = r.currencyCode;
      _selectedCategoryId = r.categoryId;
      _selectedDate = r.date;
      _selectedTime = TimeOfDay(hour: r.hour, minute: r.minute);
      _selectedRecurrence = r.recurrence;
    } else {
      _selectedCategoryId = AppCategories.expenseCategories.keys.first;
    }

    _amountController.addListener(_onAmountChanged);
  }

  void _onAmountChanged() {
    if (_amountController.text.isNotEmpty && _selectedCurrency == null) {
      final walletProvider =
          Provider.of<WalletProvider>(context, listen: false);
      setState(() {
        // Find currency from symbol
        final currentSymbol = walletProvider.currencySymbol;
        final c = AppCurrencies.fromSymbol(currentSymbol);
        _selectedCurrency = c.code;
      });
    }
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _titleController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _saveReminder() async {
    if (!_formKey.currentState!.validate()) return;

    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final description = _descriptionController.text.trim();
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);

    if (amount != null && amount > 0 && _selectedCurrency == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Por favor selecciona una moneda si ingresas un monto')),
      );
      return;
    }

    final provider = Provider.of<ReminderProvider>(context, listen: false);
    final now = DateTime.now();

    Reminder reminder;

    if (widget.existingReminder != null) {
      reminder = widget.existingReminder!.copyWith(
        title: title,
        description: description.isEmpty ? null : description,
        type: _selectedType,
        amount: amount,
        currencyCode: amount != null ? _selectedCurrency : null,
        categoryId: _selectedCategoryId,
        date: _selectedDate,
        hour: _selectedTime.hour,
        minute: _selectedTime.minute,
        recurrence: _selectedRecurrence,
        updatedAt: now,
      );
      await provider.updateReminder(reminder);
    } else {
      reminder = Reminder(
        id: const Uuid().v4(),
        title: title,
        description: description.isEmpty ? null : description,
        type: _selectedType,
        amount: amount,
        currencyCode: amount != null ? _selectedCurrency : null,
        categoryId: _selectedCategoryId,
        date: _selectedDate,
        hour: _selectedTime.hour,
        minute: _selectedTime.minute,
        recurrence: _selectedRecurrence,
        createdAt: now,
        updatedAt: now,
      );
      await provider.createReminder(reminder);
    }

    if (mounted) {
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

    final availableCategories = _selectedType == ReminderType.income
        ? AppCategories.incomeCategories
        : AppCategories.expenseCategories;

    if (!availableCategories.containsKey(_selectedCategoryId) &&
        _selectedType != ReminderType.general) {
      _selectedCategoryId = availableCategories.keys.first;
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                  widget.existingReminder != null
                      ? "Editar Recordatorio"
                      : "Nuevo Recordatorio",
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: txtColor),
                ),
                const SizedBox(height: 20),

                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Type Selector
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
                              _buildTypeOption(
                                  "Pago", ReminderType.payment, isDarkMode),
                              _buildTypeOption(
                                  "Ingreso", ReminderType.income, isDarkMode),
                              _buildTypeOption(
                                  "General", ReminderType.general, isDarkMode),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Title
                        _buildTextField(
                          controller: _titleController,
                          label: "Título *",
                          icon: Icons.title,
                          cardColor: cardColor,
                          txtColor: txtColor,
                          hintColor: hintColor,
                          validator: (v) =>
                              v!.trim().isEmpty ? "Requerido" : null,
                        ),
                        const SizedBox(height: 12),

                        // Description
                        _buildTextField(
                          controller: _descriptionController,
                          label: "Descripción (Opcional)",
                          icon: Icons.notes,
                          cardColor: cardColor,
                          txtColor: txtColor,
                          hintColor: hintColor,
                        ),
                        const SizedBox(height: 24),

                        // Amount and Currency
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: _buildTextField(
                                controller: _amountController,
                                label: "Monto",
                                icon: Icons.attach_money,
                                cardColor: cardColor,
                                txtColor: txtColor,
                                hintColor: hintColor,
                                isNumber: true,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 1,
                              child: Container(
                                height: 50,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedCurrency,
                                    hint: Text('Moneda',
                                        style: TextStyle(
                                            color: hintColor, fontSize: 13)),
                                    dropdownColor: backgroundColor,
                                    icon: Icon(Icons.keyboard_arrow_down,
                                        color: txtColor),
                                    isExpanded: true,
                                    items: AppCurrencies.all.map((c) {
                                      return DropdownMenuItem<String>(
                                        value: c.code,
                                        child: Text('${c.code} (${c.symbol})',
                                            style: TextStyle(
                                                color: txtColor, fontSize: 13)),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      setState(() => _selectedCurrency = val);
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Category
                        if (_selectedType != ReminderType.general) ...[
                          Text("Categoría",
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: txtColor)),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 4),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButton<int>(
                              value: _selectedCategoryId,
                              isExpanded: true,
                              underline: const SizedBox(),
                              dropdownColor: backgroundColor,
                              icon: Icon(Icons.keyboard_arrow_down,
                                  color: txtColor),
                              items: availableCategories.entries.map((entry) {
                                return DropdownMenuItem<int>(
                                  value: entry.key,
                                  child: Row(
                                    children: [
                                      Icon(AppCategories.getIcon(entry.key),
                                          size: 20,
                                          color: Color(
                                              entry.value['color'] as int)),
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
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Date and Time
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Fecha *",
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: txtColor)),
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: _selectedDate,
                                        firstDate: DateTime(2000),
                                        lastDate: DateTime(2100),
                                      );
                                      if (picked != null) {
                                        setState(() => _selectedDate = picked);
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14, horizontal: 16),
                                      decoration: BoxDecoration(
                                        color: cardColor,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                              "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}",
                                              style: TextStyle(
                                                  color: txtColor,
                                                  fontSize: 14)),
                                          const Icon(Icons.calendar_today,
                                              color: Color(0xFF00E5FF),
                                              size: 18),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Hora *",
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: txtColor)),
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onTap: () async {
                                      final picked = await showTimePicker(
                                        context: context,
                                        initialTime: _selectedTime,
                                      );
                                      if (picked != null) {
                                        setState(() => _selectedTime = picked);
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14, horizontal: 16),
                                      decoration: BoxDecoration(
                                        color: cardColor,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(_selectedTime.format(context),
                                              style: TextStyle(
                                                  color: txtColor,
                                                  fontSize: 14)),
                                          const Icon(Icons.access_time,
                                              color: Color(0xFF00E5FF),
                                              size: 18),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Recurrence
                        Text("Recurrencia *",
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: txtColor)),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButton<ReminderRecurrence>(
                            value: _selectedRecurrence,
                            isExpanded: true,
                            underline: const SizedBox(),
                            dropdownColor: backgroundColor,
                            icon: Icon(Icons.keyboard_arrow_down,
                                color: txtColor),
                            items: [
                              const DropdownMenuItem(
                                  value: ReminderRecurrence.none,
                                  child: Text('Una vez')),
                              const DropdownMenuItem(
                                  value: ReminderRecurrence.daily,
                                  child: Text('Diario')),
                              const DropdownMenuItem(
                                  value: ReminderRecurrence.weekly,
                                  child: Text('Semanal')),
                              const DropdownMenuItem(
                                  value: ReminderRecurrence.monthly,
                                  child: Text('Mensual')),
                              const DropdownMenuItem(
                                  value: ReminderRecurrence.yearly,
                                  child: Text('Anual')),
                            ].map((item) {
                              return DropdownMenuItem<ReminderRecurrence>(
                                value: item.value,
                                child: Text((item.child as Text).data!,
                                    style: TextStyle(color: txtColor)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedRecurrence = val);
                              }
                            },
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
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _saveReminder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5FF),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
                      elevation: 4,
                      shadowColor:
                          const Color(0xFF00E5FF).withValues(alpha: 0.4),
                    ),
                    child: Text(
                      widget.existingReminder != null
                          ? "Actualizar Recordatorio"
                          : "Crear Recordatorio",
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeOption(String label, ReminderType val, bool isDarkMode) {
    final isSelected = _selectedType == val;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedType = val;
            if (val == ReminderType.general) {
              _selectedCategoryId = null;
            } else {
              _selectedCategoryId = val == ReminderType.income
                  ? AppCategories.incomeCategories.keys.first
                  : AppCategories.expenseCategories.keys.first;
            }
          });
        },
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData? icon,
    required Color cardColor,
    required Color txtColor,
    required Color hintColor,
    bool isNumber = false,
    String? Function(String?)? validator,
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
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF00E5FF), width: 1.5),
          ),
          prefixIcon:
              icon != null ? Icon(icon, color: hintColor, size: 18) : null,
        ),
        validator: validator,
      ),
    );
  }
}
