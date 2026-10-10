import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Industry-standard, multi-tier environment secrets manager for Flutter.
/// 
/// Resolution Hierarchy:
/// 1. Compile-Time Definitions (`String.fromEnvironment`) via `--dart-define` / `--dart-define-from-file=.env`
/// 2. Programmatic in-memory overrides (e.g. for testing)
/// 3. Local disk `.env` file (Desktop, CLI, Unit Tests)
/// 4. Flutter Asset Bundle `rootBundle.loadString('.env')` (if bundled as an asset)
/// 5. Operating System platform environment (`Platform.environment`, guarded for non-web)
/// 6. Default fallback values
class SecretConfigService {
  static final Map<String, String> _envVars = {};
  static bool _initialized = false;

  // Standard Configuration Keys
  static const String keyAppEnv = 'APP_ENV';
  static const String keyAppName = 'APP_NAME';
  static const String keyAppBaseUrl = 'APP_BASE_URL';
  static const String keyGoogleMapsApiKey = 'GOOGLE_MAPS_API_KEY';
  static const String keyFirebaseAppId = 'FIREBASE_APP_ID';
  static const String keyFirebaseProjectId = 'FIREBASE_PROJECT_ID';
  static const String keyFirebaseApiKey = 'FIREBASE_API_KEY';
  static const String keyVaultPepper = 'APP_VAULT_PEPPER';
  static const String keyLogLevel = 'LOG_LEVEL';
  static const String keyEnableCrashReporting = 'ENABLE_CRASH_REPORTING';
  static const String keyEnableAnalytics = 'ENABLE_ANALYTICS';
  static const String keyCiRunnerId = 'CI_RUNNER_ID';
  static const String keyCloudinaryCloudName = 'CLOUDINARY_CLOUD_NAME';
  static const String keyCloudinaryUploadPreset = 'CLOUDINARY_UPLOAD_PRESET';
  static const String keyCloudinaryApiKey = 'CLOUDINARY_API_KEY';
  static const String keyCloudinaryApiSecret = 'CLOUDINARY_API_SECRET';

  /// Initializes configuration from all available standard layers.
  static Future<void> initialize({Map<String, String>? overrides}) async {
    _envVars.clear();

    if (overrides != null) {
      _envVars.addAll(overrides);
      _initialized = true;
      return;
    }

    // Layer 1: Check compile-time environment variables
    _loadCompileTimeDefaults();

    // Layer 2: Load from local disk `.env` file (if accessible on Desktop/CLI/Tests)
    if (!kIsWeb) {
      await _loadFromLocalFile();
    }

    // Layer 3: Attempt to load from bundled assets if configured
    await _loadFromAssetBundle();

    // Layer 4: Populate from Platform.environment where available
    if (!kIsWeb) {
      _loadFromPlatformEnvironment();
    }

    _initialized = true;
  }

  /// Ingests compile-time definitions passed via `--dart-define` or `--dart-define-from-file=.env`
  static void _loadCompileTimeDefaults() {
    const knownKeys = [
      keyAppEnv,
      keyAppName,
      keyAppBaseUrl,
      keyGoogleMapsApiKey,
      keyFirebaseAppId,
      keyFirebaseProjectId,
      keyFirebaseApiKey,
      keyVaultPepper,
      keyLogLevel,
      keyEnableCrashReporting,
      keyEnableAnalytics,
      keyCiRunnerId,
      keyCloudinaryCloudName,
      keyCloudinaryUploadPreset,
      keyCloudinaryApiKey,
      keyCloudinaryApiSecret,
    ];

    for (final key in knownKeys) {
      final val = String.fromEnvironment(key, defaultValue: '');
      if (val.isNotEmpty) {
        _envVars[key] = val;
      }
    }
  }

