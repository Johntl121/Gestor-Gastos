import 'package:flutter/material.dart';
import 'icon_mapper.dart';

class AppCategories {
  static final Map<int, Map<String, dynamic>> expenseCategories = {
    1: {'name': 'Comida', 'icon': 'restaurant', 'color': 0xFFFB8C00},
    2: {'name': 'Mercado', 'icon': 'shopping_cart', 'color': 0xFF9CCC65},
    3: {'name': 'Vivienda', 'icon': 'home', 'color': 0xFF607D8B},
    4: {'name': 'Servicios', 'icon': 'bolt', 'color': 0xFFF57C00},
    5: {'name': 'Transporte', 'icon': 'directions_bus', 'color': 0xFF2196F3},
    6: {'name': 'Vehículo', 'icon': 'directions_car', 'color': 0xFFFF5252},
    7: {'name': 'Compras', 'icon': 'shopping_bag', 'color': 0xFFE91E63},
    8: {'name': 'Cuidado', 'icon': 'spa', 'color': 0xFF9C27B0},
    9: {'name': 'Suscripciones', 'icon': 'play_circle_filled', 'color': 0xFFF44336},
    10: {'name': 'Salud', 'icon': 'local_hospital', 'color': 0xFF009688},
    11: {'name': 'Deportes', 'icon': 'fitness_center', 'color': 0xFF4CAF50},
    12: {'name': 'Entretenimiento', 'icon': 'movie', 'color': 0xFF3F51B5},
    13: {'name': 'Viajes', 'icon': 'flight', 'color': 0xFF00BCD4},
    14: {'name': 'Educación', 'icon': 'school', 'color': 0xFF795548},
    15: {'name': 'Tecnología', 'icon': 'computer', 'color': 0xFF9E9E9E},
    16: {'name': 'Deudas', 'icon': 'money_off', 'color': 0xFFFF5722},
    17: {'name': 'Ahorro', 'icon': 'savings', 'color': 0xFFCDDC39},
    20: {'name': 'Otros', 'icon': 'grid_view', 'color': 0xFF607D8B},
  };

  static final Map<int, Map<String, dynamic>> incomeCategories = {
    18: {'name': 'Sueldo', 'icon': 'monetization_on', 'color': 0xFF2E7D32},
    19: {'name': 'Negocio', 'icon': 'work', 'color': 0xFF0D47A1},
    21: {'name': 'Inversiones', 'icon': 'trending_up', 'color': 0xFF9C27B0},
    22: {'name': 'Regalos', 'icon': 'card_giftcard', 'color': 0xFFFF4081},
    23: {'name': 'Ventas', 'icon': 'storefront', 'color': 0xFFFB8C00},
    24: {'name': 'Préstamos', 'icon': 'handshake', 'color': 0xFF009688},
    25: {'name': 'Otros', 'icon': 'category', 'color': 0xFF607D8B},
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
