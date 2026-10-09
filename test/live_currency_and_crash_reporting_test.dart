import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart';
import 'package:trackmytrip/core/services/crash_reporting_service.dart';
import 'package:trackmytrip/core/services/live_currency_service.dart';
import 'package:trackmytrip/core/services/map_tile_cache_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LiveCurrencyService Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Falls back to static rates when uninitialized or offline', () {
      final inrRate = LiveCurrencyService.getRateToInr('INR');
      expect(inrRate, equals(1.0));

      final usdRate = LiveCurrencyService.getRateToInr('USD');
      expect(usdRate, greaterThan(80.0));

      final eurRate = LiveCurrencyService.getRateToInr('EUR');
      expect(eurRate, greaterThan(85.0));
    });

    test('Converts correctly using exchange rates', () {
      final convertedUsdToInr = LiveCurrencyService.convert(10.0, 'USD', 'INR');
      expect(convertedUsdToInr, greaterThan(800.0));

      final sameCurrency = LiveCurrencyService.convert(150.0, 'USD', 'USD');
      expect(sameCurrency, equals(150.0));

      final convertedUsdToEur = LiveCurrencyService.convert(100.0, 'USD', 'EUR');
      expect(convertedUsdToEur, greaterThan(0.0));
      expect(convertedUsdToEur, isNot(isNaN));
    });

    test('Initializes with cached rates in SharedPreferences', () async {
      final mockRates = {'USD': 85.5, 'EUR': 92.0, 'GBP': 108.2};
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      SharedPreferences.setMockInitialValues({
        'cached_fx_rates_inr_v1': jsonEncode(mockRates),
        'cached_fx_rates_timestamp_v1': nowMs,
      });

      await LiveCurrencyService.initialize();

      expect(LiveCurrencyService.getRateToInr('USD'), equals(85.5));
      expect(LiveCurrencyService.getRateToInr('EUR'), equals(92.0));
      expect(LiveCurrencyService.getRateToInr('GBP'), equals(108.2));

      final telemetry = LiveCurrencyService.getTelemetry();
      expect(telemetry['isLive'], isTrue);
      expect(telemetry['cachedCurrenciesCount'], equals(3));
    });
  });

  group('CrashReportingService Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Records errors, captures stack trace and stores in-memory & SharedPreferences', () async {
      await CrashReportingService.initialize();
      await CrashReportingService.clearCrashReports();

      CrashReportingService.setCustomKey('userId', 'user_abc_123');
      CrashReportingService.setCustomKey('activeTripId', 'trip_delhi_shimla');

      await CrashReportingService.recordError(
        Exception('Network connection timeout'),
        StackTrace.current,
        reason: 'HTTP Sync Engine',
        fatal: false,
      );

      final reports = CrashReportingService.getCrashReports();
      expect(reports.length, equals(1));
      expect(reports.first.message, contains('HTTP Sync Engine'));
      expect(reports.first.message, contains('Network connection timeout'));
      expect(reports.first.customKeys['userId'], equals('user_abc_123'));
      expect(reports.first.customKeys['activeTripId'], equals('trip_delhi_shimla'));
      expect(reports.first.isFatal, isFalse);

      final json = reports.first.toJson();
      final roundtrip = CrashReport.fromJson(json);
      expect(roundtrip.id, equals(reports.first.id));
      expect(roundtrip.message, equals(reports.first.message));
    });

    test('Caps in-memory crash log at 50 entries', () async {
      await CrashReportingService.initialize();
      await CrashReportingService.clearCrashReports();

      for (int i = 0; i < 60; i++) {
        await CrashReportingService.recordError(
          'Error #$i',
          StackTrace.empty,
          reason: 'Stress Loop',
          fatal: false,
        );
      }

      final reports = CrashReportingService.getCrashReports();
      expect(reports.length, equals(50));
      expect(reports.first.message, contains('Error #59'));

      await CrashReportingService.clearCrashReports();
      expect(CrashReportingService.getCrashReports().isEmpty, isTrue);
    });
  });

  group('Regional Offline Map Tile Pack Tests', () {
    test('Calculates tile coordinates for regional preset coordinates', () {
      final manaliPoints = [
        const LatLng(32.2396, 77.1887),
        const LatLng(32.3166, 77.1575),
        const LatLng(32.3716, 77.2466),
      ];

      final tiles = MapTileCacheService.calculateTileCoordinates(points: manaliPoints);
      expect(tiles, isNotEmpty);
      expect(tiles.length, greaterThan(0));
    });
  });
}
