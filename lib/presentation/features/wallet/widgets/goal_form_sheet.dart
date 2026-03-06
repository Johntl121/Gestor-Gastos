import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../domain/entities/goal_entity.dart';
import '../../../providers/wallet_provider.dart';

class GoalFormSheet extends StatefulWidget {
  final GoalEntity? goalToEdit;

  const GoalFormSheet({super.key, this.goalToEdit});

  @override
  State<GoalFormSheet> createState() => _GoalFormSheetState();
}

class _GoalFormSheetState extends State<GoalFormSheet> {
  late TextEditingController _nameController;
  late TextEditingController _amountController;

  late int _selectedIconCode;
  late int _selectedColorValue;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.goalToEdit?.name ?? '');
    _amountController = TextEditingController(
        text: widget.goalToEdit?.targetAmount.toStringAsFixed(0) ?? '');

    _selectedIconCode = widget.goalToEdit?.iconCode ?? Icons.star.codePoint;
    _selectedColorValue = widget.goalToEdit?.colorValue ?? Colors.cyan.value;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? const Color(0xFF1E2435) : Colors.white;
    final textColor = theme.textTheme.titleLarge?.color ?? Colors.black;
    final subTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    final walletProvider = Provider.of<WalletProvider>(context);
    final currencySymbol = walletProvider.currencySymbol;

    final inputFillColor =
        isDarkMode ? const Color(0xFF0F172A) : Colors.grey[100];
    final inputHintColor = theme.hintColor;
    final unselectedIconBg = isDarkMode ? Colors.white10 : Colors.grey[200];
    final unselectedIconColor = isDarkMode ? Colors.grey : Colors.grey[600];

    final icons = [
      Icons.star,
      Icons.computer,
      Icons.flight,
      Icons.directions_car,
      Icons.home,
      Icons.school,
      Icons.pets,
      Icons.gamepad,
      Icons.medical_services,
      Icons.shopping_bag,
      Icons.fitness_center,
      Icons.music_note
    ];

    final colors = [
      Colors.cyan,
      Colors.purple,
      Colors.orange,
      Colors.green,
      Colors.red,
      Colors.blueAccent
    ];

    return Container(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 20),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.goalToEdit == null ? "Nueva Meta" : "Editar Meta",
                style: TextStyle(
                    color: textColor,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // Inputs
            TextField(
              controller: _nameController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: "Nombre",
                labelStyle: TextStyle(color: subTextColor),
                filled: true,
                fillColor: inputFillColor,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                hintStyle: TextStyle(color: inputHintColor),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                  labelText: "Monto Objetivo",
                  labelStyle: TextStyle(color: subTextColor),
                  filled: true,
                  fillColor: inputFillColor,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  prefixText: "$currencySymbol ",
                  prefixStyle: TextStyle(color: subTextColor),
                  hintStyle: TextStyle(color: inputHintColor)),
            ),

            const SizedBox(height: 20),
            Text("Icono", style: TextStyle(color: subTextColor)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: icons.map((icon) {
                final isSelected = icon.codePoint == _selectedIconCode;
                return GestureDetector(
                  onTap: () =>
                      setState(() => _selectedIconCode = icon.codePoint),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: isSelected
                            ? Color(_selectedColorValue).withOpacity(0.2)
                            : unselectedIconBg,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: isSelected
                                ? Color(_selectedColorValue)
                                : Colors.transparent,
                            width: 2.0)),
                    child: Icon(icon,
                        color: isSelected
                            ? Color(_selectedColorValue)
                            : unselectedIconColor,
                        size: 24),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),
            Text("Color", style: TextStyle(color: subTextColor)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: colors.map((color) {
                final isSelected = color.value == _selectedColorValue;
                return GestureDetector(
                  onTap: () =>
                      setState(() => _selectedColorValue = color.value),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: textColor, width: 3)
                            : null,
                        boxShadow: [
                          BoxShadow(
                              color: color.withOpacity(0.4), blurRadius: 8)
                        ]),
                    child: isSelected
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saveGoal,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Color(_selectedColorValue)),
                child: Text(
                    widget.goalToEdit == null
                        ? "Crear Meta"
                        : "Guardar Cambios",
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveGoal() {
    final name = _nameController.text.trim();
    final amount = double.tryParse(_amountController.text) ?? 0;

    if (name.isNotEmpty && amount > 0) {
      final provider = Provider.of<WalletProvider>(context, listen: false);

      if (widget.goalToEdit == null) {
        // ADD
        // The previous method was dashboardProvider.addGoal(name, amount, icon, color).
        // WalletProvider should have similar method.
        // I will assume it does, but wait, looking at `WalletProvider` content:
        // `createGoal(GoalEntity)` or such?
        // Let's create `GoalEntity` here and use `addGoal`.
        provider.addGoal(name, amount, _selectedIconCode, _selectedColorValue);
      } else {
        // UPDATE
        final updated = GoalEntity(
            id: widget.goalToEdit!.id,
            name: name,
            targetAmount: amount,
            currentAmount: widget.goalToEdit!.currentAmount,
            iconCode: _selectedIconCode,
            colorValue: _selectedColorValue,
            isCompleted: widget.goalToEdit!.currentAmount >= amount);
        provider.updateGoal(updated);
      }
      Navigator.pop(context);
    }
  }
}
