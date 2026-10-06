import 'dart:io';

/// Represents a detected token drift violation where an arbitrary pixel value
/// should be snapped to standard 4-point/8-point design grid tokens.
class AqilTokenDrift {
  final String filePath;
  final int lineNumber;
  final String originalLine;
  final double foundValue;
  final double suggestedTokenValue;
  final String tokenName;

  const AqilTokenDrift({
    required this.filePath,
    required this.lineNumber,
    required this.originalLine,
    required this.foundValue,
    required this.suggestedTokenValue,
    required this.tokenName,
  });

  @override
  String toString() =>
      '$filePath:$lineNumber -> $foundValue px drifts from token $tokenName ($suggestedTokenValue px)';
}

/// Audits Dart files for hardcoded, off-grid dimensional values (padding, margin, sizedbox, border radius)
/// and proposes or automatically applies nearest 4-pt grid tokens (4, 8, 12, 16, 20, 24, 32, 40, 48, 64).
class AqilTokenDriftAuditor {
  static final Map<double, String> tokenGrid = {
    0.0: 'AppSpacing.none',
    4.0: 'AppSpacing.xs',
    8.0: 'AppSpacing.sm',
    12.0: 'AppSpacing.md',
    16.0: 'AppSpacing.base',
    20.0: 'AppSpacing.lg',
    24.0: 'AppSpacing.xl',
    32.0: 'AppSpacing.xxl',
    40.0: 'AppSpacing.huge',
    48.0: 'AppSpacing.massive',
    64.0: 'AppSpacing.colossal',
  };

  /// Finds the nearest standard design token value for any arbitrary dimension.
  static ({double value, String name}) findNearestToken(double raw) {
    double bestDiff = double.infinity;
    double bestVal = 8.0;
    String bestName = 'AppSpacing.sm';

    for (final entry in tokenGrid.entries) {
      final diff = (raw - entry.key).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        bestVal = entry.key;
        bestName = entry.value;
      }
    }
    return (value: bestVal, name: bestName);
  }

  /// Scans a Dart file and returns all instances where raw padding/spacing/radius
  /// values deviate from the 4-point design system grid.
  static List<AqilTokenDrift> auditFile(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) return [];

    final drifts = <AqilTokenDrift>[];
    final lines = file.readAsLinesSync();

    // Regex matching raw numerical dimensions like EdgeInsets.all(13), SizedBox(width: 17), BorderRadius.circular(9)
    final dimensionRegex = RegExp(
      r'(?:EdgeInsets\.(?:all|symmetric|only)\([^)]*?|SizedBox\s*\([^)]*?(?:width|height):\s*|BorderRadius\.circular\()([0-9]+(?:\.[0-9]+)?)',
    );

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.trim().startsWith('//')) continue; // Skip comments

      for (final match in dimensionRegex.allMatches(line)) {
        final rawStr = match.group(1);
        if (rawStr != null) {
          final val = double.tryParse(rawStr);
          if (val != null && val > 0 && val <= 128) {
            // Check if it's already an exact 4-point grid value (multiple of 4)
            if (val % 4 != 0) {
              final nearest = findNearestToken(val);
              drifts.add(AqilTokenDrift(
                filePath: filePath,
                lineNumber: i + 1,
                originalLine: line.trim(),
                foundValue: val,
                suggestedTokenValue: nearest.value,
                tokenName: nearest.name,
              ));
            }
          }
        }
      }
    }

    return drifts;
  }

  /// Audits all Dart files in a directory or project.
  static List<AqilTokenDrift> auditDirectory(String dirPath) {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return [];

    final allDrifts = <AqilTokenDrift>[];
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart') && !entity.path.contains('.g.dart')) {
        allDrifts.addAll(auditFile(entity.path));
      }
    }
    return allDrifts;
  }

  /// Automatically snaps off-grid dimensions to nearest 4-pt grid values.
  static int applyTokenSnapping(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) return 0;

    String content = file.readAsStringSync();
    int replacements = 0;

    // Pattern capturing EdgeInsets.all(13) or SizedBox(height: 17)
    final dimensionRegex = RegExp(
      r'((?:EdgeInsets\.(?:all|symmetric|only)\([^)]*?|SizedBox\s*\([^)]*?(?:width|height):\s*|BorderRadius\.circular\())([0-9]+(?:\.[0-9]+)?)',
    );

    final updated = content.replaceAllMapped(dimensionRegex, (match) {
      final prefix = match.group(1)!;
      final rawStr = match.group(2)!;
      final val = double.tryParse(rawStr);
      if (val != null && val > 0 && val <= 128 && val % 4 != 0) {
        final nearest = findNearestToken(val);
        replacements++;
        final snappedValStr = nearest.value.toInt() == nearest.value ? '${nearest.value.toInt()}' : '${nearest.value}';
        return '$prefix$snappedValStr';
      }
      return match.group(0)!;
    });

    if (replacements > 0) {
      file.writeAsStringSync(updated);
    }
    return replacements;
  }
}
