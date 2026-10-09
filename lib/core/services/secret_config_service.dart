import 'dart:io';
import 'package:flutter/foundation.dart';

/// Centralized, enterprise-grade secret and environment configuration manager.
/// Safely manages environment secrets with zero plain-text leaks in logs or diagnostics.
class SecretConfigService {
  static final Map<String, String> _envVars = {};
  static bool _initialized = false;

  /// Default keys managed by the service
  static const String keyAppEnv = 'APP_ENV';
  static const String keyGoogleMapsApiKey = 'GOOGLE_MAPS_API_KEY';
  static const String keyFirebaseAppId = 'FIREBASE_APP_ID';
  static const String keyFirebaseProjectId = 'FIREBASE_PROJECT_ID';
  static const String keyVaultPepper = 'APP_VAULT_PEPPER';

  /// Initializes the secret configuration from an in-memory map or local .env file
  static Future<void> initialize({Map<String, String>? overrides}) async {
    _envVars.clear();

    if (overrides != null) {
      _envVars.addAll(overrides);
      _initialized = true;
      return;
    }

    // Attempt to load from local .env file safely
    try {
      final envFile = File('.env');
      if (await envFile.exists()) {
        final lines = await envFile.readAsLines();
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
          final separatorIndex = trimmed.indexOf('=');
          if (separatorIndex > 0) {
            final key = trimmed.substring(0, separatorIndex).trim();
            final value = trimmed.substring(separatorIndex + 1).trim();
            // Strip outer quotes if present
            final sanitizedValue = _stripOuterQuotes(value);
            _envVars[key] = sanitizedValue;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SecretConfigService] Fallback: No .env loaded: $e');
      }
    }

    // Fallback: Populate platform environment variables if available
    try {
      for (final key in [keyAppEnv, keyGoogleMapsApiKey, keyFirebaseAppId, keyFirebaseProjectId, keyVaultPepper]) {
        if (!_envVars.containsKey(key)) {
          final fromPlatform = Platform.environment[key];
          if (fromPlatform != null && fromPlatform.isNotEmpty) {
            _envVars[key] = fromPlatform;
          }
        }
      }
    } catch (_) {}

    _initialized = true;
  }

  static String _stripOuterQuotes(String value) {
    if ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))) {
      if (value.length >= 2) {
        return value.substring(1, value.length - 1);
      }
    }
    return value;
  }

  /// Retrieves a secret or environment variable by key with fallback
  static String get(String key, {String fallback = ''}) {
    final val = _envVars[key];
    if (val != null && val.isNotEmpty) {
      return val;
    }
    return fallback;
  }

  /// Whether a specific secret key is configured and non-empty
  static bool isConfigured(String key) {
    final val = _envVars[key];
    return val != null && val.trim().isNotEmpty && !val.contains('YOUR_') && !val.contains('placeholder');
  }

  static String get appEnv => get(keyAppEnv, fallback: kReleaseMode ? 'production' : 'development');
  static bool get isProduction => appEnv.toLowerCase() == 'production';

  static String get googleMapsApiKey => get(keyGoogleMapsApiKey);
  static String get firebaseAppId => get(keyFirebaseAppId);
  static String get firebaseProjectId => get(keyFirebaseProjectId, fallback: 'trackmytrip-app');
  static String get vaultPepper => get(keyVaultPepper, fallback: 'trackmytrip_default_salt_2026');

  /// Masks a sensitive secret for safe logging, UI display, or diagnostic reporting.
  /// Example: 'AIzaSyD12345678901234567890' -> 'AIza...7890'
  static String maskSecret(String? secret, {int visibleLeading = 4, int visibleTrailing = 4}) {
    if (secret == null || secret.trim().isEmpty) {
      return '[NOT CONFIGURED]';
    }
    final trimmed = secret.trim();
    if (trimmed.length <= (visibleLeading + visibleTrailing)) {
      return '••••••••';
    }
    final lead = trimmed.substring(0, visibleLeading);
    final trail = trimmed.substring(trimmed.length - visibleTrailing);
    return '$lead••••$trail';
  }

  /// Returns a sanitized diagnostic map of all registered secrets with safe masking
  static Map<String, dynamic> getMaskedSecretsAuditReport() {
    return {
      'appEnv': appEnv,
      'isProduction': isProduction,
      'googleMapsConfigured': isConfigured(keyGoogleMapsApiKey),
      'googleMapsApiKeyMasked': maskSecret(get(keyGoogleMapsApiKey)),
      'firebaseAppIdConfigured': isConfigured(keyFirebaseAppId),
      'firebaseAppIdMasked': maskSecret(get(keyFirebaseAppId)),
      'vaultPepperConfigured': isConfigured(keyVaultPepper),
      'totalKeysRegistered': _envVars.length,
      'isInitialized': _initialized,
    };
  }

  /// Manually injects variables (useful for test isolation)
  @visibleForTesting
  static void setMockVariables(Map<String, String> mockVars) {
    _envVars.clear();
    _envVars.addAll(mockVars);
    _initialized = true;
  }
}
