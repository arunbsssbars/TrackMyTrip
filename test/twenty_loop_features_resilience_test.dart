import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trackmytrip/models/expense_split.dart';
import 'package:trackmytrip/models/stoppage.dart';
import 'package:trackmytrip/core/utils/currency_formatter.dart';
import 'package:trackmytrip/core/utils/debt_simplifier.dart';
import 'package:trackmytrip/core/services/proximity_alert_service.dart';
import 'package:trackmytrip/core/services/tombstone_service.dart';
import 'package:trackmytrip/screens/common/user_avatar.dart';

void main() {
  group('Loop 1 & 2: ExpenseSplit & CurrencyFormatter Edge Cases', () {
    test('ExpenseSplit.fromJson safely handles null/missing fields without TypeError', () {
      final json = <String, dynamic>{
        'memberId': null,
        'allocatedAmount': null,
        'percentage': null,
      };
      final split = ExpenseSplit.fromJson(json);
      expect(split.memberId, isEmpty);
      expect(split.allocatedAmount, 0.0);
      expect(split.isIncluded, isTrue);
    });

    test('CurrencyFormatter.convertEstimated guards against NaN, infinite, and zero rates', () {
      expect(CurrencyFormatter.convertEstimated(double.nan, 'USD', 'INR'), 0.0);
      expect(CurrencyFormatter.convertEstimated(double.infinity, 'USD', 'INR'), 0.0);
      expect(CurrencyFormatter.convertEstimated(100.0, 'USD', 'USD'), 100.0);
      final inr = CurrencyFormatter.convertEstimated(10.0, 'USD', 'INR');
      expect(inr, greaterThan(800.0));
    });
  });

  group('Loop 3: Stoppage Duration & Deterministic Ordering', () {
    test('Stoppage handles clock drift / negative duration safely', () {
      final stop = Stoppage(
        id: 'stop_1',
        tripId: 'trip_1',
        name: 'Hilltop View',
        latitude: 32.2,
        longitude: 77.1,
        category: 'Viewpoint',
        arrivedAt: DateTime(2026, 5, 1, 14, 0),
        departedAt: DateTime(2026, 5, 1, 13, 45), // Clock rolled backwards
        createdBy: 'usr_me',
      );
      expect(stop.duration, Duration.zero);
      expect(stop.formattedDuration, '0m');
    });

    test('Stoppage sorting uses arrivedAt, orderIndex, and id deterministically', () {
      final t = DateTime(2026, 5, 1, 10, 0);
      final stopA = Stoppage(
        id: 'stop_a',
        tripId: 'trip_1',
        name: 'A',
        latitude: 10,
        longitude: 10,
        category: 'Food',
        arrivedAt: t,
        orderIndex: 2,
        createdBy: 'usr',
      );
      final stopB = Stoppage(
        id: 'stop_b',
        tripId: 'trip_1',
        name: 'B',
        latitude: 10,
        longitude: 10,
        category: 'Food',
        arrivedAt: t,
        orderIndex: 1,
        createdBy: 'usr',
      );

      final list = [stopA, stopB]..sort((a, b) {
        final cmp = a.arrivedAt.compareTo(b.arrivedAt);
        if (cmp != 0) return cmp;
        final orderCmp = a.orderIndex.compareTo(b.orderIndex);
        if (orderCmp != 0) return orderCmp;
        return a.id.compareTo(b.id);
      });

      expect(list.first.id, 'stop_b');
      expect(list.last.id, 'stop_a');
    });
  });

  group('Loop 4: Proximity Alert GPS Validation', () {
    test('isValidCoordinate correctly rejects Null Island and NaN/infinite coordinates', () {
      expect(ProximityAlertService.isValidCoordinate(0.0, 0.0), isFalse);
      expect(ProximityAlertService.isValidCoordinate(null, 77.0), isFalse);
      expect(ProximityAlertService.isValidCoordinate(double.nan, 77.0), isFalse);
      expect(ProximityAlertService.isValidCoordinate(95.0, 77.0), isFalse);
      expect(ProximityAlertService.isValidCoordinate(32.2, 77.1), isTrue);
    });
  });

  group('Loop 5: Debt Simplifier & Balances', () {
    test('simplifyDebts handles cyclical balances without infinite loop', () {
      final balances = {
        'user_1': -50.0,
        'user_2': 50.0,
      };
      final transfers = DebtSimplifier.simplifyDebts(balances);
      expect(transfers.length, 1);
      expect(transfers.first.fromMemberId, 'user_1');
      expect(transfers.first.toMemberId, 'user_2');
      expect(transfers.first.amount, 50.0);
    });
  });

  group('Loop 6: Tombstone Service Normalization', () {
    test('compact prunes null and undefined placeholders', () {
      final set = {'trip_1', 'null', 'undefined', '  ', 'trip_2'};
      final removed = TombstoneService.compact(set);
      expect(removed, 3);
      expect(set, contains('trip_1'));
      expect(set, contains('trip_2'));
      expect(set, isNot(contains('null')));
      expect(set, isNot(contains('undefined')));
    });
  });

  group('Loop 17: UserAvatar Color & Unicode Initials', () {
    test('parseColor handles 3-char, 6-char, and hashtag hex strings safely', () {
      final c1 = UserAvatar.parseColor('#F00');
      expect(c1.red, 255);
      expect(c1.green, 0);

      final c2 = UserAvatar.parseColor('#0F766E');
      expect(c2, isA<Color>());

      final c3 = UserAvatar.parseColor('invalid_hex', seedName: 'Pankaj');
      expect(c3, isA<Color>());
    });

    test('getInitials handles multi-byte emoji names without surrogate split errors', () {
      expect(UserAvatar.getInitials('Arun Sharma'), 'AS');
      expect(UserAvatar.getInitials('⭐ Star Traveler'), '⭐S');
      expect(UserAvatar.getInitials(''), '?');
    });
  });
}
