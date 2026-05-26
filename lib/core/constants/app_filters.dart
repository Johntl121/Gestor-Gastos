import 'package:flutter/material.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/entities/account_entity.dart';
import 'app_categories.dart';

class AppFilters {
  static List<Map<String, dynamic>> getHistoryFilters(
      List<AccountEntity> accounts) {
    return [
      {
        'label': 'Todos',
        'type': 'all',
        'value': null,
        'color': Colors.blueGrey
      },
      {
        'label': 'Gastos',
        'type': 'type',
        'value': TransactionType.expense,
        'color': Colors.redAccent
      },
      {
        'label': 'Ingresos',
        'type': 'type',
        'value': TransactionType.income,
        'color': Colors.greenAccent
      },
      {
        'label': '🏆 Logros',
        'type': 'goal',
        'value': 'Meta Cumplida',
        'color': Colors.amber
      },
      // Dynamic Accounts
      ...accounts.map((acc) => {
            'label': acc.name,
            'type': 'account',
            'value': acc.id,
            'color': Color(acc.colorValue),
          }),
      {
        'label': '|',
        'type': 'separator',
        'value': null,
        'color': Colors.grey
      }, // Visual Separator
      // Expanded Categories generated dynamically
      ...AppCategories.allCategories.values.map((cat) => {
            'label': cat['name'],
            'type': 'category',
            'value': cat[
                'name'], // Note: 'value' uses the name for filtering in HistoryPage
            'color': Color(cat['color'] as int),
          }),
    ];
  }
}
