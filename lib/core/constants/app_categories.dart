import 'package:flutter/material.dart';

class AppCategories {
  static final Map<int, Map<String, dynamic>> expenseCategories = {
    1: {'name': 'Comida', 'icon': Icons.restaurant, 'color': Colors.orange},
    2: {
      'name': 'Mercado',
      'icon': Icons.shopping_cart,
      'color': Colors.lightGreen
    },
    3: {'name': 'Vivienda', 'icon': Icons.home, 'color': Colors.blueGrey},
    4: {
      'name': 'Servicios',
      'icon': Icons.bolt,
      'color': Colors.amber.shade700
    },
    5: {
      'name': 'Transporte',
      'icon': Icons.directions_bus,
      'color': Colors.blue
    },
    6: {
      'name': 'Vehículo',
      'icon': Icons.directions_car,
      'color': Colors.redAccent
    },
    7: {'name': 'Compras', 'icon': Icons.shopping_bag, 'color': Colors.pink},
    8: {'name': 'Cuidado', 'icon': Icons.spa, 'color': Colors.purple},
    9: {
      'name': 'Suscripciones',
      'icon': Icons.play_circle_filled,
      'color': Colors.red
    },
    10: {'name': 'Salud', 'icon': Icons.local_hospital, 'color': Colors.teal},
    11: {
      'name': 'Deportes',
      'icon': Icons.fitness_center,
      'color': Colors.green
    },
    12: {
      'name': 'Entretenimiento',
      'icon': Icons.movie,
      'color': Colors.indigo
    },
    13: {'name': 'Viajes', 'icon': Icons.flight, 'color': Colors.cyan},
    14: {'name': 'Educación', 'icon': Icons.school, 'color': Colors.brown},
    15: {'name': 'Tecnología', 'icon': Icons.computer, 'color': Colors.grey},
    16: {'name': 'Deudas', 'icon': Icons.money_off, 'color': Colors.deepOrange},
    17: {'name': 'Ahorro', 'icon': Icons.savings, 'color': Colors.lime},
    20: {'name': 'Otros', 'icon': Icons.grid_view, 'color': Colors.blueGrey},
  };

  static final Map<int, Map<String, dynamic>> incomeCategories = {
    18: {
      'name': 'Sueldo',
      'icon': Icons.monetization_on,
      'color': Colors.green.shade800
    },
    19: {'name': 'Negocio', 'icon': Icons.work, 'color': Colors.blue.shade900},
    21: {
      'name': 'Inversiones',
      'icon': Icons.trending_up,
      'color': Colors.purple
    },
    22: {
      'name': 'Regalos',
      'icon': Icons.card_giftcard,
      'color': Colors.pinkAccent
    },
    23: {'name': 'Ventas', 'icon': Icons.storefront, 'color': Colors.orange},
    24: {'name': 'Préstamos', 'icon': Icons.handshake, 'color': Colors.teal},
    25: {'name': 'Otros', 'icon': Icons.category, 'color': Colors.blueGrey},
  };

  static final Map<int, Map<String, dynamic>> allCategories = {
    ...expenseCategories,
    ...incomeCategories,
  };
}
