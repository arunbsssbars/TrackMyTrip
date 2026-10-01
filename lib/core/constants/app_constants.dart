import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'Track My Trip';
  static const String appTagline = 'Memories, Stoppages & Shared Expenses';

  // OpenStreetMap Tile Server Endpoints (100% Free, Pure OSM Data, No API Key Required, No Watermarks)
  static const String mapTileUrlOsmDe = 'https://tile.openstreetmap.de/{z}/{x}/{y}.png';
  static const String mapTileUrlOsmOrg = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String mapTileUrlOsmFr = 'https://a.tile.openstreetmap.fr/osmfr/{z}/{x}/{y}.png';

  static String getMapTileUrl({bool isDark = false}) {
    return mapTileUrlOsmDe;
  }

  static const List<String> defaultCurrencies = [
    'INR',
    'USD',
    'EUR',
    'GBP',
    'AED',
    'JPY',
    'AUD',
    'CAD',
    'SGD',
    'CHF',
    'NZD',
    'THB',
    'MYR',
    'IDR',
    'SAR',
    'QAR',
    'KWD',
    'OMR',
    'BHD',
    'NPR',
    'LKR',
    'BDT',
    'PKR',
    'KRW',
    'CNY',
    'TRY',
    'BRL',
    'MXN',
    'ZAR',
    'RUB',
  ];

  static const List<String> stoppageCategories = [
    'Viewpoint',
    'Food & Cafe',
    'Hotel & Stay',
    'Gas / Fuel Station',
    'Adventure & Activity',
    'Sightseeing',
    'Toll & Transit',
    'Shopping',
    'Rest Stop',
    'Other',
  ];

  static const List<String> expenseCategories = [
    'Food & Drinks',
    'Fuel / Gas',
    'Accommodation',
    'Activities & Tickets',
    'Transport & Toll',
    'Shopping & Souvenirs',
    'Snacks & Refreshment',
    'Emergency & Misc',
  ];

  /// Robust normalizer ensuring any user-input, OCR, or enum category maps to a standard category
  static String normalizeExpenseCategory(String? rawCategory) {
    if (rawCategory == null || rawCategory.trim().isEmpty) {
      return 'Emergency & Misc';
    }
    final raw = rawCategory.trim();
    for (final standard in expenseCategories) {
      if (standard.toLowerCase() == raw.toLowerCase()) {
        return standard;
      }
    }
    final lower = raw.toLowerCase();
    if (lower.contains('shop') || lower.contains('souvenir') || lower.contains('gift') || lower.contains('cloth') || lower.contains('market') || lower.contains('mall')) {
      return 'Shopping & Souvenirs';
    }
    if (lower.contains('food') || lower.contains('drink') || lower.contains('dinner') || lower.contains('lunch') || lower.contains('breakfast') || lower.contains('restaurant') || lower.contains('cafe')) {
      return 'Food & Drinks';
    }
    if (lower.contains('fuel') || lower.contains('gas') || lower.contains('petrol') || lower.contains('diesel')) {
      return 'Fuel / Gas';
    }
    if (lower.contains('hotel') || lower.contains('stay') || lower.contains('accommodat') || lower.contains('lodge') || lower.contains('room')) {
      return 'Accommodation';
    }
    if (lower.contains('transport') || lower.contains('toll') || lower.contains('transit') || lower.contains('cab') || lower.contains('taxi') || lower.contains('uber') || lower.contains('flight') || lower.contains('train') || lower.contains('bus')) {
      return 'Transport & Toll';
    }
    if (lower.contains('activit') || lower.contains('ticket') || lower.contains('sight') || lower.contains('adventure') || lower.contains('entry') || lower.contains('pass')) {
      return 'Activities & Tickets';
    }
    if (lower.contains('snack') || lower.contains('refresh') || lower.contains('tea') || lower.contains('coffee') || lower.contains('beverage') || lower.contains('water')) {
      return 'Snacks & Refreshment';
    }
    return 'Emergency & Misc';
  }

  static IconData getStoppageIcon(String category) {
    switch (category) {
      case 'Viewpoint':
        return Icons.landscape_rounded;
      case 'Food & Cafe':
        return Icons.restaurant_rounded;
      case 'Hotel & Stay':
        return Icons.hotel_rounded;
      case 'Gas / Fuel Station':
        return Icons.local_gas_station_rounded;
      case 'Adventure & Activity':
        return Icons.kayaking_rounded;
      case 'Sightseeing':
        return Icons.attractions_rounded;
      case 'Toll & Transit':
        return Icons.toll_rounded;
      case 'Shopping':
        return Icons.shopping_bag_rounded;
      case 'Rest Stop':
        return Icons.local_parking_rounded;
      default:
        return Icons.place_rounded;
    }
  }

  static IconData getExpenseIcon(String category) {
    switch (category) {
      case 'Food & Drinks':
        return Icons.restaurant_menu_rounded;
      case 'Fuel / Gas':
        return Icons.local_gas_station_rounded;
      case 'Accommodation':
        return Icons.bed_rounded;
      case 'Activities & Tickets':
        return Icons.confirmation_number_rounded;
      case 'Transport & Toll':
        return Icons.directions_car_rounded;
      case 'Shopping & Souvenirs':
        return Icons.shopping_cart_rounded;
      case 'Snacks & Refreshment':
        return Icons.coffee_rounded;
      default:
        return Icons.receipt_long_rounded;
    }
  }

  static Color getExpenseCategoryColor(String category) {
    final cat = category.toLowerCase().trim();
    if (cat.contains('food') || cat.contains('drink') || cat.contains('cafe') || cat.contains('restaurant')) {
      return const Color(0xFFF59E0B); // Amber/Orange
    } else if (cat.contains('fuel') || cat.contains('gas') || cat.contains('petrol') || cat.contains('diesel')) {
      return const Color(0xFFEF4444); // Crimson Red
    } else if (cat.contains('accommodat') || cat.contains('hotel') || cat.contains('stay') || cat.contains('resort')) {
      return const Color(0xFFFBBF24); // Warm Gold / Amber (high contrast against green)
    } else if (cat.contains('transport') || cat.contains('toll') || cat.contains('cab') || cat.contains('flight') || cat.contains('train') || cat.contains('transit')) {
      return const Color(0xFF60A5FA); // Sky Blue
    } else if (cat.contains('activit') || cat.contains('ticket') || cat.contains('sightseeing') || cat.contains('adventure') || cat.contains('entry')) {
      return const Color(0xFF38BDF8); // Electric Cyan (high contrast against green)
    } else if (cat.contains('shopping') || cat.contains('souvenir') || cat.contains('gift') || cat.contains('cloth')) {
      return const Color(0xFFEC4899); // Pink
    } else if (cat.contains('snack') || cat.contains('refresh') || cat.contains('tea') || cat.contains('coffee')) {
      return const Color(0xFFFB923C); // Bright Orange
    } else if (cat.contains('health') || cat.contains('medical') || cat.contains('pharmacy')) {
      return const Color(0xFF2DD4BF); // Mint Cyan
    } else {
      return const Color(0xFFFB7185); // Rose Coral (high contrast against green)
    }
  }
}
