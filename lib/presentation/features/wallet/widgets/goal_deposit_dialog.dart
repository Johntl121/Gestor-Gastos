import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../domain/entities/goal_entity.dart';
import '../../../providers/wallet_provider.dart';
import '../../../providers/transaction_provider.dart';

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
  int? _selectedSourceId;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<WalletProvider>(context, listen: false);
    // Inicializar con primera cuenta que NO sea la alcancía
    if (provider.accounts.isNotEmpty) {
      final nonVault =
          provider.accounts.where((a) => a.id != widget.goal.accountId);
      _selectedSourceId =
          nonVault.isNotEmpty ? nonVault.first.id : provider.accounts.first.id;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final goalColor = Color(widget.goal.colorValue);
    final currencySymbol =
        Provider.of<WalletProvider>(context, listen: false).currencySymbol;

    return AlertDialog(
      backgroundColor: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: goalColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(widget.goal.icon, color: goalColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Depositar a ${widget.goal.name}",
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Monto
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black87,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              autofocus: true,
              onChanged: (val) {
                if (_errorText != null) {
                  setState(() => _errorText = null);
                }
              },
              decoration: InputDecoration(
                prefixText: "$currencySymbol ",
                prefixStyle: TextStyle(
                    color: goalColor,
                    fontSize: 28,
                    fontWeight: FontWeight.bold),
                border: InputBorder.none,
                hintText: "0.00",
                hintStyle: TextStyle(
                  color: isDarkMode ? Colors.white24 : Colors.grey[300],
                ),
                errorText: _errorText,
                errorStyle: const TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
            ),

            // Progreso actual
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: goalColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Progreso: ${(widget.goal.progress * 100).toInt()}%",
                    style: TextStyle(
                        color: goalColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                  ),
                  Text(
                    "Faltan $currencySymbol ${widget.goal.remainingAmount.toStringAsFixed(2)}",
                    style: TextStyle(
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // CUENTA ORIGEN (Selector)
            Text("Desde:",
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                )),
            const SizedBox(height: 8),
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

                if (_selectedSourceId == null ||
                    !provider.accounts.any((a) => a.id == _selectedSourceId)) {
                  _selectedSourceId = provider.accounts.first.id;
                }

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonFormField<int>(
                    initialValue: _selectedSourceId,
                    isExpanded: true,
                    dropdownColor:
                        isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black87,
                      fontSize: 14,
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
                              color: Color(account.colorValue),
                            ),
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
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // CUENTA DESTINO (Estática — La Alcancía de la meta)
            Text("Hacia:",
                style: TextStyle(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                )),
            const SizedBox(height: 8),
            Consumer<WalletProvider>(
              builder: (context, provider, _) {
                final vaultAccount = widget.goal.accountId != null
                    ? provider.accounts
                        .where((a) => a.id == widget.goal.accountId)
                        .firstOrNull
                    : null;

                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    color: goalColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: goalColor.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lock, size: 18, color: goalColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          vaultAccount != null
                              ? "${vaultAccount.name} (Alcancía)"
                              : "Cuenta Alcancía",
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Icon(Icons.verified, size: 16, color: goalColor),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("Cancelar",
              style: TextStyle(
                  color: isDarkMode ? Colors.grey : Colors.grey[600])),
        ),
        ElevatedButton(
          onPressed: () async {
            final amount = double.tryParse(_amountController.text) ?? 0;
            final remainingAmount = widget.goal.remainingAmount;

            if (amount <= 0) {
              setState(() => _errorText = "Ingresa un monto válido");
              return;
            }

            if (amount > remainingAmount) {
              setState(() {
                _errorText =
                    "Solo te faltan $currencySymbol ${remainingAmount.toStringAsFixed(2)}";
              });
              return;
            }

            // ¿Completa la meta?
            if (amount >= remainingAmount) {
              widget.onConfettiTrigger();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text("¡FELICIDADES! 🎉 Meta Completada",
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                backgroundColor: Colors.amber,
              ));
            }

            await Provider.of<WalletProvider>(context, listen: false)
                .depositToGoal(
                    widget.goal.id.toString(), amount, _selectedSourceId!);

            if (context.mounted) {
              Provider.of<TransactionProvider>(context, listen: false)
                  .loadTransactions();
              Navigator.pop(context);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: goalColor,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 4,
            shadowColor: goalColor.withValues(alpha: 0.4),
          ),
          child: const Text("Depositar",
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
