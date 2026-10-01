import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_filters.dart';
import '../../../providers/wallet_provider.dart';

class HistoryFiltersBar extends StatelessWidget {
  final Map<String, dynamic> selectedFilter;
  final ValueChanged<Map<String, dynamic>> onFilterChanged;

  const HistoryFiltersBar({
    super.key,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Consumer<WalletProvider>(
      builder: (context, walletProvider, _) {
        final dynamicFilters =
            AppFilters.getHistoryFilters(walletProvider.accounts);

        return SizedBox(
          height: 60,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            itemCount: dynamicFilters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final filter = dynamicFilters[index];

              if (filter['type'] == 'separator') {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 1,
                  height: 20,
                  color: isDarkMode ? Colors.white24 : Colors.black12,
                );
              }

              final isSelected = filter['label'] == selectedFilter['label'];
              final color = filter['color'] as Color;

              return GestureDetector(
                onTap: () => onFilterChanged(filter),
                child: _FilterChipWidget(
                  label: filter['label'],
                  isSelected: isSelected,
                  activeColor: color,
                  isDarkMode: isDarkMode,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _FilterChipWidget extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color activeColor;
  final bool isDarkMode;

  const _FilterChipWidget({
    required this.label,
    required this.isSelected,
    required this.activeColor,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? activeColor
            : (isDarkMode
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05)),
        borderRadius: BorderRadius.circular(20),
        border: isSelected
            ? Border.all(color: Colors.transparent)
            : Border.all(
                color: isDarkMode
                    ? activeColor.withValues(alpha: 0.5)
                    : Colors.black12),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : (isDarkMode ? Colors.white70 : Colors.black54),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13),
          ),
          if (isSelected) ...[
            const SizedBox(width: 4),
            const Icon(Icons.check, color: Colors.white, size: 16)
          ]
        ],
      ),
    );
  }
}
