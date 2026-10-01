import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../data/models/subscription.dart';
import '../../../../domain/entities/account_entity.dart';
import '../../../providers/wallet_provider.dart';
import '../../../providers/subscription_provider.dart';
import '../../../../core/utils/currency_formatter.dart';
import 'fixed_expense_card.dart';

Widget _proxyDecorator(Widget child, int index, Animation<double> animation) {
  return AnimatedBuilder(
    animation: animation,
    builder: (BuildContext context, Widget? child) {
      return Material(
        elevation: 0,
        color: Colors.transparent,
        child: Transform.scale(
          scale: 1.05,
          child: Opacity(
            opacity: 0.9,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: child,
            ),
          ),
        ),
      );
    },
    child: child,
  );
}

class FixedExpensesSection extends StatelessWidget {
  final VoidCallback onAddExpense;
  final void Function(Subscription) onEditExpense;
  final void Function(Subscription) onPayExpense;
  final void Function(bool) onDraggingChanged;
  final bool isDarkMode;

  const FixedExpensesSection({
    super.key,
    required this.onAddExpense,
    required this.onEditExpense,
    required this.onPayExpense,
    required this.onDraggingChanged,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<SubscriptionProvider>(
      builder: (context, provider, _) {
        final subscriptions = provider.subscriptions;
        final walletProvider =
            Provider.of<WalletProvider>(context, listen: false);
        final currencySymbol = walletProvider.currencySymbol;

        double totalFixed = 0.0;
        for (var sub in subscriptions) {
          String subCurrency = 'S/';
          try {
            final acc = walletProvider.accounts
                .firstWhere((a) => a.id == sub.accountToCharge);
            subCurrency = acc.currencySymbol;
          } catch (e) {
            // Ignore if account not found
          }

          totalFixed += walletProvider.currencyConverter
              .convert(sub.amount, subCurrency, currencySymbol);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    "Gastos Fijos",
                    style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "Total: ${CurrencyFormatter.format(totalFixed, currencySymbol)}",
                      style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: onAddExpense,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                          color: const Color(0xFFD500F9),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFD500F9)
                                  .withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            )
                          ]),
                      child:
                          const Icon(Icons.add, color: Colors.white, size: 26),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            if (subscriptions.isEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                child: SizedBox(
                  width: double.infinity,
                  child: Center(
                    child: Text(
                      "No tienes gastos fijos registrados.\n¡Agrega uno para empezar!",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: isDarkMode ? Colors.grey : Colors.grey[600]),
                    ),
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  proxyDecorator: _proxyDecorator,
                  onReorderStart: (_) => onDraggingChanged(true),
                  onReorderEnd: (_) => onDraggingChanged(false),
                  itemCount: subscriptions.length,
                  onReorder: (oldIndex, newIndex) {
                    provider.reorderSubscriptions(oldIndex, newIndex);
                  },
                  itemBuilder: (context, index) {
                    final sub = subscriptions[index];
                    final account =
                        Provider.of<WalletProvider>(context, listen: false)
                            .accounts
                            .firstWhere((a) => a.id == sub.accountToCharge,
                                orElse: () => const AccountEntity(
                                    id: -1,
                                    name: 'Desconocido',
                                    initialBalance: 0,
                                    currencySymbol: '',
                                    colorValue: 0xFF9E9E9E,
                                    iconCode: 0));

                    return Container(
                      key: ValueKey(sub.id),
                      child: FixedExpenseCard(
                        subscription: sub,
                        account: account,
                        onTap: () => onEditExpense(sub),
                        onPay: () => onPayExpense(sub),
                        onDelete: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text("¿Eliminar gasto fijo?"),
                              content: Text(
                                  "¿Ya no pagas ${sub.name}? Esto dejará de notificarte."),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text("Cancelar")),
                                ElevatedButton(
                                    onPressed: () {
                                      provider.removeSubscription(
                                          sub.id.toString());
                                      Navigator.pop(ctx);
                                    },
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red),
                                    child: const Text("Eliminar"))
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}
