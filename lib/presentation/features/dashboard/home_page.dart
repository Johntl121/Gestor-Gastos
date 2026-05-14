import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/transaction_entity.dart';
import '../../providers/ui_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/stats_provider.dart';
import '../../../injection_container.dart' as sl;
import '../../../data/repositories/transaction_data_source.dart';
import '../../../core/constants/app_categories.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/constants/icon_mapper.dart';

import '../settings/settings_page.dart';
import '../auth/onboarding_page.dart';

class HomePage extends StatefulWidget {
  final VoidCallback? onSeeAllPressed;

  const HomePage({super.key, this.onSeeAllPressed});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  void _showDeveloperPanel(BuildContext context) {
    if (!kDebugMode) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E2A32),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("🛠️ Panel de Desarrollador",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _buildDevButton(
                ctx, "⚠️ Reset App Data (Development)", Colors.redAccent,
                () async {
              Navigator.pop(ctx);
              await sl.sl<TransactionLocalDataSource>().clearAllData();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                      builder: (context) => const OnboardingPage()),
                  (route) => false,
                );
              }
            }),
            const SizedBox(height: 10),
            _buildDevButton(ctx, "🌱 Seed Fake Data", Colors.greenAccent,
                () async {
              Navigator.pop(ctx);
              await Provider.of<TransactionProvider>(ctx, listen: false)
                  .generateFakeData();
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Fake data seeded!')),
                );
              }
            }),
            const SizedBox(height: 10),
            _buildDevButton(ctx, "🤖 Reset Coach Timer", Colors.blueAccent,
                () async {
              Navigator.pop(ctx);
              await Provider.of<StatsProvider>(ctx, listen: false)
                  .resetCoachCooldown();
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Coach timers reset!')),
                );
              }
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDevButton(
      BuildContext context, String label, Color color, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
            backgroundColor: color.withValues(alpha: 0.2),
            foregroundColor: color,
            side: BorderSide(color: color),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10))),
        onPressed: onTap,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = theme.scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // --- Header ---
              _HeaderSection(
                onShowDeveloperPanel: () => _showDeveloperPanel(context),
              ),

              const SizedBox(height: 30),

              // --- Donut Chart / Graphical Indicator Section ---
              const _DonutChartSection(),

              const SizedBox(height: 10),

              // --- Balance Summary Section ---
              const _BalanceSummary(),

              const SizedBox(height: 30),

              // --- Recent Transactions List ---
              _RecentTransactionsList(onSeeAllPressed: widget.onSeeAllPressed),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// --- TOP LEVEL NOTIFICATION HELPER ---

bool _hasPendingNotifications(TransactionProvider txProvider) {
  final now = DateTime.now();
  for (var sub in txProvider.subscriptions) {
    if (sub.isPaid) continue;
    final due = sub.nextDueDate;
    final diff = due.difference(now).inDays;
    if (diff <= 3) return true;
  }
  return false;
}

