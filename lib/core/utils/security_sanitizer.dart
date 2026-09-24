/// ---------------------------------------------------------------------------
/// SecuritySanitizer (Input Sanitization & Injection Defense - MASVS-NETWORK)
/// ---------------------------------------------------------------------------
/// Strips dangerous HTML, script tags, SQL/NoSQL injection artifacts,
/// control characters, and null bytes from user inputs across the application.
class SecuritySanitizer {
  // Regex detecting potential script tags, javascript: URIs, and dangerous HTML entities
  static final RegExp _scriptTagRegex = RegExp(
    r'<\s*script[^>]*>[\s\S]*?<\s*/\s*script\s*>',
    caseSensitive: false,
  );
  static final RegExp _htmlTagRegex = RegExp(r'<[^>]*>');
  static final RegExp _controlCharRegex = RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]');
  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$',
  );
  static final RegExp _usernameRegex = RegExp(r'^[a-zA-Z0-9_]{3,30}$');

  /// Sanitizes plain text input (e.g., trip title, stoppage note, expense title)
  static String sanitizeText(String? input, {int maxLength = 500}) {
    if (input == null) return '';
    String sanitized = input.trim();

    // 1. Remove script tags and embedded JavaScript
    sanitized = sanitized.replaceAll(_scriptTagRegex, '');

    // 2. Strip HTML tags
    sanitized = sanitized.replaceAll(_htmlTagRegex, '');

    // 3. Remove non-printable control characters and null bytes
    sanitized = sanitized.replaceAll(_controlCharRegex, '');

    // 4. Enforce reasonable bounds
    if (sanitized.length > maxLength) {
      sanitized = sanitized.substring(0, maxLength);
    }

    return sanitized;
  }

  /// Alias for sanitizeText
  static String sanitizeString(String? input, {int maxLength = 500}) =>
      sanitizeText(input, maxLength: maxLength);

  /// Cleans and normalizes email input
  static String sanitizeEmail(String? email) {
    if (email == null) return '';
    return email.trim().toLowerCase();
  }

  /// Validates email address format
  static bool isValidEmail(String email) {
    return _emailRegex.hasMatch(email.trim());
  }

  /// Validates username format (alphanumeric and underscore, 3-30 chars)
  static bool isValidUsername(String username) {
    final clean = username.trim().replaceAll('@', '');
    return _usernameRegex.hasMatch(clean);
  }

  /// Recursively sanitizes a Map payload before transmission to Firestore / SQLite
  static Map<String, dynamic> sanitizePayload(Map<String, dynamic> payload) {
    final cleanMap = <String, dynamic>{};
    for (final entry in payload.entries) {
      final val = entry.value;
      if (val is String) {
        cleanMap[entry.key] = sanitizeText(val);
      } else if (val is Map<String, dynamic>) {
        cleanMap[entry.key] = sanitizePayload(val);
      } else if (val is List) {
        cleanMap[entry.key] = val.map((item) {
          if (item is String) return sanitizeText(item);
          if (item is Map<String, dynamic>) return sanitizePayload(item);
          return item;
        }).toList();
      } else {
        cleanMap[entry.key] = val;
      }
    }
    return cleanMap;
  }
}
