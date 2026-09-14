import 'package:flutter/material.dart';
import 'app_currencies.dart';

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
  static List<Map<String, String>> get currencies {
    return AppCurrencies.all
        .map((c) => {
              'symbol': c.symbol,
              'name': c.name,
              'code': c.code,
            })
        .toList();
  }

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
  static double getBudgetSuggestionForCurrency(
      double baseAmountPEN, String selectedCurrency) {
    // The defaultRate is how many PEN equals 1 unit of the currency.
    // So to convert PEN to that currency, we divide by the defaultRate.
    final rate = AppCurrencies.defaultRateFor(selectedCurrency);
    final raw = baseAmountPEN / rate;

    // Default rounding logic
    double rounding = 100.0;
    if (selectedCurrency == '\$' ||
        selectedCurrency == '€' ||
        selectedCurrency == '£') {
      rounding = 10.0;
    } else if (selectedCurrency == '¥' || selectedCurrency == '₽') {
      rounding = 1000.0;
    } else if (selectedCurrency == 'S/') {
      rounding = 50.0;
    } else if (selectedCurrency == 'R\$') {
      rounding = 50.0;
    }

    if (raw > 15000) {
      return (raw / 1000).round() * 1000.0;
    } else if (raw < 100) {
      return (raw / 5).round() * 5.0;
    } else {
      return (raw / rounding).round() * rounding;
    }
  }
}
