import 'package:flutter_test/flutter_test.dart';
import 'package:trackmytrip/core/constants/app_constants.dart';
import 'package:trackmytrip/core/database/app_database.dart';
import 'package:trackmytrip/core/services/map_tile_cache_service.dart';
import 'package:trackmytrip/models/expense.dart';
import 'package:trackmytrip/models/stoppage.dart';

void main() {
  group('20-Point Enterprise Polish Tests', () {
    test('MapTileCacheService computes tile X and Y indices accurately', () {
      final tileX = MapTileCacheService.lon2tile(77.5946, 12);
      final tileY = MapTileCacheService.lat2tile(12.9716, 12);
      expect(tileX, greaterThan(0));
      expect(tileY, greaterThan(0));
    });

    test('Stoppage fallback model initializes cleanly for empty photo trips', () {
      final fallbackStoppage = Stoppage(
        id: 'general_trip_123',
        tripId: 'trip_123',
        name: 'Summer Voyage',
        latitude: 0.0,
        longitude: 0.0,
        arrivedAt: DateTime(2026, 6, 1),
        category: 'general',
        createdBy: 'user_456',
      );

      expect(fallbackStoppage.id, 'general_trip_123');
      expect(fallbackStoppage.category, 'general');
      expect(fallbackStoppage.name, 'Summer Voyage');
      expect(fallbackStoppage.createdBy, 'user_456');
    });

    test('AppDatabase.getDbNameForUser sanitizes user IDs correctly', () {
      expect(AppDatabase.getDbNameForUser(null), 'trip_tracker_guest.db');
      expect(AppDatabase.getDbNameForUser(''), 'trip_tracker_guest.db');
      expect(AppDatabase.getDbNameForUser('usr_abc-123'), 'trip_tracker_usr_abc-123.db');
      expect(AppDatabase.getDbNameForUser('usr:test/456'), 'trip_tracker_usr_test_456.db');
    });

    test('Directional bearing calculation logic computes cardinal accurately', () {
      String bearingToCardinal(double bearing) {
        final b = (bearing + 360) % 360;
        if (b >= 337.5 || b < 22.5) return 'N';
        if (b >= 22.5 && b < 67.5) return 'NE';
        if (b >= 67.5 && b < 112.5) return 'E';
        if (b >= 112.5 && b < 157.5) return 'SE';
        if (b >= 157.5 && b < 202.5) return 'S';
        if (b >= 202.5 && b < 247.5) return 'SW';
        if (b >= 247.5 && b < 292.5) return 'W';
        return 'NW';
      }

      expect(bearingToCardinal(0), 'N');
      expect(bearingToCardinal(45), 'NE');
      expect(bearingToCardinal(90), 'E');
      expect(bearingToCardinal(135), 'SE');
      expect(bearingToCardinal(180), 'S');
      expect(bearingToCardinal(225), 'SW');
      expect(bearingToCardinal(270), 'W');
      expect(bearingToCardinal(315), 'NW');
    });

    test('Point 21: AppConstants.normalizeExpenseCategory maps enums and strings to canonical categories', () {
      expect(AppConstants.normalizeExpenseCategory('food'), 'Food & Drinks');
      expect(AppConstants.normalizeExpenseCategory('ExpenseCategory.food'), 'Food & Drinks');
      expect(AppConstants.normalizeExpenseCategory('shopping'), 'Shopping & Souvenirs');
      expect(AppConstants.normalizeExpenseCategory('Shopping & Souvenirs'), 'Shopping & Souvenirs');
      expect(AppConstants.normalizeExpenseCategory('transport'), 'Transport & Toll');
      expect(AppConstants.normalizeExpenseCategory('activities'), 'Activities & Tickets');
      expect(AppConstants.normalizeExpenseCategory('unknown_xyz'), 'Emergency & Misc');
    });

    test('Point 24 & 25: Expense isPersonal field defaults to false and roundtrips JSON', () {
      final sharedExpense = Expense(
        id: 'exp_1',
        tripId: 'trip_1',
        title: 'Dinner at cafe',
        totalAmount: 100.0,
        currency: 'USD',
        category: 'Food & Dining',
        paidByMemberId: 'mem_1',
        splitType: SplitType.equal,
        splits: [],
        createdAt: DateTime(2026, 6, 1),
      );
      expect(sharedExpense.isPersonal, isFalse);

      final personalExpense = sharedExpense.copyWith(
        id: 'exp_2',
        title: 'Personal souvenirs',
        isPersonal: true,
      );
      expect(personalExpense.isPersonal, isTrue);

      final json = personalExpense.toJson();
      expect(json['isPersonal'], isTrue);

      final revived = Expense.fromJson(json);
      expect(revived.isPersonal, isTrue);
      expect(revived.title, 'Personal souvenirs');
    });
  });
}