void _showNotificationSheet(BuildContext context) {
  final txProvider = Provider.of<TransactionProvider>(context, listen: false);
  final uiProvider = Provider.of<UiProvider>(context, listen: false);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  final subs = txProvider.subscriptions.where((s) {
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
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold),
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

              final subColor = Color(s.customColor ?? AppCategories.getColor(s.categoryId).toARGB32());

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

// --- DECOMPOSED WIDGETS WITH CONST CONSTRUCTORS ---

class _HeaderSection extends StatelessWidget {
  final VoidCallback onShowDeveloperPanel;

  const _HeaderSection({required this.onShowDeveloperPanel});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.white;

    return Consumer2<UiProvider, TransactionProvider>(
      builder: (context, uiProvider, txProvider, _) {
        final isDarkMode = uiProvider.isDarkMode;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const SettingsPage()),
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
                  if (_hasPendingNotifications(txProvider))
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

class _DonutChartSection extends StatelessWidget {
  const _DonutChartSection();

  Widget _buildMoodIndicator(double limit, double spent, bool isDarkMode) {
    final remaining = (limit - spent).clamp(0, limit);
    final percent = (limit > 0) ? (remaining / limit) : 0.0;

    IconData icon;
    Color color;

    if (percent > 0.50) {
      icon = Icons.sentiment_very_satisfied_rounded;
      color = Colors.greenAccent.shade700;
    } else if (percent > 0.20) {
      icon = Icons.sentiment_neutral_rounded;
      color = Colors.amber.shade300;
    } else {
      icon = Icons.sentiment_very_dissatisfied_rounded;
      color = Colors.redAccent;
    }

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.cyan.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 60, color: color),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Consumer2<WalletProvider, TransactionProvider>(
      builder: (context, walletProvider, txProvider, _) {
        final currency = walletProvider.currencySymbol;
        final budgetLimit = walletProvider.budgetLimit;

        double monthSpent = 0;
        final now = DateTime.now();

        for (var t in txProvider.transactions) {
          if (t.type == TransactionType.transfer) continue;
          final isSameMonth =
              t.date.year == now.year && t.date.month == now.month;

          if (isSameMonth && t.amount < 0) {
            final accList =
                walletProvider.accounts.where((a) => a.id == t.accountId);
            final acc = accList.isNotEmpty ? accList.first : null;

            final sourceRate = WalletProvider
                    .exchangeRatesToPEN[acc?.currencySymbol ?? 'S/'] ??
                1.0;
            final targetRate =
                WalletProvider.exchangeRatesToPEN[currency] ?? 1.0;
            monthSpent += (t.amount.abs() * sourceRate) / targetRate;
          }
        }

        return Column(
          children: [
            _buildMoodIndicator(budgetLimit, monthSpent, isDarkMode),
          ],
        );
      },
    );
  }
}

class _BalanceSummary extends StatelessWidget {
  const _BalanceSummary();

  String _getMoodQuote(double limit, double spent) {
    if (limit == 0) return "Define un presupuesto.";
    final percent = (limit - spent) / limit;

    if (percent > 0.50) return "\"¡Estás en la cima! Sigue así.\"";
    if (percent > 0.20) return "\"Todo en orden, pero mantente atento.\"";
    return "\"¡Alerta roja! Presupuesto excedido.\"";
  }

  Widget _buildSummaryCard(
      {required IconData icon,
      required Color iconColor,
      required Color backgroundColor,
      required String amount,
      required String label,
      required BuildContext context}) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final cardColor = theme.cardColor;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final subTextColor = isDarkMode ? Colors.blueGrey[200] : Colors.grey[600];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: isDarkMode
              ? Border.all(color: Colors.white10)
              : Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
                color: isDarkMode ? Colors.black45 : Colors.black12,
                blurRadius: 5,
                offset: const Offset(0, 2))
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 12),
          Text(amount,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: subTextColor, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildBudgetCard(
      BuildContext context, double limit, double spent, String currency) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final progress = (limit > 0) ? (spent / limit).clamp(0.0, 1.0) : 0.0;
    final cardColor = theme.cardColor;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final subTextColor = isDarkMode ? Colors.blueGrey[200] : Colors.grey[600];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black45
                : Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 4),
            blurRadius: 10,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("PRESUPUESTO MENSUAL",
              style: TextStyle(
                  color: subTextColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              RichText(
                text: TextSpan(children: [
                  TextSpan(
                      text: "$currency ${spent.toStringAsFixed(2)}",
                      style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  TextSpan(
                      text: " / $currency ${limit.toStringAsFixed(2)}",
                      style: TextStyle(color: subTextColor, fontSize: 14)),
                ]),
              ),
              Text("${((1 - progress) * 100).toInt()}% restante",
                  style: const TextStyle(
                      color: Colors.tealAccent, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 15),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor:
                  isDarkMode ? Colors.white10 : Colors.grey.shade200,
              color: progress > 0.9 ? Colors.redAccent : Colors.cyan,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 15),
          const Row(
            children: [
              Icon(Icons.access_time_filled,
                  size: 14, color: Colors.tealAccent),
              SizedBox(width: 5),
              Text("Calculado al día de hoy",
                  style: TextStyle(color: Colors.tealAccent, fontSize: 12))
            ],
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.white;
    final subTextColor = isDarkMode ? Colors.blueGrey[200] : Colors.grey[600];

    return Consumer2<WalletProvider, TransactionProvider>(
      builder: (context, walletProvider, txProvider, _) {
        final currency = walletProvider.currencySymbol;
        final balance = walletProvider.totalBalance;
        final budgetLimit = walletProvider.budgetLimit;

        double todayIncome = 0;
        double todayExpense = 0;
        double monthSpent = 0;
        final now = DateTime.now();

        for (var t in txProvider.transactions) {
          if (t.type == TransactionType.transfer) continue;

          final isToday = t.date.year == now.year &&
              t.date.month == now.month &&
              t.date.day == now.day;

          final isSameMonth =
              t.date.year == now.year && t.date.month == now.month;

          if (isToday) {
            final accList =
                walletProvider.accounts.where((a) => a.id == t.accountId);
            final acc = accList.isNotEmpty ? accList.first : null;

            final sourceRate = WalletProvider
                    .exchangeRatesToPEN[acc?.currencySymbol ?? 'S/'] ??
                1.0;
            final targetRate =
                WalletProvider.exchangeRatesToPEN[currency] ?? 1.0;
            final convertedAmount = (t.amount * sourceRate) / targetRate;

            if (t.amount > 0) {
              todayIncome += convertedAmount;
            } else {
              todayExpense += convertedAmount.abs();
            }
          }

          if (isSameMonth && t.amount < 0) {
            final accList =
                walletProvider.accounts.where((a) => a.id == t.accountId);
            final acc = accList.isNotEmpty ? accList.first : null;

            final sourceRate = WalletProvider
                    .exchangeRatesToPEN[acc?.currencySymbol ?? 'S/'] ??
                1.0;
            final targetRate =
                WalletProvider.exchangeRatesToPEN[currency] ?? 1.0;
            monthSpent += (t.amount.abs() * sourceRate) / targetRate;
          }
        }

        return Column(
          children: [
            Text("SALDO DISPONIBLE",
                style: TextStyle(
                    color: subTextColor,
                    fontSize: 12,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 5),
            Text(
              CurrencyFormatter.format(balance, currency),
              style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: textColor),
            ),
            const SizedBox(height: 5),
            Text(
              _getMoodQuote(budgetLimit, monthSpent),
              style: TextStyle(
                  color: Colors.cyanAccent.withValues(alpha: 0.8),
                  fontStyle: FontStyle.italic,
                  fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              "⚠️ Totales convertidos a $currency",
              style: TextStyle(
                  color: Colors.orangeAccent.withValues(alpha: 0.8),
                  fontSize: 10,
                  fontWeight: FontWeight.w500),
            ),

            const SizedBox(height: 30),

            // Budget Card
            _buildBudgetCard(context, budgetLimit, monthSpent, currency),

            const SizedBox(height: 20),

            // Summary Cards
            Row(
              children: [
                Expanded(
                    child: _buildSummaryCard(
                        icon: Icons.arrow_upward,
                        iconColor:
                            isDarkMode ? Colors.greenAccent : Colors.green,
                        backgroundColor: isDarkMode
                            ? Colors.greenAccent.withValues(alpha: 0.1)
                            : const Color(0xFFE0F2F1),
                        amount: CurrencyFormatter.formatWithSign(
                            todayIncome, currency),
                        label: "Ingresos Hoy",
                        context: context)),
                const SizedBox(width: 15),
                Expanded(
                    child: _buildSummaryCard(
                        icon: Icons.arrow_downward,
                        iconColor: Colors.redAccent,
                        backgroundColor: isDarkMode
                            ? Colors.redAccent.withValues(alpha: 0.1)
                            : const Color(0xFFFFEBEE),
                        amount: CurrencyFormatter.formatWithSign(
                            -todayExpense, currency),
                        label: "Gastos Hoy",
                        context: context)),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _RecentTransactionsList extends StatelessWidget {
  final VoidCallback? onSeeAllPressed;

  const _RecentTransactionsList({this.onSeeAllPressed});

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
    final subTextColor = theme.brightness == Brightness.dark ? Colors.blueGrey[200] : Colors.grey[600];

    return Consumer2<TransactionProvider, WalletProvider>(
      builder: (context, txProvider, walletProvider, _) {
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Actividad Reciente",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: textColor)),
                GestureDetector(
                  onTap: onSeeAllPressed,
                  child: const Text("Ver todo",
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
                        onDismissed: (_) {
                          final deleted = transaction;
                          if (transaction.id != null) {
                            txProvider.deleteTransaction(transaction.id!);
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: const Text(
                                  'Transacción eliminada de recientes'),
                              action: SnackBarAction(
                                label: 'DESHACER',
                                textColor: Colors.cyanAccent,
                                onPressed: () {
                                  txProvider.addTransaction(deleted);
                                },
                              ),
                              duration: const Duration(seconds: 4),
                            ));
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
