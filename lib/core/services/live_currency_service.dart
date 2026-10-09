import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_logger.dart';
import '../utils/currency_formatter.dart';

/// Service providing live, cached foreign exchange rates with graceful offline fallback
class LiveCurrencyService {
  static const String _prefsKeyRates = 'cached_fx_rates_inr_v1';
  static const String _prefsKeyTimestamp = 'cached_fx_rates_timestamp_v1';
  static const Duration _cacheTtl = Duration(hours: 24);

  static final Map<String, double> _inMemoryRates = {};
  static DateTime? _lastFetchedAt;
  static bool _isFetching = false;

  /// Free, zero-auth public Open Exchange Rates endpoint base INR
  static const String _fxApiUrl = 'https://open.er-api.com/v6/latest/INR';

  /// Initializes cached rates from local disk storage on app startup
  static Future<void> initialize({SharedPreferences? prefs}) async {
    try {
      final sp = prefs ?? await SharedPreferences.getInstance();
      final cachedJson = sp.getString(_prefsKeyRates);
      final timestampMs = sp.getInt(_prefsKeyTimestamp);

      if (cachedJson != null && timestampMs != null) {
        final decoded = jsonDecode(cachedJson) as Map<String, dynamic>;
        _inMemoryRates.clear();
        decoded.forEach((key, value) {
          if (value is num) {
            _inMemoryRates[key.toUpperCase()] = value.toDouble();
          }
        });
        _lastFetchedAt = DateTime.fromMillisecondsSinceEpoch(timestampMs);
      }

      // Check if cache expired or empty, fetch in background without blocking
      if (shouldRefresh) {
        fetchLatestRates().catchError((e) {
          AppLogger.debug('Silent background FX rate fetch notice: $e');
          return false;
        });
      }
    } catch (e) {
      AppLogger.debug('FX rate cache initialization notice: $e');
    }
  }

  /// Whether rates should be refreshed (cache older than 24h or missing)
  static bool get shouldRefresh {
    if (_lastFetchedAt == null || _inMemoryRates.isEmpty) return true;
    return DateTime.now().difference(_lastFetchedAt!) > _cacheTtl;
  }

  /// Fetches the latest live exchange rates from the network and caches them
  static Future<bool> fetchLatestRates({http.Client? client}) async {
    if (_isFetching) return false;
    _isFetching = true;

    final httpClient = client ?? http.Client();
    try {
      final response = await httpClient
          .get(Uri.parse(_fxApiUrl))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final rates = body['rates'] as Map<String, dynamic>?;

        if (rates != null && rates.isNotEmpty) {
          _inMemoryRates.clear();
          // API returns: 1 INR = X foreign currency.
          // To get 1 Foreign Currency = Y INR: Y = 1 / X
          rates.forEach((curr, val) {
            if (val is num && val > 0) {
              final foreignRatePerInr = val.toDouble();
              final inrPerForeign = 1.0 / foreignRatePerInr;
              _inMemoryRates[curr.toUpperCase()] = inrPerForeign;
            }
          });
          _inMemoryRates['INR'] = 1.0;
          _lastFetchedAt = DateTime.now();

          // Persist to local disk
          final sp = await SharedPreferences.getInstance();
          await sp.setString(_prefsKeyRates, jsonEncode(_inMemoryRates));
          await sp.setInt(_prefsKeyTimestamp, _lastFetchedAt!.millisecondsSinceEpoch);

          AppLogger.info('Successfully updated live FX rates for ${_inMemoryRates.length} currencies.');
          return true;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[LiveCurrencyService] FX fetch failed (using fallback rates): $e');
      }
    } finally {
      if (client == null) httpClient.close();
      _isFetching = false;
    }
    return false;
  }

  /// Synchronously returns the exchange rate of 1 unit of foreign currency to INR
  /// Uses live/cached rate if available, otherwise falls back to static baseline rate.
  static double getRateToInr(String currency) {
    final cur = currency.trim().toUpperCase();
    if (cur == 'INR') return 1.0;

    final cached = _inMemoryRates[cur];
    if (cached != null && cached > 0 && !cached.isNaN && !cached.isInfinite) {
      return cached;
    }

    return CurrencyFormatter.getEstimatedRateToInr(cur);
  }

  /// Converts an amount between any two currencies using live cached rates
  static double convert(double amount, String fromCurrency, String toCurrency) {
    if (amount.isNaN || amount.isInfinite) return 0.0;
    final from = fromCurrency.trim().toUpperCase();
    final to = toCurrency.trim().toUpperCase();
    if (from == to) return CurrencyFormatter.roundTo2Decimals(amount);

    final fromRateToInr = getRateToInr(from);
    final toRateToInr = getRateToInr(to);

    if (toRateToInr <= 0) return CurrencyFormatter.roundTo2Decimals(amount);
    final inrAmount = amount * fromRateToInr;
    return CurrencyFormatter.roundTo2Decimals(inrAmount / toRateToInr);
  }

  /// Diagnostics telemetry report for Super Admin / debugging
  static Map<String, dynamic> getTelemetry() {
    return {
      'cachedCurrenciesCount': _inMemoryRates.length,
      'lastFetchedAt': _lastFetchedAt?.toIso8601String() ?? 'Never',
      'isLive': _inMemoryRates.isNotEmpty,
      'sampleUsdInr': getRateToInr('USD'),
      'sampleEurInr': getRateToInr('EUR'),
    };
  }
}
