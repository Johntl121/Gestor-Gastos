import 'package:flutter/material.dart';
import 'icon_mapper.dart';

class AppCategories {
  static final Map<int, Map<String, dynamic>> expenseCategories = {
    1: {'name': 'Alimentación', 'icon': 'restaurant', 'color': 0xFFF28B82}, // Pastel Red / Soft Coral
    2: {'name': 'Vivienda', 'icon': 'home', 'color': 0xFF81C995}, // Soft Mint / Light Green
    3: {'name': 'Transporte', 'icon': 'directions_bus', 'color': 0xFF8AB4F8}, // Soft Sky Blue
    4: {'name': 'Servicios', 'icon': 'bolt', 'color': 0xFFFDE293}, // Soft Yellow / Pale Gold
    5: {'name': 'Salud', 'icon': 'local_hospital', 'color': 0xFF80DEEA}, // Soft Cyan / Pale Teal
    6: {'name': 'Educación', 'icon': 'school', 'color': 0xFFD7CCC8}, // Soft Sand / Warm Grey
    7: {'name': 'Entretenimiento', 'icon': 'movie', 'color': 0xFFC58AF9}, // Soft Lilac / Lavender
    8: {'name': 'Compras', 'icon': 'shopping_bag', 'color': 0xFFF48FB1}, // Soft Pink / Blush
    9: {'name': 'Deudas', 'icon': 'money_off', 'color': 0xFFE57373}, // Soft Crimson
    10: {'name': 'Otros Gastos', 'icon': 'grid_view', 'color': 0xFFB0BEC5}, // Soft Blue-Grey
  };

  static final Map<int, Map<String, dynamic>> incomeCategories = {
    11: {'name': 'Sueldo', 'icon': 'monetization_on', 'color': 0xFFA5D6A7}, // Soft Emerald / Mint
    12: {'name': 'Negocio', 'icon': 'work', 'color': 0xFF9FA8DA}, // Soft Indigo
    13: {'name': 'Inversiones', 'icon': 'trending_up', 'color': 0xFFCE93D8}, // Soft Amethyst / Purple
    14: {'name': 'Regalos', 'icon': 'card_giftcard', 'color': 0xFFFFAB91}, // Soft Peach / Coral
    15: {'name': 'Otros Ingresos', 'icon': 'category', 'color': 0xFF90A4AE}, // Soft Cool Grey
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
