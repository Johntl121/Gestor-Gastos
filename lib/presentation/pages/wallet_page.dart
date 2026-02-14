import 'dart:ui'; // For lerpDouble
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:provider/provider.dart';
import '../../core/services/notification_service.dart';
import '../providers/dashboard_provider.dart';
import '../../domain/entities/goal_entity.dart';
import '../../domain/entities/account_entity.dart'; // Import
import '../../data/models/subscription.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  // Flag to lock scroll during reordering to prevent "running away"
  bool _isDragging = false;

  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  // --- DIALOGS & ACTIONS ---

  void _showGoalFormDialog(BuildContext context, {GoalEntity? toEdit}) {
    final nameController = TextEditingController(text: toEdit?.name ?? '');
    final amountController = TextEditingController(
        text: toEdit?.targetAmount.toStringAsFixed(0) ?? '');

    // Default Values
    int selectedIconCode = toEdit?.iconCode ?? Icons.star.codePoint;
    int selectedColorValue = toEdit?.colorValue ?? Colors.cyan.value;

    final List<IconData> icons = [
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

    final List<Color> colors = [
      Colors.cyan,
      Colors.purple,
      Colors.orange,
      Colors.green,
      Colors.red,
      Colors.blueAccent
    ];

    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final backgroundColor = theme.cardColor;
    final textColor = theme.textTheme.titleLarge?.color ?? Colors.black;
    final subTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final inputFillColor =
        isDarkMode ? const Color(0xFF0F172A) : Colors.grey[100];
    final inputHintColor = theme.hintColor;
    final unselectedIconBg = isDarkMode ? Colors.white10 : Colors.grey[200];
    final unselectedIconColor = isDarkMode ? Colors.grey : Colors.grey[600];

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: backgroundColor,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (ctx) => StatefulBuilder(builder: (context, setState) {
              return Padding(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                    left: 20,
                    right: 20,
                    top: 20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(toEdit == null ? "Nueva Meta" : "Editar Meta",
                          style: TextStyle(
                              color: textColor,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),

                      // Inputs
                      TextField(
                        controller: nameController,
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
                        controller: amountController,
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
                            prefixText: "S/ ",
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
                          final isSelected = icon.codePoint == selectedIconCode;
                          return GestureDetector(
                            onTap: () => setState(
                                () => selectedIconCode = icon.codePoint),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                  color: isSelected
                                      ? Color(selectedColorValue)
                                          .withOpacity(0.2)
                                      : unselectedIconBg,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: isSelected
                                          ? Color(selectedColorValue)
                                          : Colors.transparent,
                                      width:
                                          2.0 // Fixed width to prevent jumping
                                      )),
                              child: Icon(icon,
                                  color: isSelected
                                      ? Color(selectedColorValue)
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
                          final isSelected = color.value == selectedColorValue;
                          return GestureDetector(
                            onTap: () => setState(() {
                              selectedColorValue = color.value;
                              // Also update icon selection visual immediately if needed
                            }),
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
                                        color: color.withOpacity(0.4),
                                        blurRadius: 8)
                                  ]),
                              child: isSelected
                                  ? const Icon(Icons.check,
                                      size: 16, color: Colors.white)
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
                          onPressed: () {
                            final name = nameController.text.trim();
                            final amount =
                                double.tryParse(amountController.text) ?? 0;

                            if (name.isNotEmpty && amount > 0) {
                              final provider = Provider.of<DashboardProvider>(
                                  context,
                                  listen: false);

                              if (toEdit == null) {
                                // ADD
                                provider.addGoal(name, amount, selectedIconCode,
                                    selectedColorValue);
                              } else {
                                // UPDATE
                                // Preserve current amount and completion status logic (or re-calc)
                                // If target changes, completion might change, so let's preserve currentAmount but re-eval completion in provider if we want,
                                // but Entity is immutable here, so we recreate.
                                final updated = GoalEntity(
                                    id: toEdit.id,
                                    name: name,
                                    targetAmount: amount,
                                    currentAmount: toEdit.currentAmount,
                                    iconCode: selectedIconCode,
                                    colorValue: selectedColorValue,
                                    isCompleted:
                                        toEdit.currentAmount >= amount);
                                provider.updateGoal(updated);
                              }
                              Navigator.pop(ctx);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Color(selectedColorValue)),
                          child: Text(
                              toEdit == null ? "Crear Meta" : "Guardar Cambios",
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }));
  }

  void _showAddAccountSheet(BuildContext context,
      {AccountEntity? accountToEdit}) {
    final nameController = TextEditingController(text: accountToEdit?.name);
    final balanceController = TextEditingController(
        text: accountToEdit?.currentBalance.toStringAsFixed(2));

    // Theme Logic
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final subTextColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final inputFillColor =
        isDarkMode ? const Color(0xFF0F172A) : Colors.grey[100];
    final sheetColor = theme.cardColor;

    // Default Values
    int selectedIconCode =
        accountToEdit?.iconCode ?? Icons.account_balance.codePoint;
    int selectedColorValue =
        accountToEdit?.colorValue ?? Colors.blueAccent.value;
    String selectedCurrency = accountToEdit?.currencySymbol ??
        Provider.of<DashboardProvider>(context, listen: false).currencySymbol;
    bool includeInTotal = accountToEdit?.includeInTotal ?? true;

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

    // Basic Colors
    final colors = [
      Colors.blueAccent,
      Colors.green,
      Colors.purple,
      Colors.orange,
      Colors.pink,
      Colors.teal,
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: sheetColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(builder: (context, setState) {
        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              left: 20,
              right: 20,
              top: 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ... (Title, Name, Balance, Currency, Icon, Color)

                // Title Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                        accountToEdit == null
                            ? "Nueva Cuenta"
                            : "Editar Cuenta",
                        style: TextStyle(
                            color: textColor,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    if (accountToEdit != null)
                      IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            // DELETE LOGIC
                            Navigator.pop(ctx);
                            final provider = Provider.of<DashboardProvider>(
                                context,
                                listen: false);
                            provider.softDeleteAccount(accountToEdit);

                            ScaffoldMessenger.of(context)
                                .showSnackBar(SnackBar(
                                  content: Text(
                                      "Cuenta '${accountToEdit.name}' eliminada."),
                                  duration: const Duration(seconds: 4),
                                  action: SnackBarAction(
                                      label: "DESHACER",
                                      textColor: Colors.cyanAccent,
                                      onPressed: () {
                                        provider
                                            .undoDeleteAccount(accountToEdit);
                                      }),
                                ))
                                .closed
                                .then((reason) {
                              if (reason != SnackBarClosedReason.action) {
                                provider.confirmDeleteAccount(accountToEdit.id);
                              }
                            });
                          }),
                  ],
                ),
                const SizedBox(height: 20),

                // Name Input
                TextField(
                  controller: nameController,
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
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: balanceController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          labelText: "Saldo Inicial",
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
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 1,
                      child: GestureDetector(
                        onTap: () {
                          showModalBottomSheet(
                              context: context,
                              backgroundColor: const Color(0xFF0F172A),
                              shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(25))),
                              builder: (ctx) {
                                final currencies = [
                                  {
                                    'symbol': 'S/',
                                    'name': 'Sol',
                                    'code': 'PEN'
                                  },
                                  {
                                    'symbol': '\$',
                                    'name': 'Dólar',
                                    'code': 'USD'
                                  },
                                  {
                                    'symbol': '€',
                                    'name': 'Euro',
                                    'code': 'EUR'
                                  },
                                  {'symbol': '¥', 'name': 'Yen', 'code': 'JPY'},
                                  {
                                    'symbol': '₽',
                                    'name': 'Rublo',
                                    'code': 'RUB'
                                  },
                                ];

                                return Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 24),
                                  decoration: const BoxDecoration(
                                      color: Color(
                                          0xFF0F172A), // Dark background for contrast
                                      borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(25))),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 20),
                                        child: Text("Selecciona la Divisa",
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                      const SizedBox(height: 20),
                                      ShaderMask(
                                        shaderCallback: (Rect bounds) {
                                          return const LinearGradient(
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                            colors: [
                                              Colors.white,
                                              Colors.white,
                                              Colors.transparent
                                            ],
                                            stops: [
                                              0.0,
                                              0.8,
                                              1.0
                                            ], // El desvanecido empieza al 80% del ancho
                                          ).createShader(bounds);
                                        },
                                        blendMode: BlendMode.dstIn,
                                        child: SizedBox(
                                          height: 120, // Altura del carrusel
                                          child: ListView.separated(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 20),
                                            scrollDirection: Axis.horizontal,
                                            itemCount: currencies.length,
                                            separatorBuilder: (_, __) =>
                                                const SizedBox(width: 12),
                                            itemBuilder: (context, index) {
                                              final currency =
                                                  currencies[index];
                                              final isSelected =
                                                  selectedCurrency ==
                                                      currency['symbol'];
                                              return GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    selectedCurrency =
                                                        currency['symbol']!;
                                                  });
                                                  Navigator.pop(ctx);
                                                },
                                                child: AnimatedContainer(
                                                  // Animación suave al cambiar
                                                  duration: const Duration(
                                                      milliseconds: 200),
                                                  width: 100,
                                                  decoration: BoxDecoration(
                                                    gradient: isSelected
                                                        ? const LinearGradient(
                                                            colors: [
                                                                Colors.cyan,
                                                                Colors
                                                                    .blueAccent
                                                              ],
                                                            begin: Alignment
                                                                .topLeft,
                                                            end: Alignment
                                                                .bottomRight)
                                                        : null,
                                                    color: isSelected
                                                        ? null
                                                        : const Color(
                                                            0xFF1E293B),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            16),
                                                    border: Border.all(
                                                        color: isSelected
                                                            ? Colors.cyanAccent
                                                            : Colors.grey[800]!,
                                                        width: isSelected
                                                            ? 0
                                                            : 1), // Sin borde si tiene gradiente o borde sutil
                                                    boxShadow: isSelected
                                                        ? [
                                                            BoxShadow(
                                                                color: Colors
                                                                    .cyan
                                                                    .withOpacity(
                                                                        0.4),
                                                                blurRadius: 10,
                                                                spreadRadius: 1)
                                                          ]
                                                        : [],
                                                  ),
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Text(
                                                        currency['symbol']!,
                                                        style: const TextStyle(
                                                          fontSize: 32,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors
                                                              .white, // Siempre blanco para contraste
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        currency['name']!,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight: isSelected
                                                              ? FontWeight.bold
                                                              : FontWeight
                                                                  .normal,
                                                          color: isSelected
                                                              ? Colors.white
                                                                  .withOpacity(
                                                                      0.9)
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
                                      ),
                                      const SizedBox(height: 10),
                                    ],
                                  ),
                                );
                              });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            color: inputFillColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: isDarkMode
                                    ? Colors.grey
                                    : Colors.grey.shade300),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(selectedCurrency,
                                  style: TextStyle(
                                      color: textColor,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              Icon(Icons.arrow_drop_down, color: textColor),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
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
                      final isSelected = icon.codePoint == selectedIconCode;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => selectedIconCode = icon.codePoint),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.cyan.withOpacity(0.2)
                                : Colors.transparent,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: Colors.cyan)
                                : null,
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
                    final isSelected = color.value == selectedColorValue;
                    return GestureDetector(
                      onTap: () =>
                          setState(() => selectedColorValue = color.value),
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
                  value: includeInTotal,
                  secondary: Icon(
                    includeInTotal ? Icons.visibility : Icons.visibility_off,
                    color: Colors.grey,
                  ),
                  onChanged: (val) {
                    setState(() {
                      includeInTotal = val;
                    });
                  },
                ),

                const SizedBox(height: 30),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      final name = nameController.text.trim();
                      final balanceInput =
                          double.tryParse(balanceController.text) ?? 0.0;

                      if (name.isNotEmpty) {
                        final isUpdate = accountToEdit != null;
                        final id = accountToEdit?.id ??
                            (DateTime.now().millisecondsSinceEpoch &
                                0xFFFFFFFF);

                        final account = AccountEntity(
                            id: id,
                            name: name,
                            initialBalance: balanceInput,
                            currencySymbol: selectedCurrency,
                            colorValue: selectedColorValue,
                            iconCode: selectedIconCode,
                            includeInTotal: includeInTotal,
                            currentBalance: balanceInput);

                        if (isUpdate) {
                          Provider.of<DashboardProvider>(context, listen: false)
                              .updateAccount(account);
                        } else {
                          Provider.of<DashboardProvider>(context, listen: false)
                              .createAccount(account);
                        }
                        Navigator.pop(ctx);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Color(selectedColorValue)),
                    child: const Text("Guardar Cuenta",
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  void _showDepositDialog(BuildContext context, GoalEntity goal) {
    final amountController = TextEditingController();
    int selectedSource = 2; // Default Bank
    String? errorText;

    showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(builder: (context, setState) {
              return AlertDialog(
                backgroundColor: Theme.of(context).cardColor,
                title: Text("Depositar a ${goal.name}",
                    style: TextStyle(
                        color: Theme.of(context).textTheme.titleLarge?.color)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                      onChanged: (val) {
                        if (errorText != null) {
                          setState(() => errorText = null);
                        }
                      },
                      decoration: InputDecoration(
                          prefixText: "S/ ",
                          prefixStyle:
                              const TextStyle(color: Colors.cyan, fontSize: 24),
                          border: InputBorder.none,
                          hintText: "0.00",
                          hintStyle: const TextStyle(color: Colors.white30),
                          errorText: errorText, // Inline Error Display
                          errorStyle: const TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 20),
                    const Text("Desde:", style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 10),
                    Consumer<DashboardProvider>(
                      builder: (context, provider, _) {
                        // 1. Handle Empty State
                        if (provider.accounts.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text(
                              "No tienes cuentas registradas.",
                              style: TextStyle(color: Colors.redAccent),
                              textAlign: TextAlign.center,
                            ),
                          );
                        }

                        // 2. Validate Selection (Prevent Crash)
                        // If selectedSource (default 2) is not in the list, fallback to first available account
                        if (!provider.accounts
                            .any((a) => a.id == selectedSource)) {
                          final defaultAcc = provider.accounts.firstWhere(
                              (a) => a.id == 2,
                              orElse: () => provider.accounts.first);
                          selectedSource = defaultAcc.id;
                        }

                        // 3. Render Dropdown
                        return DropdownButtonFormField<int>(
                          isExpanded:
                              true, // IMPORTANT: Fixes Right Overflow and Flex errors
                          initialValue: selectedSource,
                          dropdownColor: Theme.of(context).cardColor,
                          style: TextStyle(
                              color:
                                  Theme.of(context).textTheme.bodyLarge?.color,
                              fontSize: 16),
                          decoration: InputDecoration(
                            labelText: "Debitar de / Origen",
                            labelStyle: const TextStyle(color: Colors.grey),
                            prefixIcon: const Icon(Icons.account_balance_wallet,
                                color: Colors.cyan),
                            filled: true,
                            fillColor:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white.withOpacity(0.05)
                                    : Colors.grey[100],
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none),
                          ),
                          items: provider.accounts.map((account) {
                            return DropdownMenuItem<int>(
                              value: account.id,
                              child: Row(
                                children: [
                                  Icon(
                                      IconData(account.iconCode,
                                          fontFamily: 'MaterialIcons'),
                                      size: 18,
                                      color: Color(account.colorValue)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      "${account.name} - ${account.currencySymbol} ${account.currentBalance.toStringAsFixed(2)}",
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => selectedSource = val);
                            }
                          },
                        );
                      },
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Cancelar",
                          style: TextStyle(color: Colors.grey))),
                  ElevatedButton(
                      onPressed: () {
                        final amount =
                            double.tryParse(amountController.text) ?? 0;
                        final remainingAmount =
                            goal.targetAmount - goal.currentAmount;

                        if (amount > 0) {
                          // Validation: Amount exceeds remaining
                          if (amount > remainingAmount) {
                            final currency = Provider.of<DashboardProvider>(
                                    context,
                                    listen: false)
                                .currencySymbol;

                            // Inline Error via setState
                            setState(() {
                              errorText =
                                  "Solo te faltan $currency ${remainingAmount.toStringAsFixed(2)}";
                            });
                            return; // Stop execution, keep dialog open
                          }

                          // Success: Process Deposit
                          if (amount >= remainingAmount) {
                            _confettiController.play();
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        "¡FELICIDADES! 🎉 Meta Completada",
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold)),
                                    backgroundColor: Colors.amber));
                          }

                          Provider.of<DashboardProvider>(context, listen: false)
                              .depositToGoal(goal.id, amount, selectedSource);

                          Navigator.pop(ctx); // Close Dialog
                          Navigator.pop(context); // Close Bottom Sheet
                        }
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green),
                      child: const Text("Depositar",
                          style: TextStyle(color: Colors.white)))
                ],
              );
            }));
  }

  void _confirmDeleteGoal(BuildContext context, GoalEntity goal) {
    if (goal.currentAmount > 0) {
      // 1. Pre-fetch and Validate Default Account
      final provider = Provider.of<DashboardProvider>(context, listen: false);
      int selectedRefundAccount = 2; // Default Attempt

      if (provider.accounts.isNotEmpty) {
        // If default 2 doesn't exist, pick first available
        if (!provider.accounts.any((a) => a.id == selectedRefundAccount)) {
          selectedRefundAccount = provider.accounts.first.id;
        }
      } else {
        // Edge case: No accounts at all.
        // We might want to warn user or just let them delete without refund if they really force it,
        // but for now let's assume valid state or they can't save.
        selectedRefundAccount = -1;
      }

      showDialog(
          context: context,
          builder: (ctx) => StatefulBuilder(builder: (context, setState) {
                return AlertDialog(
                  backgroundColor: Theme.of(context).cardColor,
                  title: Text(
                    "Eliminar Meta con Saldo",
                    style: TextStyle(
                        color: Theme.of(context).textTheme.titleLarge?.color),
                  ),
                  content: SizedBox(
                    width: double.maxFinite, // Fix for Layout Issues
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Esta meta tiene ahorrados S/ ${goal.currentAmount.toStringAsFixed(2)}. Selecciona una cuenta para devolver el dinero antes de eliminarla.",
                          style: TextStyle(
                              color:
                                  Theme.of(context).textTheme.bodyMedium?.color,
                              fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        if (selectedRefundAccount == -1)
                          const Text("No hay cuentas para devolver fondos.",
                              style: TextStyle(color: Colors.red))
                        else
                          DropdownButtonFormField<int>(
                            isExpanded: true,
                            initialValue: selectedRefundAccount,
                            items: provider.accounts.map((acc) {
                              return DropdownMenuItem<int>(
                                value: acc.id,
                                child: Row(
                                  children: [
                                    Icon(
                                        IconData(acc.iconCode,
                                            fontFamily: 'MaterialIcons'),
                                        size: 18,
                                        color: Color(acc.colorValue)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        "${acc.name} (${acc.currencySymbol} ${acc.currentBalance.toStringAsFixed(2)})",
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 14,
                                            color: Theme.of(context)
                                                .textTheme
                                                .bodyLarge
                                                ?.color),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => selectedRefundAccount = val);
                              }
                            },
                            decoration: InputDecoration(
                              labelText: "Devolver a:",
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                            ),
                          )
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text("Cancelar",
                            style: TextStyle(color: Colors.grey))),
                    ElevatedButton(
                        onPressed: () async {
                          final provider = Provider.of<DashboardProvider>(
                              context,
                              listen: false);
                          await provider.deleteGoal(goal.id,
                              refund: true,
                              refundAccountId: selectedRefundAccount);
                          Navigator.pop(ctx);
                          Navigator.pop(context); // Close Detail Sheet
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text(
                                  "Meta eliminada y dinero devuelto a la cuenta seleccionada"),
                              backgroundColor: Colors.green));
                        },
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent),
                        child: const Text("Eliminar y Devolver",
                            style: TextStyle(color: Colors.white)))
                  ],
                );
              }));
    } else {
      // Standard Delete (No funds)
      showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
                backgroundColor: Theme.of(context).cardColor,
                title: Text("¿Eliminar Meta?",
                    style: TextStyle(
                        color: Theme.of(context).textTheme.titleLarge?.color)),
                content: Text("Esta acción no se puede deshacer.",
                    style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Cancelar",
                          style: TextStyle(color: Colors.grey))),
                  ElevatedButton(
                      onPressed: () {
                        Provider.of<DashboardProvider>(context, listen: false)
                            .deleteGoal(goal.id);
                        Navigator.pop(ctx); // Close Dialog
                        Navigator.pop(context); // Close BottomSheet
                      },
                      style:
                          ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text("Eliminar",
                          style: TextStyle(color: Colors.white)))
                ],
              ));
    }
  }

  void _showGoalDetails(BuildContext context, GoalEntity goal) {
    showModalBottomSheet(
        context: context,
        backgroundColor: Theme.of(context).cardColor,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (ctx) {
          final progress =
              (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0);
          final isCompleted = progress >= 1.0;

          return Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with Edit
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 48), // Spacer
                    Icon(isCompleted ? Icons.emoji_events : goal.icon,
                        size: 64,
                        color: isCompleted ? Colors.amber : goal.color),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.grey),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showGoalFormDialog(context, toEdit: goal);
                      },
                    )
                  ],
                ),

                const SizedBox(height: 16),
                Text(goal.name,
                    style: TextStyle(
                        color: Theme.of(ctx).textTheme.headlineMedium?.color,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text("Progreso: ${(progress * 100).toInt()}%",
                    style: TextStyle(color: Colors.grey[400], fontSize: 16)),
                const SizedBox(height: 24),

                // Progress Bar
                Stack(
                  children: [
                    Container(
                        height: 12,
                        decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(6))),
                    Container(
                        height: 12,
                        width: MediaQuery.of(ctx).size.width * 0.8 * progress,
                        decoration: BoxDecoration(
                            color: isCompleted ? Colors.amber : goal.color,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: isCompleted
                                ? [
                                    BoxShadow(
                                        color: Colors.amber.withOpacity(0.6),
                                        blurRadius: 10)
                                  ]
                                : null)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("S/ ${goal.currentAmount.toStringAsFixed(2)}",
                        style: const TextStyle(color: Colors.white70)),
                    Text("Meta: S/ ${goal.targetAmount.toStringAsFixed(2)}",
                        style: const TextStyle(color: Colors.white70)),
                  ],
                ),
                const SizedBox(height: 40),

                // Actions
                if (isCompleted) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: () {
                        // Confirm Purchase
                        showDialog(
                            context: context,
                            builder: (c) => AlertDialog(
                                  backgroundColor: const Color(0xFF1E293B),
                                  title: const Text("¡Felicidades! 🎉",
                                      style: TextStyle(color: Colors.white)),
                                  content: Text(
                                      "¿Deseas registrar la compra de '${goal.name}' por S/ ${goal.targetAmount}?",
                                      style: const TextStyle(
                                          color: Colors.white70)),
                                  actions: [
                                    TextButton(
                                        onPressed: () => Navigator.pop(c),
                                        child: const Text("Rechazar",
                                            style:
                                                TextStyle(color: Colors.grey))),
                                    ElevatedButton(
                                        onPressed: () {
                                          Provider.of<DashboardProvider>(
                                                  context,
                                                  listen: false)
                                              .purchaseGoal(goal.id);
                                          Navigator.pop(c); // Dialog
                                          Navigator.pop(ctx); // BottomSheet
                                        },
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.amber),
                                        child: const Text("¡SÍ, COMPRAR!",
                                            style: TextStyle(
                                                color: Colors.black,
                                                fontWeight: FontWeight.bold)))
                                  ],
                                ));
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 10,
                          shadowColor: Colors.amber.withOpacity(0.5)),
                      child: const Text("¡COMPRAR AHORA!",
                          style: TextStyle(
                              color: Colors.black,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                      onPressed: () => _confirmDeleteGoal(context, goal),
                      child: const Text("Retirar dinero (Sin registrar gasto)",
                          style: TextStyle(
                              color: Colors.white70,
                              decoration: TextDecoration.underline)))
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      onPressed: () => _showDepositDialog(context, goal),
                      icon: const Icon(Icons.savings, color: Colors.white),
                      label: const Text("Depositar / Ahorrar",
                          style: TextStyle(color: Colors.white, fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16))),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () => _confirmDeleteGoal(context, goal),
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    label: const Text("Eliminar Meta",
                        style: TextStyle(color: Colors.redAccent)),
                  )
                ]
              ],
            ),
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, provider, child) {
        final goals = provider.goals;
        final theme = Theme.of(context);
        final isDarkMode = theme.brightness == Brightness.dark;
        final backgroundColor = theme.scaffoldBackgroundColor;
        final textColor = theme.textTheme.titleLarge?.color ?? Colors.black;

        return Scaffold(
          backgroundColor: backgroundColor,
          appBar: AppBar(
            backgroundColor: backgroundColor,
            elevation: 0,
            title: Text("Billetera",
                style:
                    TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            centerTitle: true,
            iconTheme: IconThemeData(color: textColor),
          ),
          body: Stack(
            alignment: Alignment.topCenter,
            children: [
              SingleChildScrollView(
                physics: _isDragging
                    ? const NeverScrollableScrollPhysics()
                    : const BouncingScrollPhysics(), // Restore standard scroll physics
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    // --- Accounts PageView ---
                    SizedBox(
                      height: 200,
                      child: PageView.builder(
                        controller: PageController(viewportFraction: 0.9),
                        itemCount:
                            provider.accounts.length + 1, // +1 for Add Card
                        itemBuilder: (context, index) {
                          if (index < provider.accounts.length) {
                            final account = provider.accounts[index];
                            return GestureDetector(
                              onTap: () => _showAddAccountSheet(context,
                                  accountToEdit: account),
                              child: _buildAccountCard(context, account),
                            );
                          } else {
                            // Add Account Card
                            return GestureDetector(
                              onTap: () => _showAddAccountSheet(context),
                              child: Container(
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  color: isDarkMode
                                      ? Colors.white10
                                      : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                      color: isDarkMode
                                          ? Colors.white24
                                          : Colors.grey.shade400,
                                      style: BorderStyle.solid),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_circle_outline,
                                          size: 48,
                                          color: isDarkMode
                                              ? Colors.white54
                                              : Colors.grey),
                                      const SizedBox(height: 8),
                                      Text("Añadir Cuenta",
                                          style: TextStyle(
                                              color: isDarkMode
                                                  ? Colors.white54
                                                  : Colors.grey,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold))
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ),

                    const SizedBox(height: 40),

                    // --- Goals Section ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Mis Metas (${goals.length})",
                            style: TextStyle(
                                color: textColor,
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                          ),
                          GestureDetector(
                            onTap: () => _showGoalFormDialog(context),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.cyan,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.add,
                                  color: Colors.white, size: 20),
                            ),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Goals List
                    if (goals.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(40.0),
                        child: Center(
                            child: Text(
                                "No tienes metas activas.\n¡Crea una para empezar a ahorrar!",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: isDarkMode
                                        ? Colors.blueGrey[200]
                                        : Colors.grey))),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: goals.length,
                          onReorderStart: (_) =>
                              setState(() => _isDragging = true),
                          onReorderEnd: (_) =>
                              setState(() => _isDragging = false),
                          onReorder: (oldIndex, newIndex) {
                            // User request: just UI update for now, or update provider order
                            // Since provider might not have reorder method yet, we do it locally or call provider if exists.
                            // Assuming provider needs an update method. For now, let's just update the list via provider if possible or just let it slide visually.
                            // Actually, ReorderableListView requires updating the data source.
                            // Let's assume we can call a method on provider or we should add one.
                            // Since I can't edit provider here easily without checking it, I'll assume we need to add a method or just reorder the local list copy if it was a local state, but it is from provider.
                            // I will add a reorder method call to provider.
                            Provider.of<DashboardProvider>(context,
                                    listen: false)
                                .reorderGoals(oldIndex, newIndex);
                          },
                          proxyDecorator: (child, index, animation) {
                            return AnimatedBuilder(
                              animation: animation,
                              builder: (BuildContext context, Widget? child) {
                                final double animValue =
                                    Curves.easeInOut.transform(animation.value);
                                final double elevation =
                                    lerpDouble(0, 6, animValue)!;
                                return Material(
                                  elevation: elevation,
                                  color: Colors.transparent,
                                  shadowColor: Colors.black.withOpacity(0.2),
                                  child: Transform.scale(
                                    scale: 0.95,
                                    child: Opacity(
                                      opacity: 0.7,
                                      child: child,
                                    ),
                                  ),
                                );
                              },
                              child: child,
                            );
                          },
                          itemBuilder: (context, index) {
                            final goal = goals[index];
                            return Container(
                              key: ValueKey(goal.id),
                              margin: const EdgeInsets.only(
                                  bottom: 15), // Move margin here from Item
                              child: _buildGoalItem(context, goal, isDarkMode),
                            );
                          },
                        ),
                      ),

                    const SizedBox(height: 40),

                    // --- Fixed Expenses Section (Suscripciones) ---
                    _buildFixedExpensesSection(context, provider, isDarkMode),

                    const SizedBox(height: 120), // Spacing for safe area
                  ],
                ),
              ),
              ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: const [
                  Colors.cyan,
                  Colors.purple,
                  Colors.amber,
                  Colors.green
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAccountCard(BuildContext context, AccountEntity account) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26, // Keep standard shadow for colored cards
            blurRadius: 10,
            offset: Offset(0, 5),
          )
        ],
        gradient: LinearGradient(
          colors: [
            Color(account.colorValue),
            Color(account.colorValue).withOpacity(0.7)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(IconData(account.iconCode, fontFamily: 'MaterialIcons'),
                  color: Colors.white70, size: 32),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz, color: Colors.white),
                color: const Color(0xFF1E293B),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                onSelected: (value) {
                  if (value == 'edit') {
                    _showAddAccountSheet(context, accountToEdit: account);
                  } else if (value == 'delete') {
                    final provider =
                        Provider.of<DashboardProvider>(context, listen: false);
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
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit, color: Colors.cyanAccent),
                        SizedBox(width: 8),
                        Text('Editar', style: TextStyle(color: Colors.white))
                      ])),
                  const PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete, color: Colors.redAccent),
                        SizedBox(width: 8),
                        Text('Eliminar',
                            style: TextStyle(color: Colors.redAccent))
                      ])),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                account.name,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "${account.currencySymbol} ${account.currentBalance.toStringAsFixed(2)}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildGoalItem(
      BuildContext context, GoalEntity goal, bool isDarkMode) {
    final double progress =
        (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0);
    final int percent = (progress * 100).toInt();
    final bool isCompleted = progress >= 1.0;

    final String currency =
        Provider.of<DashboardProvider>(context, listen: false).currencySymbol;

    // Colors & Theme
    final baseColor = isCompleted ? Colors.amber : goal.color;
    final accentColor = isCompleted ? Colors.amberAccent : baseColor;

    // Premium Gradient
    final gradientBg = isDarkMode
        ? const LinearGradient(
            colors: [
                Color(0xFF1E293B),
                Color(0xFF2A3F5F)
              ], // Requested Deep Blue
            begin: Alignment.topLeft,
            end: Alignment.bottomRight)
        : const LinearGradient(
            colors: [Colors.white, Color(0xFFF1F5F9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight);

    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subTextColor = isDarkMode ? Colors.white70 : Colors.black54;

    return GestureDetector(
      onTap: () => _showGoalDetails(context, goal),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20), // Requested 20
          gradient: gradientBg,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5))
          ],
          border: isCompleted
              ? Border.all(color: Colors.amber, width: 2)
              : Border.all(
                  color: isDarkMode ? Colors.white10 : Colors.grey[200]!,
                  width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Icon + Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: baseColor.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(isCompleted ? Icons.emoji_events : goal.icon,
                      color: baseColor, size: 24),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Text(
                    goal.name,
                    style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 18),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Amounts and Percentage
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Amounts
                Text(
                  "$currency ${goal.currentAmount.toStringAsFixed(0)} / $currency ${goal.targetAmount.toStringAsFixed(0)}",
                  style: TextStyle(
                      color: subTextColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500),
                ),
                // Percentage
                Text(
                  "$percent%",
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: accentColor),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Motivational Text
            // Motivational Text
            if (isCompleted)
              const Text(
                "¡Felicidades! Meta Alcanzada 🎉",
                style: TextStyle(
                    color: Colors.amber,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              )
            else
              const SizedBox.shrink(),

            const SizedBox(height: 12),

            // Gradient Progress Bar
            Stack(
              children: [
                // Background
                Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.black26 : Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                // Foreground Gradient
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Container(
                      height: 12,
                      width: constraints.maxWidth * progress,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: LinearGradient(
                          colors: [
                            baseColor.withOpacity(0.7),
                            accentColor
                          ], // Gradient
                        ),
                        boxShadow: [
                          BoxShadow(
                              color: baseColor.withOpacity(0.4),
                              blurRadius: 5,
                              offset: const Offset(0, 2))
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFixedExpensesSection(
      BuildContext context, DashboardProvider provider, bool isDarkMode) {
    final subscriptions = provider.subscriptions;
    final totalFixed = provider.totalFixedExpenses;
    final textColor = isDarkMode ? Colors.white : Colors.black;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onDoubleTap: () {
                      NotificationService().scheduleTestNotification();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('🔔 Notificación de prueba en 5 seg...'),
                        backgroundColor: Colors.purple,
                      ));
                    },
                    child: Text(
                      "Gastos Fijos",
                      style: TextStyle(
                          color: textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      "Total: ${provider.currencySymbol} ${totalFixed.toStringAsFixed(2)}",
                      style: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                  )
                ],
              ),
              GestureDetector(
                onTap: () => _showAddSubscriptionForm(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purpleAccent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 20),
                ),
              )
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (subscriptions.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              "No tienes gastos fijos registrados.\nNetflix, Internet, Alquiler...",
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: isDarkMode ? Colors.blueGrey[200] : Colors.grey),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: subscriptions.length,
              onReorderStart: (_) => setState(() => _isDragging = true),
              onReorderEnd: (_) => setState(() => _isDragging = false),
              onReorder: (oldIndex, newIndex) {
                Provider.of<DashboardProvider>(context, listen: false)
                    .reorderSubscriptions(oldIndex, newIndex);
              },
              proxyDecorator: (child, index, animation) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (BuildContext context, Widget? child) {
                    final double animValue =
                        Curves.easeInOut.transform(animation.value);
                    final double elevation = lerpDouble(0, 6, animValue)!;
                    return Material(
                      elevation: elevation,
                      color: Colors.transparent,
                      shadowColor: Colors.black.withOpacity(0.2),
                      child: Transform.scale(
                        scale: 0.95,
                        child: Opacity(
                          opacity: 0.7,
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: child,
                );
              },
              itemBuilder: (context, index) {
                final sub = subscriptions[index];
                return Container(
                  key: ValueKey(sub.id),
                  margin: const EdgeInsets.only(bottom: 12), // Move margin here
                  child: _buildSubscriptionTile(context, sub, isDarkMode),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildSubscriptionTile(
      BuildContext context, Subscription sub, bool isDarkMode) {
    final cardColor = isDarkMode ? const Color(0xFF1F2937) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subTextColor = isDarkMode ? Colors.blueGrey[200] : Colors.grey;

    final today = DateTime.now().day;
    final isOverdue = today >= sub.renewalDay && !sub.isPaidThisMonth;
    final daysLeft = sub.renewalDay - today;

    String statusText;
    Color statusColor;

    if (sub.isPaidThisMonth) {
      statusText = "Pagado ✅";
      statusColor = Colors.green;
    } else if (isOverdue) {
      statusText = "Vencido - Pagar Ahora";
      statusColor = Colors.redAccent;
    } else {
      statusText = "Vence en $daysLeft días";
      statusColor = Colors.orange;
    }

    // Account Info
    IconData accIcon;
    Color accColor;
    String accName;
    switch (sub.accountToCharge) {
      case 1:
        accIcon = Icons.payments_outlined;
        accColor = Colors.amber;
        accName = "Efectivo";
        break;
      case 3:
        accIcon = Icons.savings;
        accColor = Colors.purpleAccent;
        accName = "Ahorros";
        break;
      case 2:
      default:
        accIcon = Icons.account_balance;
        accColor = Colors.blueAccent;
        accName = "Banco";
        break;
    }

    return GestureDetector(
      onTap: () {
        if (!sub.isPaidThisMonth) {
          _confirmPaySubscription(context, sub);
        }
      },
      onLongPress:
          null, // Disable manual long press to allow ReorderableListView to handle it

      child: Container(
        // margin: const EdgeInsets.only(bottom: 12), // Handled by ReorderableListView wrapper
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: isOverdue ? Border.all(color: Colors.redAccent) : null,
          boxShadow: isDarkMode
              ? []
              : [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                      offset: const Offset(0, 2))
                ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Color(sub.colorValue).withOpacity(0.2),
                  shape: BoxShape.circle),
              child: Icon(IconData(sub.iconCode, fontFamily: 'MaterialIcons'),
                  color: Color(sub.colorValue), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sub.name,
                      style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(statusText,
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Text("S/ ${sub.amount.toStringAsFixed(2)}",
                        style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    const SizedBox(width: 6),
                    // Account Indicator
                    Tooltip(
                      message: "Se paga con $accName",
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                            color: accColor.withOpacity(0.1),
                            shape: BoxShape.circle),
                        child: Icon(accIcon, color: accColor, size: 14),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 4),
                Text("Día ${sub.renewalDay}",
                    style: TextStyle(color: subTextColor, fontSize: 12)),
              ],
            )
          ],
        ),
      ),
    );
  }

  void _showAddSubscriptionForm(BuildContext context) {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    int selectedDay = DateTime.now().day;
    int selectedIcon = Icons.movie.codePoint;
    int selectedColor = Colors.cyan.value;
    int selectedAccount = 2; // Default Bank

    final List<IconData> icons = [
      Icons.movie, // Netflix/Disney
      Icons.music_note, // Spotify
      Icons.wifi, // Internet
      Icons.home, // Rent
      Icons.bolt, // Utilities
      Icons.fitness_center, // Gym
      Icons.phone_android, // Mobile
      Icons.school, // Education
      Icons.pets, // Pet food
      Icons.directions_car, // Car insurance
      Icons.videogame_asset, // Gaming
      Icons.cloud, // Cloud storage
    ];

    final List<Color> colors = [
      Colors.redAccent,
      Colors.pinkAccent,
      Colors.purpleAccent,
      Colors.deepPurpleAccent,
      Colors.indigoAccent,
      Colors.blueAccent,
      Colors.lightBlueAccent,
      Colors.cyanAccent,
      Colors.tealAccent,
      Colors.greenAccent,
      Colors.lightGreenAccent,
      Colors.limeAccent,
      Colors.yellowAccent,
      Colors.amberAccent,
      Colors.orangeAccent,
      Colors.deepOrangeAccent,
    ];

    final isDarkMode =
        Provider.of<DashboardProvider>(context, listen: false).isDarkMode;
    final backgroundColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subTextColor = isDarkMode ? Colors.white70 : Colors.grey[700];
    final inputFillColor =
        isDarkMode ? const Color(0xFF1F2937) : Colors.grey[100];
    final inputHintColor = isDarkMode ? Colors.white30 : Colors.grey[500];
    final unselectedIconBg = isDarkMode ? Colors.white10 : Colors.grey[200];
    final unselectedIconColor = isDarkMode ? Colors.grey : Colors.grey[600];

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: backgroundColor,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (ctx) => StatefulBuilder(
              builder: (context, setState) {
                return Padding(
                  padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                      left: 20,
                      right: 20,
                      top: 20),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Nuevo Gasto Fijo",
                            style: TextStyle(
                                color: textColor,
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 20),

                        // Icon Selector (Updated with dynamic color)
                        Text("Icono y Color",
                            style: TextStyle(color: subTextColor)),
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: icons.map((icon) {
                              final isSelected = icon.codePoint == selectedIcon;
                              final activeColor = Color(selectedColor);
                              return GestureDetector(
                                onTap: () => setState(
                                    () => selectedIcon = icon.codePoint),
                                child: Container(
                                  margin: const EdgeInsets.only(right: 12),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                      color: isSelected
                                          ? activeColor.withOpacity(0.2)
                                          : unselectedIconBg,
                                      shape: BoxShape.circle,
                                      border: isSelected
                                          ? Border.all(color: activeColor)
                                          : null),
                                  child: Icon(icon,
                                      color: isSelected
                                          ? activeColor
                                          : unselectedIconColor,
                                      size: 24),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Color Selector
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: colors.map((color) {
                              final isSelected = color.value == selectedColor;
                              return GestureDetector(
                                onTap: () =>
                                    setState(() => selectedColor = color.value),
                                child: Container(
                                  margin: const EdgeInsets.only(right: 12),
                                  padding:
                                      const EdgeInsets.all(2), // Border space
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: isSelected
                                        ? Border.all(color: textColor, width: 2)
                                        : null,
                                  ),
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                        color: color, shape: BoxShape.circle),
                                    child: isSelected
                                        ? const Icon(Icons.check,
                                            size: 16, color: Colors.white)
                                        : null,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const SizedBox(height: 20),

                        TextField(
                          controller: nameController,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                              labelText: "Nombre (ej. Netflix)",
                              labelStyle: TextStyle(color: subTextColor),
                              filled: true,
                              fillColor: inputFillColor,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none),
                              hintStyle: TextStyle(color: inputHintColor)),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: amountController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                              labelText: "Monto Mensual",
                              labelStyle: TextStyle(color: subTextColor),
                              prefixText: "S/ ",
                              prefixStyle: TextStyle(color: subTextColor),
                              filled: true,
                              fillColor: inputFillColor,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none),
                              hintStyle: TextStyle(color: inputHintColor)),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Día de Pago Mensual",
                                style: TextStyle(color: subTextColor)),
                            DropdownButton<int>(
                              value: selectedDay,
                              dropdownColor: backgroundColor,
                              style: TextStyle(color: textColor),
                              items: List.generate(31, (index) => index + 1)
                                  .map((day) => DropdownMenuItem(
                                        value: day,
                                        child: Text("Día $day"),
                                      ))
                                  .toList(),
                              onChanged: (val) =>
                                  setState(() => selectedDay = val!),
                            )
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text("Método de Pago Predeterminado",
                            style: TextStyle(color: subTextColor)),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _sourceChipStyled(
                                "Efectivo",
                                1,
                                selectedAccount == 1,
                                Colors.amber,
                                Colors.black,
                                (val) => setState(() => selectedAccount = val)),
                            _sourceChipStyled(
                                "Banco",
                                2,
                                selectedAccount == 2,
                                const Color(0xFF64B5F6), // Light Blue 300
                                Colors.black,
                                (val) => setState(() => selectedAccount = val)),
                            _sourceChipStyled(
                                "Ahorros",
                                3,
                                selectedAccount == 3,
                                const Color(
                                    0xFFE040FB), // Purple Accent 100/200 equivalent
                                Colors.black,
                                (val) => setState(() => selectedAccount = val)),
                          ],
                        ),
                        const SizedBox(height: 30),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () {
                              if (nameController.text.isNotEmpty &&
                                  amountController.text.isNotEmpty) {
                                final sub = Subscription(
                                  id: DateTime.now()
                                      .millisecondsSinceEpoch
                                      .toString(),
                                  name: nameController.text,
                                  amount: double.parse(amountController.text),
                                  renewalDay: selectedDay,
                                  iconCode: selectedIcon,
                                  colorValue: selectedColor,
                                  accountToCharge: selectedAccount,
                                );
                                Provider.of<DashboardProvider>(context,
                                        listen: false)
                                    .addSubscription(sub);
                                Navigator.pop(ctx);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.cyan),
                            child: const Text("Guardar",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                          ),
                        )
                      ],
                    ),
                  ),
                );
              },
            ));
  }

  void _confirmPaySubscription(BuildContext context, Subscription sub) {
    final provider = Provider.of<DashboardProvider>(context, listen: false);
    final accountName = provider.getAccountName(sub.accountToCharge);

    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              title: Text("Pagar ${sub.name}",
                  style: const TextStyle(color: Colors.white)),
              content: Text(
                  "¿Registrar el pago de S/ ${sub.amount.toStringAsFixed(2)}?\nSe descontará de: $accountName",
                  style: const TextStyle(color: Colors.white70)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Cancelar",
                        style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                    onPressed: () {
                      provider.markSubscriptionAsPaid(sub);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text("Pago registrado exitosamente ✅")));
                    },
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text("Pagar",
                        style: TextStyle(color: Colors.white)))
              ],
            ));
  }

  Widget _sourceChipStyled(String label, int value, bool isSelected,
      Color activeColor, Color activeTextColor, Function(int) onSelect) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) onSelect(value);
      },
      selectedColor: activeColor,
      backgroundColor: Colors.grey[200], // Visible grey background
      labelStyle: TextStyle(
          color: isSelected ? Colors.black : Colors.grey[800], // Dark text
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
      showCheckmark: isSelected,
      checkmarkColor: Colors.black,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
              color: isSelected
                  ? activeColor
                  : Colors.grey[400]!, // Visible border
              width: 1.5)), // Thicker border
    );
  }
}
