import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../domain/entities/account_entity.dart';
import '../../../providers/wallet_provider.dart';

class AddAccountSheet extends StatefulWidget {
  final AccountEntity? accountToEdit;

  const AddAccountSheet({super.key, this.accountToEdit});

  @override
  State<AddAccountSheet> createState() => _AddAccountSheetState();
}

class _AddAccountSheetState extends State<AddAccountSheet> {
  late TextEditingController _nameController;
  late TextEditingController _balanceController;

  late int _selectedIconCode;
  late int _selectedColorValue;
  late String _selectedCurrency;
  late bool _includeInTotal;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.accountToEdit?.name);
    _balanceController = TextEditingController(
        text: widget.accountToEdit?.currentBalance.toStringAsFixed(2));

    _selectedIconCode =
        widget.accountToEdit?.iconCode ?? Icons.account_balance.codePoint;
    _selectedColorValue =
        widget.accountToEdit?.colorValue ?? Colors.blueAccent.value;

    // We need context to get default currency, but initState doesn't have it easily without listen: false in build or post frame.
    // We'll initialize selectedCurrency in didChangeDependencies or just use a default and update if needed,
    // or access Provider in build.
    _selectedCurrency = widget.accountToEdit?.currencySymbol ?? 'S/';
    _includeInTotal = widget.accountToEdit?.includeInTotal ?? true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.accountToEdit == null) {
      final provider = Provider.of<WalletProvider>(context, listen: false);
      if (_selectedCurrency == 'S/') {
        // Only override if it's the default and we are adding new
        _selectedCurrency = provider.currencySymbol;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final subTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final inputFillColor =
        isDarkMode ? const Color(0xFF0F172A) : Colors.grey[100];
    final sheetColor = isDarkMode ? const Color(0xFF1E2435) : Colors.white;

    final icons = [
      Icons.account_balance,
      Icons.credit_card,
      Icons.money,
      Icons.wallet,
      Icons.smartphone,
      Icons.qr_code,
      Icons.savings,
      Icons.lock,
      Icons.flight,
      Icons.currency_bitcoin,
      Icons.show_chart,
      Icons.diamond,
      Icons.home,
      Icons.directions_car,
    ];

    final colors = [
      Colors.blueAccent,
      Colors.green,
      Colors.purple,
      Colors.orange,
      Colors.pink,
      Colors.teal,
    ];

    return Container(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 20),
      decoration: BoxDecoration(
        color: sheetColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                    widget.accountToEdit == null
                        ? "Nueva Cuenta"
                        : "Editar Cuenta",
                    style: TextStyle(
                        color: textColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
                if (widget.accountToEdit != null)
                  IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _handleDelete(context)),
              ],
            ),
            const SizedBox(height: 20),

            // Name Input
            TextField(
              controller: _nameController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: "Nombre de la cuenta",
                labelStyle: TextStyle(color: subTextColor),
                filled: true,
                fillColor: inputFillColor,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: isDarkMode
                        ? BorderSide.none
                        : BorderSide(color: Colors.grey.shade300)),
              ),
            ),
            const SizedBox(height: 15),

            // Balance & Currency Row
            Container(
              decoration: BoxDecoration(
                color: inputFillColor,
                borderRadius: BorderRadius.circular(16),
                border: !isDarkMode
                    ? Border.all(color: Colors.grey.shade300)
                    : null,
              ),
              child: Row(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _showCurrencyPicker(context),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_selectedCurrency,
                                style: TextStyle(
                                    color: isDarkMode
                                        ? Colors.cyanAccent
                                        : Colors.cyan.shade800,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900)),
                            const SizedBox(width: 8),
                            Icon(Icons.swap_horiz,
                                color:
                                    isDarkMode ? Colors.white54 : Colors.grey,
                                size: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(
                      width: 1,
                      height: 24,
                      color: Colors.grey.withOpacity(0.3)),
                  Expanded(
                    child: TextField(
                      controller: _balanceController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: textColor, fontSize: 18),
                      decoration: InputDecoration(
                        hintText: "Saldo Inicial",
                        hintStyle: TextStyle(color: subTextColor),
                        filled: false,
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Icon Selector
            Text("Icono", style: TextStyle(color: subTextColor)),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Row(
                children: icons.map((icon) {
                  final isSelected = icon.codePoint == _selectedIconCode;
                  return GestureDetector(
                    onTap: () =>
                        setState(() => _selectedIconCode = icon.codePoint),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.cyan.withOpacity(0.2)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border:
                            isSelected ? Border.all(color: Colors.cyan) : null,
                      ),
                      child: Icon(icon,
                          color: isSelected ? Colors.cyan : Colors.grey,
                          size: 28),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            // Color Selector
            Text("Color", style: TextStyle(color: subTextColor)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: colors.map((color) {
                final isSelected = color.value == _selectedColorValue;
                return GestureDetector(
                  onTap: () =>
                      setState(() => _selectedColorValue = color.value),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Colors.white, width: 3)
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Include in Total Switch
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: Colors.cyan,
              title: Text("Incluir en Saldo Disponible",
                  style: TextStyle(color: textColor)),
              subtitle: const Text(
                "Si lo desactivas, este dinero no aparecerá en la pantalla de inicio.",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              value: _includeInTotal,
              secondary: Icon(
                _includeInTotal ? Icons.visibility : Icons.visibility_off,
                color: Colors.grey,
              ),
              onChanged: (val) => setState(() => _includeInTotal = val),
            ),

            const SizedBox(height: 30),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saveAccount,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Color(_selectedColorValue)),
                child: const Text("Guardar Cuenta",
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCurrencyPicker(BuildContext context) {
    showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF0F172A),
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
        builder: (ctx) {
          final currencies = [
            {'symbol': 'S/', 'name': 'Sol', 'code': 'PEN'},
            {'symbol': '\$', 'name': 'Dólar', 'code': 'USD'},
            {'symbol': '€', 'name': 'Euro', 'code': 'EUR'},
            {'symbol': '¥', 'name': 'Yen', 'code': 'JPY'},
            {'symbol': '₽', 'name': 'Rublo', 'code': 'RUB'},
          ];

          return Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text("Selecciona la Divisa",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 120,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    itemCount: currencies.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final currency = currencies[index];
                      final isSelected =
                          _selectedCurrency == currency['symbol'];
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedCurrency = currency['symbol']!;
                          });
                          Navigator.pop(ctx);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 100,
                          decoration: BoxDecoration(
                            color: isSelected ? null : const Color(0xFF1E293B),
                            gradient: isSelected
                                ? const LinearGradient(
                                    colors: [Colors.cyan, Colors.blueAccent],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight)
                                : null,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: isSelected
                                    ? Colors.cyanAccent
                                    : Colors.grey[800]!,
                                width: isSelected ? 0 : 1),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                currency['symbol']!,
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                currency['name']!,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? Colors.white.withOpacity(0.9)
                                      : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        });
  }

  void _saveAccount() {
    final name = _nameController.text.trim();
    final balanceInput = double.tryParse(_balanceController.text) ?? 0.0;

    if (name.isNotEmpty) {
      final isUpdate = widget.accountToEdit != null;
      final id = widget.accountToEdit?.id ??
          (DateTime.now().millisecondsSinceEpoch & 0xFFFFFFFF);

      final account = AccountEntity(
          id: id,
          name: name,
          initialBalance: balanceInput,
          currencySymbol: _selectedCurrency,
          colorValue: _selectedColorValue,
          iconCode: _selectedIconCode,
          includeInTotal: _includeInTotal,
          currentBalance: balanceInput);

      final provider = Provider.of<WalletProvider>(context, listen: false);

      if (isUpdate) {
        provider.updateAccount(account);
      } else {
        provider.createAccount(account);
      }
      Navigator.pop(context);
    }
  }

  void _handleDelete(BuildContext context) {
    Navigator.pop(context); // Close sheet
    if (widget.accountToEdit == null) return;

    final provider = Provider.of<WalletProvider>(context, listen: false);
    final account = widget.accountToEdit!;

    provider.softDeleteAccount(account);

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(
          content: Text("Cuenta '${account.name}' eliminada."),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
              label: "DESHACER",
              textColor: Colors.cyanAccent,
              onPressed: () {
                provider.undoDeleteAccount(account);
              }),
        ))
        .closed
        .then((reason) {
      if (reason != SnackBarClosedReason.action) {
        provider.confirmDeleteAccount(account.id);
      }
    });
  }
}
