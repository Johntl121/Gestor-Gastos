import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../domain/entities/account_entity.dart';
import '../../../providers/wallet_provider.dart';
import 'add_account_sheet.dart';
import '../../../../core/utils/currency_formatter.dart';

class AccountsSection extends StatelessWidget {
  final VoidCallback onAddAccount;
  final void Function(AccountEntity) onEditAccount;

  const AccountsSection({
    super.key,
    required this.onAddAccount,
    required this.onEditAccount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return SizedBox(
      height: 200,
      child: Consumer<WalletProvider>(
        builder: (context, walletProvider, _) {
          final accounts = walletProvider.accounts;
          return PageView.builder(
            controller: PageController(viewportFraction: 0.9),
            itemCount: accounts.length + 1,
            itemBuilder: (context, index) {
              if (index < accounts.length) {
                final account = accounts[index];
                return GestureDetector(
                  onTap: () => onEditAccount(account),
                  child: _AccountCard(account: account),
                );
              } else {
                return GestureDetector(
                  onTap: onAddAccount,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.white10 : Colors.grey.shade200,
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
                              size: 45,
                              color: isDarkMode ? Colors.white54 : Colors.grey),
                          const SizedBox(height: 8),
                          Text("Añadir Cuenta",
                              style: TextStyle(
                                  color:
                                      isDarkMode ? Colors.white54 : Colors.grey,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold))
                        ],
                      ),
                    ),
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final AccountEntity account;

  const _AccountCard({required this.account});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Color(account.colorValue),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 5),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                account.displayIcon,
                color: Colors.white70,
                size: 34,
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz, color: Colors.white70),
                color: const Color(0xFF1E293B),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                onSelected: (value) {
                  final provider =
                      Provider.of<WalletProvider>(context, listen: false);
                  if (value == 'edit') {
                    // Call sheet via provider contextual reference or notify parent indirectly
                    // Since context in popup menu is disconnected, let's open modal securely
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (ctx) => AddAccountSheet(accountToEdit: account),
                    );
                  } else if (value == 'delete') {
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
                        Text('Eliminar', style: TextStyle(color: Colors.white))
                      ])),
                ],
              )
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
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(
                CurrencyFormatter.format(
                    account.currentBalance, account.currencySymbol),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
