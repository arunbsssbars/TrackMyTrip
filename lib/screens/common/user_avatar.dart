import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Reusable user & companion avatar component with initials and photo fallback.
class UserAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final String? colorHex;
  final double size;
  final Border? border;
  final double? fontSize;
  final TextStyle? textStyle;

  const UserAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.colorHex,
    this.size = 36.0,
    this.border,
    this.fontSize,
    this.textStyle,
  });

  static Color parseColor(String? hexString, {String? seedName}) {
    if (hexString != null && hexString.isNotEmpty) {
      try {
        String clean = hexString.replaceAll('#', '');
        if (!clean.startsWith('0x') && !clean.startsWith('0X')) {
          if (clean.length == 6) {
            clean = 'FF$clean';
          }
          clean = '0x$clean';
        }
        return Color(int.parse(clean));
      } catch (_) {}
    }

    if (seedName != null && seedName.isNotEmpty) {
      final colors = [
        const Color(0xFF0F766E), // Teal
        const Color(0xFFF97316), // Orange
        const Color(0xFF3B82F6), // Blue
        const Color(0xFFEC4899), // Pink
        const Color(0xFF10B981), // Green
        const Color(0xFF8B5CF6), // Purple
        const Color(0xFFEAB308), // Yellow
        const Color(0xFF6366F1), // Indigo
      ];
      final hash = seedName.codeUnits.fold(0, (prev, elem) => prev + elem);
      return colors[hash % colors.length];
    }

    return AppTheme.primary;
  }

  static String getInitials(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return '?';
    final parts = clean.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return clean[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final bgCol = parseColor(colorHex, seedName: name);
    final initials = getInitials(name);
    final double computedFontSize = fontSize ?? (size * 0.4);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgCol,
        shape: BoxShape.circle,
        border: border,
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl != null && imageUrl!.isNotEmpty
          ? Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildInitials(initials, computedFontSize),
            )
          : _buildInitials(initials, computedFontSize),
    );
  }

  Widget _buildInitials(String initials, double effectiveFontSize) {
    return Center(
      child: Text(
        initials,
        style: textStyle ??
            TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: effectiveFontSize,
              letterSpacing: -0.5,
            ),
      ),
    );
  }
}
