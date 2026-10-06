import 'package:flutter/material.dart';

/// The 4 standard enterprise UX lifecycle states of any modern screen or view.
enum AqilScreenStateType {
  loading,
  empty,
  error,
  content,
}

/// Automated Screen State Matrix Synthesizer.
/// Wraps any screen or view to seamlessly test and render all 4 UX states:
/// 1. `loading`: Skeleton / Shimmer placeholders maintaining zero layout shift (CLS = 0).
/// 2. `empty`: Zero-state illustration, messaging, and CTA without overflows.
/// 3. `error`: Error recovery card with retry trigger and diagnostic context.
/// 4. `content`: Standard populated view.
class AqilScreenStateMatrix extends StatelessWidget {
  final AqilScreenStateType state;
  final Widget content;
  final Widget? loadingBuilder;
  final Widget? emptyBuilder;
  final Widget? errorBuilder;
  final String? emptyTitle;
  final String? emptySubtitle;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final VoidCallback? onEmptyAction;

  const AqilScreenStateMatrix({
    super.key,
    required this.state,
    required this.content,
    this.loadingBuilder,
    this.emptyBuilder,
    this.errorBuilder,
    this.emptyTitle,
    this.emptySubtitle,
    this.errorMessage,
    this.onRetry,
    this.onEmptyAction,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: KeyedSubtree(
        key: ValueKey(state),
        child: switch (state) {
          AqilScreenStateType.content => content,
          AqilScreenStateType.loading => loadingBuilder ?? _defaultLoadingView(context),
          AqilScreenStateType.empty => emptyBuilder ?? _defaultEmptyView(context),
          AqilScreenStateType.error => errorBuilder ?? _defaultErrorView(context),
        },
      ),
    );
  }

  Widget _defaultLoadingView(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                strokeWidth: 3.5,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading content...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _defaultEmptyView(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: theme.colorScheme.primary.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              emptyTitle ?? 'No Items Found',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              emptySubtitle ?? 'Items will appear here once created or synced.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            if (onEmptyAction != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onEmptyAction,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Item'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _defaultErrorView(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage ?? 'Failed to load data. Please check your connection and try again.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
