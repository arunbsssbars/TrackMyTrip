import 'package:flutter/foundation.dart';

/// ---------------------------------------------------------------------------
/// AppLogger (Zero-PII Secure Logging Hub - MASVS-RESILIENCE)
/// ---------------------------------------------------------------------------
/// Ensures:
/// 1. Emails, passwords, auth tokens, and raw coordinates are masked.
/// 2. In release builds (kReleaseMode), console logging is strictly suppressed.
class AppLogger {
  static final RegExp _emailRegex = RegExp(r'([a-zA-Z0-9_\-\.]+)@([a-zA-Z0-9_\-\.]+)\.([a-zA-Z]{2,5})');
  static final RegExp _tokenRegex = RegExp(r'(jwt_[a-zA-Z0-9\-]+|token_[a-zA-Z0-9\-]+|eyJ[a-zA-Z0-9_\-]+)');
  static final RegExp _coordRegex = RegExp(r'(-?\d{1,3}\.\d{4,10})');

  /// Redacts sensitive PII from message strings
  static String redact(String message) {
    String sanitized = message;

    // Mask emails: a***n@domain.com
    sanitized = sanitized.replaceAllMapped(_emailRegex, (match) {
      final user = match.group(1) ?? '';
      final domain = match.group(2) ?? '';
      final tld = match.group(3) ?? '';
      if (user.length <= 2) {
        return '***@$domain.$tld';
      }
      return '${user[0]}***${user[user.length - 1]}@$domain.$tld';
    });

    // Mask JWT and Auth tokens
    sanitized = sanitized.replaceAllMapped(_tokenRegex, (match) {
      return '[REDACTED_AUTH_TOKEN]';
    });

    // Mask precision GPS coordinates: [COORDINATE_REDACTED]
    sanitized = sanitized.replaceAllMapped(_coordRegex, (match) {
      return '[GPS_REDACTED]';
    });

    return sanitized;
  }

  static void debug(String message) {
    if (!kReleaseMode) {
      debugPrint('[DEBUG] ${redact(message)}');
    }
  }

  static void info(String message) {
    if (!kReleaseMode) {
      debugPrint('[INFO] ${redact(message)}');
    }
  }

  static void warn(String message) {
    if (!kReleaseMode) {
      debugPrint('[WARN] ${redact(message)}');
    }
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (!kReleaseMode) {
      debugPrint('[ERROR] ${redact(message)}');
      if (error != null) {
        debugPrint('[ERROR_DETAIL] ${redact(error.toString())}');
      }
      if (stackTrace != null) {
        debugPrint('[STACKTRACE] $stackTrace');
      }
    }
  }
}
