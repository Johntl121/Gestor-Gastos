import 'package:flutter/material.dart';
import 'dart:io';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_categories.dart';
import '../../../../core/constants/icon_mapper.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../providers/ui_provider.dart';
import '../../../providers/wallet_provider.dart';
import '../../../providers/transaction_provider.dart';
import '../../../providers/subscription_provider.dart';
import '../../settings/settings_page.dart';

// --- TOP LEVEL NOTIFICATION HELPER ---

bool _hasPendingNotifications(SubscriptionProvider subProvider) {
  final now = DateTime.now();
  for (var sub in subProvider.subscriptions) {
    if (sub.isPaid) continue;
    final due = sub.nextDueDate;
    final diff = due.difference(now).inDays;
    if (diff <= 3) return true;
  }
  return false;
}

void _showNotificationSheet(BuildContext context) {
  final subProvider = Provider.of<SubscriptionProvider>(context, listen: false);
  final uiProvider = Provider.of<UiProvider>(context, listen: false);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  final subs = subProvider.subscriptions.where((s) {
    if (s.isPaid) return false;
    final due = s.nextDueDate;
    final diff =
        DateTime(due.year, due.month, due.day).difference(today).inDays;
    return diff <= 5;
  }).toList()
    ..sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E2A32),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text(
            "Notificaciones",
            style: TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (subs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text("¡Todo al día! No tienes pagos pendientes.",
                  style: TextStyle(color: Colors.grey)),
            )
          else
            ...subs.map((s) {
              final due = s.nextDueDate;
              final dueDay = DateTime(due.year, due.month, due.day);
              final isOverdue = dueDay.isBefore(today);
              final isToday = dueDay.isAtSameMomentAs(today);

              final formattedDate =
                  '${due.day.toString().padLeft(2, '0')}/${due.month.toString().padLeft(2, '0')}';

              final subColor = Color(s.customColor ??
                  AppCategories.getColor(s.categoryId).toARGB32());

              final String subtitleText;
              final Color subtitleColor;
              if (isOverdue) {
                subtitleText = 'Venció el $formattedDate';
                subtitleColor = Colors.redAccent;
              } else if (isToday) {
                subtitleText = '¡Vence hoy!';
                subtitleColor = Colors.orangeAccent;
              } else {
                subtitleText = 'Vence el $formattedDate';
                subtitleColor = Colors.grey;
              }

              final walletProvider =
                  Provider.of<WalletProvider>(context, listen: false);
              final acc = walletProvider.accounts.firstWhere(
                  (a) => a.id == s.accountToCharge,
                  orElse: () => walletProvider.accounts.isNotEmpty
                      ? walletProvider.accounts.first
                      : null as dynamic);
              final accountSymbol = acc.currencySymbol;
              final amountStr = CurrencyFormatter.format(s.amount, "");

              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                onTap: () {
                  Navigator.pop(ctx);
                  uiProvider.setPendingPaySubscription(s);
                  uiProvider.setIndex(3);
                },
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: subColor,
                    shape: BoxShape.circle,
                    border: isOverdue
                        ? Border.all(color: Colors.redAccent, width: 2)
                        : null,
                  ),
                  child: Icon(
                    s.customIcon != null
                        ? IconMapper.getIcon(s.customIcon)
                        : AppCategories.getIcon(s.categoryId),
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                title: Text(
                  isOverdue
                      ? "¡Pago atrasado!: ${s.name}"
                      : isToday
                          ? "¡Vence hoy!: ${s.name}"
                          : "Pago próximo: ${s.name}",
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: (isOverdue || isToday)
                          ? FontWeight.w700
                          : FontWeight.w500),
                ),
                subtitle: Text(
                  subtitleText,
                  style: TextStyle(
                      color: subtitleColor,
                      fontWeight: isToday || isOverdue
                          ? FontWeight.w600
                          : FontWeight.normal),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "$accountSymbol $amountStr",
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded,
                        color: Colors.white38, size: 18),
                  ],
                ),
              );
            }),
        ],
      ),
    ),
  );
}


class HeaderSection extends StatelessWidget {
  final VoidCallback onShowDeveloperPanel;

  const HeaderSection({super.key, required this.onShowDeveloperPanel});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.white;

    return Consumer3<UiProvider, TransactionProvider, SubscriptionProvider>(
      builder: (context, uiProvider, txProvider, subProvider, _) {
        final isDarkMode = uiProvider.isDarkMode;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SettingsPage()),
                );
              },
              onLongPress: onShowDeveloperPanel,
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.cyanAccent,
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.transparent,
                      backgroundImage: uiProvider.profileImagePath != null
                          ? FileImage(File(uiProvider.profileImagePath!))
                          : null,
                      child: uiProvider.profileImagePath == null
                          ? Text(uiProvider.userAvatar,
                              style: const TextStyle(fontSize: 28))
                          : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Bienvenido,",
                          style: TextStyle(color: Colors.teal, fontSize: 12)),
                      Text(uiProvider.userName,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: textColor)),
                    ],
                  )
                ],
              ),
            ),

            // Notification Bell
            GestureDetector(
              onTap: () => _showNotificationSheet(context),
              child: Stack(
                alignment: Alignment.topRight,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.notifications_none,
                        color: isDarkMode ? Colors.white : Colors.black54),
                  ),
                  if (_hasPendingNotifications(subProvider))
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    )
                ],
              ),
            )
          ],
        );
      },
    );
  }
}

