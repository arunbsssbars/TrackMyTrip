import 'package:flutter_test/flutter_test.dart';
import 'package:trackmytrip/models/expense.dart';
import 'package:trackmytrip/models/settlement.dart';
import 'package:trackmytrip/models/stoppage.dart';
import 'package:trackmytrip/models/trip.dart';
import 'package:trackmytrip/models/trip_member.dart';
import 'package:trackmytrip/models/trip_audit_log.dart';

void main() {
  group('Schema & Model Normalization Defensive Fallbacks (Loop 7 & ACHS)', () {
    test('Expense.fromJson handles nulls and missing fields safely without throwing', () {
      final corruptedJson = <String, dynamic>{
        'id': null,
        'title': null,
        'totalAmount': null,
        'currency': null,
        'splits': null,
        'createdAt': null,
      };

      final expense = Expense.fromJson(corruptedJson);

      expect(expense.id, '');
      expect(expense.title, 'Untitled Expense');
      expect(expense.totalAmount, 0.0);
      expect(expense.currency, 'INR');
      expect(expense.splits, isEmpty);
      expect(expense.createdAt, isA<DateTime>());
    });

    test('Settlement.fromJson handles null amounts and dates gracefully', () {
      final corruptedJson = <String, dynamic>{
        'id': null,
        'amount': null,
        'currency': null,
        'settledAt': 'not_a_valid_iso_date',
        'isAdvance': null,
      };

      final settlement = Settlement.fromJson(corruptedJson);

      expect(settlement.id, '');
      expect(settlement.amount, 0.0);
      expect(settlement.currency, 'INR');
      expect(settlement.isAdvance, false);
      expect(settlement.settledAt, isA<DateTime>());
    });

    test('Stoppage.fromJson handles null coordinates and missing names safely', () {
      final corruptedJson = <String, dynamic>{
        'id': null,
        'name': null,
        'latitude': null,
        'longitude': null,
        'arrivedAt': null,
      };

      final stoppage = Stoppage.fromJson(corruptedJson);

      expect(stoppage.id, '');
      expect(stoppage.name, 'Waypoint');
      expect(stoppage.latitude, 0.0);
      expect(stoppage.longitude, 0.0);
      expect(stoppage.arrivedAt, isA<DateTime>());
    });

    test('Trip.fromJson handles null dates, members, and ratings gracefully', () {
      final corruptedJson = <String, dynamic>{
        'id': null,
        'title': null,
        'startDate': 'invalid_date',
        'endDate': null,
        'members': null,
      };

      final trip = Trip.fromJson(corruptedJson);

      expect(trip.id, '');
      expect(trip.title, 'Untitled Trip');
      expect(trip.members, isEmpty);
      expect(trip.startDate, isA<DateTime>());
      expect(trip.endDate, isA<DateTime>());
    });

    test('TripMember.fromJson handles null ids and names safely', () {
      final corruptedJson = <String, dynamic>{
        'id': null,
        'name': null,
        'latitude': null,
      };

      final member = TripMember.fromJson(corruptedJson);

      expect(member.id, '');
      expect(member.name, 'Traveler');
      expect(member.latitude, isNull);
    });

    test('TripAuditLog.fromJson handles null fields without throwing', () {
      final corruptedJson = <String, dynamic>{
        'id': null,
        'actionType': null,
        'itemTitle': null,
        'amount': null,
      };

      final log = TripAuditLog.fromJson(corruptedJson);

      expect(log.id, '');
      expect(log.actionType, 'action');
      expect(log.itemTitle, 'Item');
      expect(log.amount, isNull);
    });
  });
}
