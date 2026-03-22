import 'package:flutter/material.dart';
import 'icon_mapper.dart';

class AppCategories {
  static final Map<int, Map<String, dynamic>> expenseCategories = {
    1: {'name': 'Alimentación', 'icon': 'restaurant', 'color': 0xFFFB8C00},
    2: {'name': 'Vivienda', 'icon': 'home', 'color': 0xFF607D8B},
    3: {'name': 'Transporte', 'icon': 'directions_bus', 'color': 0xFF2196F3},
    4: {'name': 'Servicios', 'icon': 'bolt', 'color': 0xFFF57C00},
    5: {'name': 'Salud', 'icon': 'local_hospital', 'color': 0xFF009688},
    6: {'name': 'Educación', 'icon': 'school', 'color': 0xFF795548},
    7: {'name': 'Entretenimiento', 'icon': 'movie', 'color': 0xFF3F51B5},
    8: {'name': 'Compras', 'icon': 'shopping_bag', 'color': 0xFFE91E63},
    9: {'name': 'Deudas', 'icon': 'money_off', 'color': 0xFFFF5722},
    10: {'name': 'Otros Gastos', 'icon': 'grid_view', 'color': 0xFF9E9E9E},
  };

  static final Map<int, Map<String, dynamic>> incomeCategories = {
    11: {'name': 'Sueldo', 'icon': 'monetization_on', 'color': 0xFF2E7D32},
    12: {'name': 'Negocio', 'icon': 'work', 'color': 0xFF0D47A1},
    13: {'name': 'Inversiones', 'icon': 'trending_up', 'color': 0xFF9C27B0},
    14: {'name': 'Regalos', 'icon': 'card_giftcard', 'color': 0xFFFF4081},
    15: {'name': 'Otros Ingresos', 'icon': 'category', 'color': 0xFF607D8B},
  };

  static final Map<int, Map<String, dynamic>> allCategories = {
    ...expenseCategories,
    ...incomeCategories,
  };

  // --- Helpers for UI ---

  static IconData getIcon(int categoryId) {
    final cat = allCategories[categoryId];
    if (cat == null) return Icons.category;
    return IconMapper.getIcon(cat['icon'] as String?);
  }

  static Color getColor(int categoryId) {
    final cat = allCategories[categoryId];
    if (cat == null) return Colors.grey;
    return Color(cat['color'] as int);
  }

  static String getName(int categoryId) {
    return allCategories[categoryId]?['name'] ?? 'Otros';
  }
}
