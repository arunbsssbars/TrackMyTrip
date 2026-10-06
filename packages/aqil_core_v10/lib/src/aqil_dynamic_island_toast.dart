import 'package:flutter/material.dart';

/// Presentation mode for [AqilDynamicIslandToast].
enum AqilIslandMode {
  compact,
  expanded,
}

/// Dynamic Island morphing capsule banner (Apple iOS / Flighty Live Activity standard).
///
/// Transitions smoothly between a compact status pill and an expanded notification
/// card with spring physics and obsidian styling.
class AqilDynamicIslandToast extends StatelessWidget {
  final AqilIslandMode mode;
  final Widget leading;
  final Widget? trailing;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  const AqilDynamicIslandToast({
    super.key,
    required this.mode,
    required this.leading,
    this.trailing,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isExpanded = mode == AqilIslandMode.expanded;

    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Curves.fastOutSlowIn,
          constraints: BoxConstraints(
            minWidth: isExpanded ? 320.0 : 180.0,
            maxWidth: isExpanded ? 380.0 : 240.0,
            minHeight: isExpanded ? 76.0 : 40.0,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isExpanded ? 16.0 : 12.0,
            vertical: isExpanded ? 14.0 : 8.0,
          ),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(isExpanded ? 24.0 : 32.0),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20.0,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: isExpanded
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    leading,
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14.0,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2.0),
                            Text(
                              subtitle!,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 12.0,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 10.0),
                      trailing!,
                    ],
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    leading,
                    const SizedBox(width: 8.0),
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.0,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 8.0),
                      trailing!,
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}
