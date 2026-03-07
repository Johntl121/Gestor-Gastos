import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../data/models/subscription.dart';
import '../../../providers/transaction_provider.dart';
import '../../../providers/wallet_provider.dart';

class AddFixedExpenseSheet extends StatefulWidget {
  const AddFixedExpenseSheet({super.key});

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
  int _selectedAccountIndex = 0;
  Color _selectedColor = const Color(0xFF00E5FF); // Cian por defecto
  IconData _selectedIcon = Icons.home;

  final List<Color> _colors = [
    const Color(0xFF00E5FF), // Cian
    const Color(0xFFD500F9), // Morado Neon
    const Color(0xFFFFC107), // Amarillo Oro
    const Color(0xFF00E676), // Verde Neón
    const Color(0xFF2979FF), // Azul Eléctrico
    const Color(0xFFFF3D00), // Naranja Coral
    const Color(0xFFF50057), // Rosa Hot
    const Color(0xFFD32F2F), // Rojo Vivo
    const Color(0xFF00BFA5), // Verde Esmeralda
    const Color(0xFF7C4DFF), // Violeta
  ];

  final List<IconData> _icons = [
    Icons.home,
    Icons.wifi,
    Icons.lightbulb,
    Icons.water_drop,
    Icons.credit_card,
    Icons.directions_car,
    Icons.school,
    Icons.fitness_center,
    Icons.movie,
    Icons.pets,
    Icons.medical_services,
    Icons.shopping_bag,
    Icons.restaurant,
    Icons.local_gas_station,
  ];

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
              "Nuevo Gasto Fijo",
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

                    // 3. SECCIÓN PERSONALIZACIÓN (Pixel Perfect)

                    // Fila 1: Íconos
                    Text("Ícono",
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: hintColor)),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _icons.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final icon = _icons[index];
                          final isSelected = _selectedIcon == icon;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedIcon = icon),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? _selectedColor.withValues(alpha: 0.2)
                                    : cardColor,
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(
                                        color: _selectedColor, width: 2)
                                    : null,
                              ),
                              child: Icon(
                                icon,
                                color: isSelected ? _selectedColor : hintColor,
                                size: 20,
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Fila 2: Colores
                    Text("Color",
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: hintColor)),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _colors.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final color = _colors[index];
                          final isSelected = _selectedColor == color;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedColor = color),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(
                                        color: Colors.white, width: 2.5)
                                    : null,
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                            color: color.withValues(alpha: 0.4),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2))
                                      ]
                                    : [],
                              ),
                            ),
                          );
                        },
                      ),
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

                    // 5. Selector de Cuentas (Marca con texto negro)
                    Text("Cuenta de cargo",
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: txtColor)),
                    const SizedBox(height: 12),
                    Consumer<WalletProvider>(
                      builder: (context, walletProvider, _) {
                        final accounts = walletProvider.accounts;
                        if (accounts.isEmpty) {
                          return Text("No hay cuentas disponibles",
                              style: TextStyle(color: hintColor));
                        }

                        Color getAccountColor(String name) {
                          final n = name.toLowerCase();
                          if (n.contains("efectivo") || n.contains("cash")) {
                            return const Color(0xFFFFC107);
                          }
                          if (n.contains("banco") ||
                              n.contains("bbl") ||
                              n.contains("bcp")) {
                            return const Color(0xFF2196F3);
                          }
                          if (n.contains("ahorro")) {
                            return const Color(0xFF9C27B0);
                          }
                          return const Color(0xFF00E5FF);
                        }

                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: List.generate(accounts.length, (index) {
                            final acc = accounts[index];
                            final isSelected = _selectedAccountIndex == index;
                            final brandColor = getAccountColor(acc.name);

                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedAccountIndex = index),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected ? brandColor : cardColor,
                                  borderRadius: BorderRadius.circular(20),
                                  border: isSelected
                                      ? null
                                      : Border.all(color: Colors.white10),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: brandColor.withValues(alpha: 0.4),
                                            blurRadius: 6,
                                            offset: const Offset(0, 3),
                                          )
                                        ]
                                      : [],
                                ),
                                child: Text(
                                  acc.name,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.black
                                        : txtColor, // Texto NEGRO Puro
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            );
                          }),
                        );
                      },
                    ),
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
      final wallet = Provider.of<WalletProvider>(context, listen: false);

      if (wallet.accounts.isEmpty) return;

      final accountId = wallet.accounts[_selectedAccountIndex].id;

      final newSub = Subscription(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        amount: amount,
        paymentDate: _selectedDate,
        frequency: _selectedFrequency,
        accountToCharge: accountId,
        iconCode: _selectedIcon.codePoint,
        colorValue: _selectedColor.toARGB32(),
      );

      provider.addSubscription(newSub);
      Navigator.pop(context);
    }
  }
}
