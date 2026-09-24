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
}
