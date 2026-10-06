import 'package:flutter/material.dart';
import '../app_status_colors.dart';
import '../app_tokens.dart';

/// Standard error state widget conforming to AQIL v2:
/// - Human readable error presentation (never raw stack traces)
/// - Uses AppStatusColors danger/warning tokens
/// - Accessible >= 48dp retry CTA
class AppErrorRetry extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;
  final IconData icon;

  const AppErrorRetry({
    super.key,
    this.title = 'Something went wrong',
    required this.message,
    this.onRetry,
    this.retryLabel = 'Try Again',
    this.icon = Icons.error_outline_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final status = Theme.of(context).extension<AppStatusColors>() ?? AppStatusColors.light;
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 72.0,
              height: 72.0,
              decoration: BoxDecoration(
                color: status.dangerContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 36.0,
                color: status.danger,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: status.onDangerContainer,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420.0),
              child: Text(
                message,
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.brightness == Brightness.dark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                ),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.xl),
              Semantics(
                button: true,
                label: retryLabel,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48.0, minWidth: 130.0),
                  child: OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 18.0),
                    label: Text(retryLabel),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: status.danger,
                      side: BorderSide(color: status.danger, width: 1.5),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl,
                        vertical: AppSpacing.md,
                      ),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.roundedMd,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
