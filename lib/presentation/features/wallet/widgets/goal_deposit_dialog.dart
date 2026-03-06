import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../domain/entities/goal_entity.dart';
import '../../../providers/wallet_provider.dart'; // Changed from DashboardProvider

class GoalDepositDialog extends StatefulWidget {
  final GoalEntity goal;
  final VoidCallback onConfettiTrigger;

  const GoalDepositDialog({
    super.key,
    required this.goal,
    required this.onConfettiTrigger,
  });

  @override
  State<GoalDepositDialog> createState() => _GoalDepositDialogState();
}

class _GoalDepositDialogState extends State<GoalDepositDialog> {
  final TextEditingController _amountController = TextEditingController();
  int _selectedSourceId = 2; // Default, checking existence later
  String? _errorText;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(builder: (context, setState) {
      return AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text("Depositar a ${widget.goal.name}",
            style: TextStyle(
                color: Theme.of(context).textTheme.titleLarge?.color)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              onChanged: (val) {
                if (_errorText != null) {
                  setState(() => _errorText = null);
                }
              },
              decoration: InputDecoration(
                  prefixText: "S/ ",
                  prefixStyle:
                      const TextStyle(color: Colors.cyan, fontSize: 24),
                  border: InputBorder.none,
                  hintText: "0.00",
                  hintStyle: const TextStyle(color: Colors.white30),
                  errorText: _errorText,
                  errorStyle: const TextStyle(
                      color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
            const Text("Desde:", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 10),
            Consumer<WalletProvider>(
              builder: (context, provider, _) {
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

                // Initial validation of selectedSourceId
                if (!provider.accounts.any((a) => a.id == _selectedSourceId)) {
                  // Fallback to first available account if default not found
                  final defaultAcc = provider.accounts.first;
                  // We can't setState during build here easily unless we defer it, or just use defaultAcc.id for display
                  // and update _selectedSourceId if we want to persist.
                  // But since Dropdown value must match item value:
                  _selectedSourceId = defaultAcc.id;
                }

                return DropdownButtonFormField<int>(
                  isExpanded: true,
                  value: _selectedSourceId,
                  dropdownColor: Theme.of(context).cardColor,
                  style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      fontSize: 16),
                  decoration: InputDecoration(
                    labelText: "Debitar de / Origen",
                    labelStyle: const TextStyle(color: Colors.grey),
                    prefixIcon: const Icon(Icons.account_balance_wallet,
                        color: Colors.cyan),
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.dark
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
                      setState(() => _selectedSourceId = val);
                    }
                  },
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text("Cancelar", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(_amountController.text) ?? 0;
                final remainingAmount =
                    widget.goal.targetAmount - widget.goal.currentAmount;

                if (amount > 0) {
                  // Validation
                  if (amount > remainingAmount) {
                    final currency =
                        Provider.of<WalletProvider>(context, listen: false)
                            .currencySymbol;
                    setState(() {
                      _errorText =
                          "Solo te faltan $currency ${remainingAmount.toStringAsFixed(2)}";
                    });
                    return;
                  }

                  // Success
                  if (amount >= remainingAmount) {
                    widget.onConfettiTrigger();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text("¡FELICIDADES! 🎉 Meta Completada",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        backgroundColor: Colors.amber));
                  }

                  Provider.of<WalletProvider>(context, listen: false)
                      .depositToGoal(widget.goal.id.toString(), amount,
                          _selectedSourceId); // GoalEntity id is int? String?
                  // Wait, GoalEntity id is String in WalletProvider code (line 131: millisecond string).
                  // But in WalletPage generic code, let's check GoalEntity definition.

                  Navigator.pop(context); // Close Dialog
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text("Depositar",
                  style: TextStyle(color: Colors.white)))
        ],
      );
    });
  }
}