  /// Attempts to read `.env` from local file system
  static Future<void> _loadFromLocalFile() async {
    try {
      final file = File('.env');
      if (await file.exists()) {
        final content = await file.readAsString();
        _parseAndMerge(content);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SecretConfigService] Notice: Local .env file lookup skipped: $e');
      }
    }
  }

  /// Attempts to read `.env` from Flutter rootBundle assets if present
  static Future<void> _loadFromAssetBundle() async {
    try {
      final assetContent = await rootBundle.loadString('.env');
      if (assetContent.isNotEmpty) {
        _parseAndMerge(assetContent);
      }
    } catch (_) {
      // Gracefully expected when .env is not included in pubspec assets
    }
  }

  /// Reads from OS environment variables on supported desktop/server platforms
  static void _loadFromPlatformEnvironment() {
    try {
      final env = Platform.environment;
      for (final entry in env.entries) {
        // Do not overwrite existing higher-priority keys
        if (!_envVars.containsKey(entry.key) && entry.value.isNotEmpty) {
          _envVars[entry.key] = entry.value;
        }
      }
    } catch (_) {
      // Ignored on platforms where Platform.environment is unsupported
    }
  }

  /// Parses raw dotenv content according to standard dotenv specifications
  static void _parseAndMerge(String rawContent) {
    final lines = rawContent.split(RegExp(r'\r?\n'));
    for (final line in lines) {
      final trimmed = line.trim();
      // Skip empty lines or pure comment lines
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

      // Strip optional 'export ' prefix
      var processed = trimmed;
      if (processed.startsWith('export ') && processed.length > 7) {
        processed = processed.substring(7).trim();
      }

      final eqIdx = processed.indexOf('=');
      if (eqIdx <= 0) continue;

      final key = processed.substring(0, eqIdx).trim();
      var value = processed.substring(eqIdx + 1).trim();

      // Handle comments and quote stripping
      value = _cleanValue(value);

      // Do not overwrite keys if compile-time define already took precedence
      if (!_envVars.containsKey(key) || _envVars[key]!.isEmpty) {
        _envVars[key] = value;
      }
    }
  }

  /// Cleans and extracts dotenv value stripping quotes and trailing inline comments
  static String _cleanValue(String value) {
    if (value.isEmpty) return '';

    // If enclosed in double quotes: "hello # world"
    if (value.startsWith('"') && value.endsWith('"') && value.length >= 2) {
      return value.substring(1, value.length - 1).replaceAll(r'\"', '"');
    }

    // If enclosed in single quotes: 'hello # world'
    if (value.startsWith("'") && value.endsWith("'") && value.length >= 2) {
      return value.substring(1, value.length - 1).replaceAll(r"\'", "'");
    }

    // If unquoted, strip trailing inline comments starting with '#'
    final commentIdx = value.indexOf('#');
    if (commentIdx >= 0) {
      value = value.substring(0, commentIdx).trim();
    }

    return value;
  }

  // =================================================================
  // Type-Safe Value Accessors
  // =================================================================

  /// Retrieves a string configuration value by key with optional fallback
  static String get(String key, {String fallback = ''}) {
    final val = _envVars[key];
    if (val != null && val.isNotEmpty) {
      return val;
    }
    return fallback;
  }

  /// Retrieves a boolean configuration value
  static bool getBool(String key, {bool fallback = false}) {
    final val = _envVars[key]?.trim().toLowerCase();
    if (val == null || val.isEmpty) return fallback;
    if (val == 'true' || val == '1' || val == 'yes' || val == 'enabled') return true;
    if (val == 'false' || val == '0' || val == 'no' || val == 'disabled') return false;
    return fallback;
  }

  /// Retrieves an integer configuration value
  static int getInt(String key, {int fallback = 0}) {
    final val = _envVars[key]?.trim();
    if (val == null || val.isEmpty) return fallback;
    return int.tryParse(val) ?? fallback;
  }

  /// Retrieves a double configuration value
  static double getDouble(String key, {double fallback = 0.0}) {
    final val = _envVars[key]?.trim();
    if (val == null || val.isEmpty) return fallback;
    return double.tryParse(val) ?? fallback;
  }

  /// Checks if a key exists and is non-empty
  static bool has(String key) {
    final val = _envVars[key];
    return val != null && val.trim().isNotEmpty;
  }

  /// Checks if a key is configured with a real value (not an unreplaced template placeholder)
  static bool isConfigured(String key) {
    final val = _envVars[key];
    if (val == null || val.trim().isEmpty) return false;
    final lower = val.toLowerCase();
    if (lower.contains('your_') ||
        lower.contains('placeholder') ||
        lower.contains('example') ||
        lower.contains('change_in_production')) {
      return false;
    }
    return true;
  }

  // =================================================================
  // Strongly-Typed Standard App Properties
  // =================================================================

  static String get appEnv => get(keyAppEnv, fallback: kReleaseMode ? 'production' : 'development');
  static bool get isProduction => appEnv.toLowerCase() == 'production';
  static bool get isStaging => appEnv.toLowerCase() == 'staging';
  static bool get isDevelopment => appEnv.toLowerCase() == 'development';

  static String get appName => get(keyAppName, fallback: 'TrackMyTrip');
  static String get appBaseUrl => get(keyAppBaseUrl, fallback: 'https://trackmytrip.app');

  static String get googleMapsApiKey => get(keyGoogleMapsApiKey);
  static String get firebaseAppId => get(keyFirebaseAppId);
  static String get firebaseProjectId => get(keyFirebaseProjectId, fallback: 'trackmytrip-sync-2026');
  static String get firebaseApiKey => get(keyFirebaseApiKey);

  static String get vaultPepper => get(keyVaultPepper, fallback: 'trackmytrip_default_pepper_salt_2026');
  static String get logLevel => get(keyLogLevel, fallback: kDebugMode ? 'debug' : 'info');

  static bool get isCrashReportingEnabled => getBool(keyEnableCrashReporting, fallback: true);
  static bool get isAnalyticsEnabled => getBool(keyEnableAnalytics, fallback: true);
  static String get ciRunnerId => get(keyCiRunnerId, fallback: 'local_env');

  // Cloudinary Zero-Card Media Config
  static String get cloudinaryCloudName => get(keyCloudinaryCloudName, fallback: 'dcj4v7toh');
  static String get cloudinaryUploadPreset => get(keyCloudinaryUploadPreset, fallback: 'TrackMyTrip');
  static String get cloudinaryApiKey => get(keyCloudinaryApiKey);
  static String get cloudinaryApiSecret => get(keyCloudinaryApiSecret);
  static bool get isCloudinaryConfigured {
    final name = cloudinaryCloudName;
    final preset = cloudinaryUploadPreset;
    if (name.isEmpty || preset.isEmpty || name == '[NOT CONFIGURED]') return false;
    final nameLower = name.toLowerCase();
    final presetLower = preset.toLowerCase();
    return !nameLower.contains('your_') &&
        !presetLower.contains('your_') &&
        !nameLower.contains('placeholder') &&
        !presetLower.contains('placeholder');
  }

  // =================================================================
  // Zero-Leak Secret Masking & Security Audit
  // =================================================================

  /// Masks a sensitive secret for safe logging, UI display, or diagnostic reporting.
  /// Example: 'AIzaSyD12345678901234567890' -> 'AIza••••7890'
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
      'appName': appName,
      'googleMapsConfigured': isConfigured(keyGoogleMapsApiKey),
      'googleMapsApiKeyMasked': maskSecret(get(keyGoogleMapsApiKey)),
      'firebaseAppIdConfigured': isConfigured(keyFirebaseAppId),
      'firebaseAppIdMasked': maskSecret(get(keyFirebaseAppId)),
      'firebaseProjectId': firebaseProjectId,
      'cloudinaryConfigured': isCloudinaryConfigured,
      'cloudinaryCloudName': cloudinaryCloudName.isNotEmpty ? cloudinaryCloudName : '[NOT CONFIGURED]',
      'cloudinaryPresetMasked': maskSecret(cloudinaryUploadPreset),
      'vaultPepperConfigured': isConfigured(keyVaultPepper),
      'crashReportingEnabled': isCrashReportingEnabled,
      'analyticsEnabled': isAnalyticsEnabled,
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

  /// Clears in-memory variables and unsets initialization flag
  @visibleForTesting
  static void reset() {
    _envVars.clear();
    _initialized = false;
  }
}
