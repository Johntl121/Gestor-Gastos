import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import '../../providers/transaction_provider.dart';
import '../../providers/coach_provider.dart';
import '../../../data/datasources/preferences_local_data_source.dart';
import '../../../core/services/database_helper.dart';
import '../../../injection_container.dart' as sl;

import '../auth/onboarding_page.dart';
import 'widgets/header_section.dart';
import 'widgets/dashboard_summary_sections.dart';
import 'widgets/recent_transactions_list.dart';


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
              // Limpiar datos
              await sl.sl<PreferencesLocalDataSource>().clearAllPreferences();
              await sl.sl<LocalDatabase>().clearAllTables();
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
              await Provider.of<CoachProvider>(ctx, listen: false)
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
              HeaderSection(
                onShowDeveloperPanel: () => _showDeveloperPanel(context),
              ),

              const SizedBox(height: 30),

              // --- Donut Chart / Graphical Indicator Section ---
              const DonutChartSection(),

              const SizedBox(height: 10),

              // --- Balance Summary Section ---
              const BalanceSummary(),

              const SizedBox(height: 30),

              // --- Recent Transactions List ---
              RecentTransactionsList(onSeeAllPressed: widget.onSeeAllPressed),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

