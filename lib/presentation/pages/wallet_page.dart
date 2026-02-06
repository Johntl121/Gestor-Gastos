import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dashboard_provider.dart';
import '../../domain/entities/goal_entity.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
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

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF1E293B),
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (ctx) => StatefulBuilder(builder: (context, setState) {
              return Padding(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                    left: 20,
                    right: 20,
                    top: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(toEdit == null ? "Nueva Meta" : "Editar Meta",
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),

                    // Inputs
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: "Nombre",
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white24)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                          labelText: "Monto Objetivo",
                          labelStyle: TextStyle(color: Colors.white70),
                          enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.white24)),
                          prefixText: "S/ ",
                          prefixStyle: TextStyle(color: Colors.white60)),
                    ),

                    const SizedBox(height: 20),
                    const Text("Icono",
                        style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: icons.map((icon) {
                        final isSelected = icon.codePoint == selectedIconCode;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => selectedIconCode = icon.codePoint),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                                color: isSelected
                                    ? Color(selectedColorValue).withOpacity(0.2)
                                    : Colors.white10,
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(
                                        color: Color(selectedColorValue))
                                    : null),
                            child: Icon(icon,
                                color: isSelected
                                    ? Color(selectedColorValue)
                                    : Colors.grey,
                                size: 24),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),
                    const Text("Color",
                        style: TextStyle(color: Colors.white70)),
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
                                    ? Border.all(color: Colors.white, width: 3)
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
                                  isCompleted: toEdit.currentAmount >= amount);
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
              );
            }));
  }

  void _showDepositDialog(BuildContext context, GoalEntity goal) {
    final amountController = TextEditingController();
    int selectedSource = 2; // Default Bank

    showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(builder: (context, setState) {
              return AlertDialog(
                backgroundColor: const Color(0xFF1E293B),
                title: Text("Depositar a ${goal.name}",
                    style: const TextStyle(color: Colors.white)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                          prefixText: "S/ ",
                          prefixStyle:
                              TextStyle(color: Colors.cyan, fontSize: 24),
                          border: InputBorder.none,
                          hintText: "0.00",
                          hintStyle: TextStyle(color: Colors.white30)),
                    ),
                    const SizedBox(height: 20),
                    const Text("Desde:", style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _sourceChip("Efectivo", 1, selectedSource == 1,
                            (val) => setState(() => selectedSource = val)),
                        _sourceChip("Banco", 2, selectedSource == 2,
                            (val) => setState(() => selectedSource = val)),
                      ],
                    )
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
                        if (amount > 0) {
                          Provider.of<DashboardProvider>(context, listen: false)
                              .depositToGoal(goal.id, amount, selectedSource);
                          Navigator.pop(ctx);
                          Navigator.pop(context); // Close details sheet too
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

  Widget _sourceChip(
      String label, int value, bool isSelected, Function(int) onSelect) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) onSelect(value);
      },
      selectedColor: Colors.cyan.withOpacity(0.3),
      backgroundColor: Colors.black26,
      labelStyle: TextStyle(color: isSelected ? Colors.cyan : Colors.grey),
      side: BorderSide(color: isSelected ? Colors.cyan : Colors.transparent),
    );
  }

  void _confirmDeleteGoal(BuildContext context, GoalEntity goal) {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              title: const Text("¿Eliminar Meta?",
                  style: TextStyle(color: Colors.white)),
              content: Text(
                  "El dinero ahorrado (S/ ${goal.currentAmount.toStringAsFixed(2)}) permanecerá en tu cuenta de Ahorros pero se desvinculará de esta meta.",
                  style: const TextStyle(color: Colors.white70)),
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

  void _showGoalDetails(BuildContext context, GoalEntity goal) {
    showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF1E293B),
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
                    style: const TextStyle(
                        color: Colors.white,
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
                        width:
                            MediaQuery.of(context).size.width * 0.8 * progress,
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
                      onPressed: () {
                        // Logic to withdraw without spending could go here
                        Navigator.pop(ctx);
                      },
                      child: const Text("Retirar dinero (Sin registrar gasto)",
                          style: TextStyle(color: Colors.grey)))
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
        final isDarkMode = provider.isDarkMode;
        final backgroundColor =
            isDarkMode ? const Color(0xFF15202B) : const Color(0xFFF5F7FA);
        final textColor = isDarkMode ? Colors.white : Colors.black;

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
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                // --- Accounts PageView ---
                SizedBox(
                  height: 200,
                  child: PageView(
                    controller: PageController(viewportFraction: 0.9),
                    children: [
                      _buildAccountCard(
                        "Efectivo",
                        provider.currencySymbol,
                        provider.cashBalance,
                        Colors.amber,
                        Icons.payments_outlined,
                      ),
                      _buildAccountCard(
                        "Banco",
                        provider.currencySymbol,
                        provider.bankBalance,
                        Colors.blueAccent,
                        Icons.account_balance,
                      ),
                      _buildAccountCard(
                        "Ahorros",
                        provider.currencySymbol,
                        provider.savingsBalance,
                        Colors.purpleAccent,
                        Icons.savings,
                      ),
                    ],
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
                    child: Column(
                      children: goals
                          .map((goal) =>
                              _buildGoalItem(context, goal, isDarkMode))
                          .toList(),
                    ),
                  ),

                const SizedBox(height: 100), // Spacing for safe area
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAccountCard(String title, String currency, double balance,
      Color color, IconData icon) {
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
          colors: [color, color.withOpacity(0.7)],
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
              Icon(icon, color: Colors.white70, size: 32),
              const Icon(Icons.more_horiz, color: Colors.white70),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "$currency ${balance.toStringAsFixed(2)}",
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

    final cardColor = isDarkMode ? const Color(0xFF1F2937) : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subTextColor = isDarkMode ? Colors.blueGrey[200] : Colors.grey;

    return GestureDetector(
      onTap: () => _showGoalDetails(context, goal),
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border:
                isCompleted ? Border.all(color: Colors.amber, width: 2) : null,
            boxShadow: isCompleted
                ? [
                    BoxShadow(
                        color: Colors.amber.withOpacity(0.2), blurRadius: 10)
                  ]
                : (isDarkMode
                    ? []
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          offset: const Offset(0, 4),
                          blurRadius: 10,
                        )
                      ])),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isCompleted
                    ? Colors.amber.withOpacity(0.2)
                    : goal.color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(isCompleted ? Icons.emoji_events : goal.icon,
                  color: isCompleted ? Colors.amber : goal.color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        goal.name,
                        style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      ),
                      Text(
                        isCompleted ? "¡COMPLETADA!" : "$percent%",
                        style: TextStyle(
                            color: isCompleted ? Colors.amber : goal.color,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      color: isCompleted ? Colors.amber : goal.color,
                      backgroundColor:
                          isDarkMode ? Colors.white10 : Colors.grey[200],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "S/ ${goal.currentAmount.toStringAsFixed(0)} / S/ ${goal.targetAmount.toStringAsFixed(0)}",
                    style: TextStyle(color: subTextColor, fontSize: 12),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
