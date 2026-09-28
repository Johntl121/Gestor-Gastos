import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../../domain/entities/transaction_entity.dart';
import '../../../../core/constants/app_categories.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../providers/wallet_provider.dart';
import '../../../providers/transaction_provider.dart';

class RecentTransactionsList extends StatelessWidget {
  final VoidCallback? onSeeAllPressed;

  const RecentTransactionsList({super.key, this.onSeeAllPressed});

  Widget _buildTransactionItem(TransactionEntity t,
      WalletProvider walletProvider, BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    bool isTransfer = t.type == TransactionType.transfer ||
        t.description.toLowerCase().contains('transferencia');

    String title = t.description;
    String subtitle = DateFormat('h:mm a').format(t.date);
    String symbol = walletProvider.currencySymbol;
    String absAmount = t.amount.abs().toStringAsFixed(2);

    String amountFormatted;
    Color color;
    IconData icon;
    bool isIncome = t.amount > 0;

    final cardColor = theme.cardColor;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black87;
    final subTextColor = isDarkMode ? Colors.blueGrey[200] : Colors.grey[600];

    if (isTransfer) {
      final source = walletProvider.getAccountName(t.accountId);
      final dest = t.destinationAccountId != null
          ? walletProvider.getAccountName(t.destinationAccountId!)
          : 'Destino';

      title = t.description.isNotEmpty ? t.description : "Transferencia";
      subtitle = "${DateFormat('h:mm a').format(t.date)} • $source ➔ $dest";

      amountFormatted = "⇄ $symbol $absAmount";
      color = isDarkMode ? Colors.white70 : const Color(0xFF64B5F6);
      icon = Icons.swap_horiz;
    } else {
      amountFormatted = "${isIncome ? '+' : '-'} $symbol $absAmount";
      color = isIncome
          ? (isDarkMode ? Colors.greenAccent : Colors.green)
          : Colors.redAccent;

      icon = AppCategories.getIcon(t.categoryId);

      if (t.iconCode != null) {
        icon = IconData(t.iconCode!, fontFamily: 'MaterialIcons');
      }

      if (t.note != null && t.note!.isNotEmpty) {
        subtitle += " • ${t.note!}";
      } else {
        subtitle += " • ${isIncome ? 'Ingreso' : 'Gasto'}";
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isDarkMode
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    offset: const Offset(0, 4),
                    blurRadius: 10,
                  )
                ]),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (t.type == TransactionType.expense ||
                      (!isIncome && !isTransfer))
                  ? Colors.redAccent.withValues(alpha: 0.15)
                  : color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (t.type == TransactionType.expense ||
                        (!isIncome && !isTransfer))
                    ? Colors.redAccent.withValues(alpha: 0.1)
                    : color.withValues(alpha: 0.1),
              ),
            ),
            child: Icon(icon,
                color: (t.type == TransactionType.expense ||
                        (!isIncome && !isTransfer))
                    ? Colors.redAccent
                    : color,
                size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: textColor),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: subTextColor, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            amountFormatted,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: (t.type == TransactionType.expense ||
                        (!isIncome && !isTransfer))
                    ? Colors.redAccent
                    : color),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.white;
    final subTextColor = theme.brightness == Brightness.dark
        ? Colors.blueGrey[200]
        : Colors.grey[600];

    return Consumer2<TransactionProvider, WalletProvider>(
      builder: (context, txProvider, walletProvider, _) {
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(AppStrings.homeRecentTransactions,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: textColor)),
                GestureDetector(
                  onTap: onSeeAllPressed,
                  child: const Text(AppStrings.homeSeeAll,
                      style: TextStyle(
                          color: Colors.tealAccent,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 15),
            txProvider.transactions.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text("No hay transacciones recientes",
                        style: TextStyle(color: subTextColor)),
                  )
                : ListView.separated(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: txProvider.transactions.take(3).length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final transaction = txProvider.transactions[index];
                      return Dismissible(
                        key: Key(transaction.id.toString()),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) async {
                          final deleted = transaction;
                          if (transaction.id != null) {
                            await txProvider.deleteTransaction(transaction.id!);
                            await walletProvider.loadWalletData();

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).clearSnackBars();
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(
                                content: const Text(
                                    'Transacción eliminada de recientes'),
                                action: SnackBarAction(
                                  label: 'DESHACER',
                                  textColor: Colors.cyanAccent,
                                  onPressed: () async {
                                    await txProvider.addTransaction(deleted);
                                    await walletProvider.loadWalletData();
                                  },
                                ),
                                duration: const Duration(seconds: 4),
                              ));
                            }
                          }
                        },
                        child: _buildTransactionItem(
                            transaction, walletProvider, context),
                      );
                    },
                  ),
          ],
        );
      },
    );
  }
}
