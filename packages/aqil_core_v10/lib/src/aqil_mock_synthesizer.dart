/// Automated Mock Data & Fixture Synthesizer (AQIL Frontier 5).
///
/// Synthesizes realistic, deterministic mock datasets and fixtures for UI widgets,
/// domain entities, and data models to allow instant testing of complex screens.
class AqilMockSynthesizer {
  /// Generates a realistic mock value for a given field name and expected type.
  static dynamic synthesizeValue(String fieldName, String typeName) {
    final lowerName = fieldName.toLowerCase();
    final lowerType = typeName.toLowerCase();

    // 1. Strings
    if (lowerType == 'string') {
      if (lowerName.contains('email')) return 'sarah.connor@antigravity.io';
      if (lowerName.contains('name')) return 'Sarah Connor';
      if (lowerName.contains('title')) return 'Enterprise Architecture Lead';
      if (lowerName.contains('id')) return 'USR-0042';
      if (lowerName.contains('phone')) return '+1-555-0199';
      if (lowerName.contains('url') || lowerName.contains('image')) {
        return 'https://images.unsplash.com/photo-1534528741775-53994a69daeb';
      }
      if (lowerName.contains('address')) return '42 Innovation Way, Silicon Park';
      if (lowerName.contains('description')) {
        return 'Comprehensive system architecture documentation and verification plan.';
      }
      return 'Mock $fieldName';
    }

    // 2. Numbers
    if (lowerType == 'int') {
      if (lowerName.contains('age')) return 32;
      if (lowerName.contains('count')) return 5;
      if (lowerName.contains('status') || lowerName.contains('code')) return 200;
      return 42;
    }

    if (lowerType == 'double') {
      if (lowerName.contains('price') || lowerName.contains('amount')) return 199.99;
      if (lowerName.contains('rating')) return 4.8;
      if (lowerName.contains('latitude')) return 37.7749;
      if (lowerName.contains('longitude')) return -122.4194;
      return 12.5;
    }

    // 3. Booleans
    if (lowerType == 'bool') {
      if (lowerName.contains('error') || lowerName.contains('deleted')) return false;
      return true;
    }

    // 4. DateTime
    if (lowerType == 'datetime') {
      return DateTime(2026, 10, 5, 12, 0);
    }

    // 5. Lists
    if (lowerType.startsWith('list')) {
      return ['Item 1', 'Item 2', 'Item 3'];
    }

    return null;
  }

  /// Synthesizes a mock map for an entity schema.
  static Map<String, dynamic> synthesizeEntity(Map<String, String> fieldSchema) {
    final result = <String, dynamic>{};
    for (final entry in fieldSchema.entries) {
      result[entry.key] = synthesizeValue(entry.key, entry.value);
    }
    return result;
  }
}
