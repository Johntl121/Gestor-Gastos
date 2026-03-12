import 'package:flutter/material.dart';

class AppOnboardingData {
  /// Lista de Avatares disponibles para el perfil de usuario.
  static const List<String> avatars = [
    '😎',
    '🦸',
    '🕵️',
    '🤖',
    '🦁',
    '👽',
    '🦊',
    '🐱',
    '🐼',
    '🐨',
    '🐯',
    '🐮',
    '🐷',
    '🐸',
    '🦄',
    '🐲',
    '👻',
    '💀',
    '👾',
    '🧘',
    '🚵',
    '🤸',
    '🧖',
    '🧟',
    '🧛',
    '🧝',
    '🧞',
    '🧜',
    '⚽',
    '🏀',
    '🎮',
    '🎵',
    '🎨',
    '📷'
  ];

  /// Lista de Monedas admitidas en el paso de Configuración Inicial (Welcome).
  static const List<Map<String, String>> currencies = [
    {'symbol': 'S/', 'name': 'Sol', 'code': 'PEN'},
    {'symbol': '\$', 'name': 'Dólar', 'code': 'USD'},
    {'symbol': '€', 'name': 'Euro', 'code': 'EUR'},
    {'symbol': 'mx\$', 'name': 'Peso', 'code': 'MXN'},
    {'symbol': '₽', 'name': 'Rublo', 'code': 'RUB'},
    {'symbol': '£', 'name': 'Libra', 'code': 'GBP'},
    {'symbol': '¥', 'name': 'Yen', 'code': 'JPY'},
    {'symbol': 'R\$', 'name': 'Real', 'code': 'BRL'},
  ];

  /// Listado de perfiles de usuario y sub-textos en el paso de Selector de Perfil.
  static const List<Map<String, dynamic>> profiles = [
    {
      'title': 'Estudiante',
      'subtitle': 'Gestionando lo justo.',
      'icon': Icons.school
    },
    {
      'title': 'Profesional',
      'subtitle': 'Sueldo fijo y metas.',
      'icon': Icons.work
    },
    {
      'title': 'Freelance',
      'subtitle': 'Ingresos variables.',
      'icon': Icons.rocket_launch
    },
    {'title': 'Hogar', 'subtitle': 'Finanzas familiares.', 'icon': Icons.home},
  ];

  /// Recomendaciones y sugerencias dinámicas de Presupuesto (Paso Budget),
  /// según el perfil que seleccione el usuario.
  static List<Map<String, dynamic>> getBudgetSuggestions(String userProfile) {
    switch (userProfile) {
      case 'Estudiante':
        return [
          {'amount': 500.0, 'desc': 'Básico'},
          {'amount': 800.0, 'desc': 'Equilibrado'},
          {'amount': 1200.0, 'desc': 'Holgado'}
        ];
      case 'Profesional':
        return [
          {'amount': 1500.0, 'desc': 'Conservador'},
          {'amount': 2500.0, 'desc': 'Estándar'},
          {'amount': 4000.0, 'desc': 'Alto Nivel'}
        ];
      case 'Freelance':
        return [
          {'amount': 1800.0, 'desc': 'Ajustado'},
          {'amount': 3000.0, 'desc': 'Promedio'},
          {'amount': 5000.0, 'desc': 'Excelente'}
        ];
      case 'Hogar':
        return [
          {'amount': 2000.0, 'desc': 'Esencial'},
          {'amount': 3500.0, 'desc': 'Normal'},
          {'amount': 6000.0, 'desc': 'Confort'}
        ];
      default:
        return [
          {'amount': 1000.0, 'desc': 'Mínimo'},
          {'amount': 2400.0, 'desc': 'Medio'},
          {'amount': 5000.0, 'desc': 'Máximo'}
        ];
    }
  }

  /// Calcula dinámicamente el presupuesto balanceado de acuerdo a la moneda seleccionada.
  /// Ej: si en Soles la base son 1000, un USD (usando factor x0.27) te aconsejará $270.
  static double getBudgetSuggestionForCurrency(
      double baseAmountPEN, String selectedCurrency) {
    double factor = 1.0;
    double rounding = 100.0;

    switch (selectedCurrency) {
      case '\$': // USD
        factor = 0.27; // 1 PEN ~= 0.27 USD
        rounding = 10.0;
        break;
      case '€': // EUR
        factor = 0.25; // 1 PEN ~= 0.25 EUR
        rounding = 10.0;
        break;
      case '£': // GBP
        factor = 0.21;
        rounding = 10.0;
        break;
      case 'mx\$': // MXN
        factor = 5.3;
        rounding = 100.0;
        break;
      case 'R\$': // BRL
        factor = 1.35;
        rounding = 50.0;
        break;
      case '₽': // RUB
        factor = 25.0;
        rounding = 1000.0;
        break;
      case '¥': // JPY
        factor = 40.0;
        rounding = 1000.0;
        break;
      case 'S/': // PEN (Base)
      default:
        factor = 1.0;
        rounding = 50.0;
    }

    double raw = baseAmountPEN * factor;

    if (raw > 15000) {
      return (raw / 1000).round() * 1000.0;
    } else if (raw < 100) {
      return (raw / 5).round() * 5.0;
    } else {
      return (raw / rounding).round() * rounding;
    }
  }
}
