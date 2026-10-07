import 'package:flutter_test/flutter_test.dart';
import 'package:trackmytrip/core/services/tombstone_service.dart';
import 'package:trackmytrip/core/utils/currency_formatter.dart';
import 'package:trackmytrip/core/utils/date_formatter.dart';
import 'package:trackmytrip/models/proximity_alert.dart';
import 'package:intl/intl.dart';

void main() {
  group('CurrencyFormatter defensive guards (Loop 46)', () {
    test('NaN and Infinity render as zero', () {
      expect(CurrencyFormatter.format(double.nan, currency: 'INR'), '₹0.00');
      expect(CurrencyFormatter.format(double.infinity, currency: 'USD'), '\$0.00');
      expect(CurrencyFormatter.format(double.negativeInfinity, currency: 'EUR'), '€0.00');
    });

    test('negative amounts place the sign before the symbol', () {
      expect(CurrencyFormatter.format(-50, currency: 'INR'), '-₹50.00');
      expect(CurrencyFormatter.format(-1234.5, currency: 'USD'), '-\$1,234.50');
    });

    test('tiny negative values collapse to positive zero', () {
      expect(CurrencyFormatter.format(-0.001, currency: 'INR'), '₹0.00');
    });

    test('INR keeps lakh grouping', () {
      expect(CurrencyFormatter.format(1234567.8, currency: 'INR'), '₹12,34,567.80');
    });

    test('junk currency codes fall back to rupee symbol', () {
      expect(CurrencyFormatter.getCurrencySymbol('null'), '₹');
      expect(CurrencyFormatter.getCurrencySymbol('NOT_A_CODE'), '₹');
      expect(CurrencyFormatter.getCurrencySymbol(''), '₹');
      expect(CurrencyFormatter.getCurrencySymbol(null), '₹');
    });

    test('unknown but valid ISO codes are echoed in upper case', () {
      expect(CurrencyFormatter.getCurrencySymbol('vnd'), 'VND ');
    });

    test('roundTo2Decimals is NaN safe', () {
      expect(CurrencyFormatter.roundTo2Decimals(double.nan), 0.0);
      expect(CurrencyFormatter.roundTo2Decimals(10.005), closeTo(10.01, 0.001));
    });

    test('formatCompact handles negatives and non-finite', () {
      expect(CurrencyFormatter.formatCompact(double.nan, currency: 'INR'), '₹0');
      expect(CurrencyFormatter.formatCompact(-5000, currency: 'INR'), '-₹5K');
    });
  });

  group('DateFormatter defensive guards (Loop 47)', () {
    final now = DateTime(2026, 10, 3, 0, 30);

    test('earlier same calendar day is Today', () {
      expect(
        DateFormatter.formatRelativeOrTime(DateTime(2026, 10, 3, 0, 5), now: now),
        startsWith('Today at'),
      );
    });

    test('late previous evening is Yesterday even within 24h', () {
      expect(
        DateFormatter.formatRelativeOrTime(DateTime(2026, 10, 2, 23, 50), now: now),
        startsWith('Yesterday at'),
      );
    });

    test('next calendar day is Tomorrow, not Yesterday', () {
      expect(
        DateFormatter.formatRelativeOrTime(DateTime(2026, 10, 4, 9, 0), now: now),
        startsWith('Tomorrow at'),
      );
    });

    test('timeAgo tolerates small future clock skew', () {
      expect(DateFormatter.timeAgo(now.add(const Duration(seconds: 30)), now: now), 'Just now');
    });

    test('timeAgo shows a date for far-future timestamps', () {
      expect(DateFormatter.timeAgo(DateTime(2026, 12, 25), now: now), 'Dec 25');
    });

    test('timeAgo includes the year for previous years', () {
      expect(DateFormatter.timeAgo(DateTime(2024, 5, 1), now: now), 'May 1, 2024');
    });

    test('timeAgo relative buckets', () {
      expect(DateFormatter.timeAgo(now.subtract(const Duration(minutes: 5)), now: now), '5m ago');
      expect(DateFormatter.timeAgo(now.subtract(const Duration(hours: 3)), now: now), '3h ago');
      expect(DateFormatter.timeAgo(now.subtract(const Duration(days: 2)), now: now), '2d ago');
    });

    test('formatTripDateRange swaps reversed inputs', () {
      expect(
        DateFormatter.formatTripDateRange(DateTime(2026, 10, 10), DateTime(2026, 10, 3)),
        'Oct 3 - Oct 10, 2026',
      );
    });

    test('formatTripDateRange shows both years across a year boundary', () {
      expect(
        DateFormatter.formatTripDateRange(DateTime(2025, 12, 28), DateTime(2026, 1, 4)),
        'Dec 28, 2025 - Jan 4, 2026',
      );
    });

    test('DateFormatter converts UTC timestamps to local time without hour drift', () {
      final utcTime = DateTime.utc(2026, 10, 7, 9, 0); // 09:00 UTC
      final expectedLocalTime = utcTime.toLocal();

      final formattedTimeOnly = DateFormatter.formatTimeOnly(utcTime);
      final expectedHourString = DateFormat('h:mm a').format(expectedLocalTime);
      expect(formattedTimeOnly, expectedHourString);

      final formattedDateTime = DateFormatter.formatDateTime(utcTime);
      final expectedDateTimeString = DateFormat('MMM d, y • h:mm a').format(expectedLocalTime);
      expect(formattedDateTime, expectedDateTimeString);

      final formattedDateAndTime = DateFormatter.formatDateAndTime(utcTime, showYear: true);
      expect(formattedDateAndTime, expectedDateTimeString);
    });

    test('ProximityAlert.fromJson normalizes UTC timestamp to local time', () {
      final alert = ProximityAlert.fromJson({
        'id': 'alert_1',
        'tripId': 'trip_1',
        'type': 'general',
        'title': 'Test Alert',
        'message': 'Test',
        'senderMemberId': 'u1',
        'senderName': 'User',
        'timestamp': '2026-10-07T09:00:00.000Z',
      });

      expect(alert.timestamp.isUtc, false);
      expect(alert.timestamp, DateTime.utc(2026, 10, 7, 9, 0).toLocal());
    });
  });

  group('TombstoneService.compact (Loop 45)', () {
    test('strips blank and placeholder ids and trims whitespace', () {
      final ids = {'trip_1', ' trip_2 ', '', '   ', 'null', 'NULL'};
      final removed = TombstoneService.compact(ids);
      expect(ids, {'trip_1', 'trip_2'});
      expect(removed, 4);
    });

    test('never removes valid tombstones', () {
      final ids = {'trip_a', 'trip_b', 'trip_c'};
      expect(TombstoneService.compact(ids), 0);
      expect(ids.length, 3);
    });

    test('deduplicates ids that only differ by whitespace', () {
      final ids = {'trip_x', ' trip_x'};
      TombstoneService.compact(ids);
      expect(ids, {'trip_x'});
    });
  });
}
