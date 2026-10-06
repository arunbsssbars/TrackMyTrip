import 'package:flutter/material.dart';

/// Single avatar participant for [AqilAvatarGroup].
class AqilAvatarItem {
  final String id;
  final String name;
  final String? imageUrl;
  final Color? backgroundColor;

  const AqilAvatarItem({
    required this.id,
    required this.name,
    this.imageUrl,
    this.backgroundColor,
  });

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return '?';
  }
}

/// Overlapping collaborative facepile / avatar stack (Figma, Slack, Linear standard).
///
/// Features negative horizontal offset, crisp outer cutout border ring, and an
/// excess count pill (+N).
class AqilAvatarGroup extends StatelessWidget {
  final List<AqilAvatarItem> avatars;
  final double avatarSize;
  final double overlapOffset;
  final int maxVisible;
  final VoidCallback? onExcessTap;

  const AqilAvatarGroup({
    super.key,
    required this.avatars,
    this.avatarSize = 36.0,
    this.overlapOffset = -8.0,
    this.maxVisible = 4,
    this.onExcessTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF161618) : Colors.white;

    final visibleCount = avatars.length > maxVisible ? maxVisible : avatars.length;
    final excessCount = avatars.length - visibleCount;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < visibleCount; i++)
          Transform.translate(
            offset: Offset(i * overlapOffset, 0),
            child: Tooltip(
              message: avatars[i].name,
              child: Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: avatars[i].backgroundColor ??
                      Colors.primaries[i % Colors.primaries.length],
                  border: Border.all(
                    color: borderColor,
                    width: 2.0,
                  ),
                ),
                child: Center(
                  child: Text(
                    avatars[i].initials,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: (avatarSize * 0.38).clamp(10.0, 16.0),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (excessCount > 0)
          Transform.translate(
            offset: Offset(visibleCount * overlapOffset, 0),
            child: GestureDetector(
              onTap: onExcessTap,
              child: Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? const Color(0xFF2C2C30) : const Color(0xFFE5E7EB),
                  border: Border.all(
                    color: borderColor,
                    width: 2.0,
                  ),
                ),
                child: Center(
                  child: Text(
                    '+$excessCount',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black87,
                      fontSize: (avatarSize * 0.35).clamp(9.0, 14.0),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
