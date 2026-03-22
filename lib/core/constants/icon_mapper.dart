import 'package:flutter/material.dart';

class IconMapper {
  static IconData getIcon(String? name) {
    if (name == null) return Icons.category;
    
    switch (name.toLowerCase()) {
      case 'restaurant':
        return Icons.restaurant;
      case 'shopping_cart':
        return Icons.shopping_cart;
      case 'home':
        return Icons.home;
      case 'bolt':
        return Icons.bolt;
      case 'directions_bus':
        return Icons.directions_bus;
      case 'directions_car':
        return Icons.directions_car;
      case 'shopping_bag':
        return Icons.shopping_bag;
      case 'spa':
        return Icons.spa;
      case 'play_circle_filled':
        return Icons.play_circle_filled;
      case 'local_hospital':
        return Icons.local_hospital;
      case 'fitness_center':
        return Icons.fitness_center;
      case 'movie':
        return Icons.movie;
      case 'flight':
        return Icons.flight;
      case 'school':
        return Icons.school;
      case 'computer':
        return Icons.computer;
      case 'money_off':
        return Icons.money_off;
      case 'savings':
        return Icons.savings;
      case 'monetization_on':
        return Icons.monetization_on;
      case 'work':
        return Icons.work;
      case 'trending_up':
        return Icons.trending_up;
      case 'card_giftcard':
        return Icons.card_giftcard;
      case 'storefront':
        return Icons.storefront;
      case 'handshake':
        return Icons.handshake;
      case 'category':
        return Icons.category;
      case 'grid_view':
        return Icons.grid_view;
      case 'fastfood':
        return Icons.fastfood;
      case 'live_tv':
        return Icons.live_tv;
      case 'wifi':
        return Icons.wifi;
      case 'water_drop':
        return Icons.water_drop;
      case 'phone_android':
        return Icons.phone_android;
      case 'gamepad':
        return Icons.gamepad;
      default:
        return Icons.category;
    }
  }
}
