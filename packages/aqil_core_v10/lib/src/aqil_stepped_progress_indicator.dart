import 'package:flutter/material.dart';

/// Progress step model for [AqilSteppedProgressIndicator].
class AqilStepItem {
  final String title;

  const AqilStepItem({
    required this.title,
  });
}

/// Multi-step wizard and checkout progress indicator (Airbnb / Stripe / Uber standard).
///
/// Provides connected progression tracks, checkmark state transitions, and an active step ring.
class AqilSteppedProgressIndicator extends StatelessWidget {
  final List<AqilStepItem> steps;
  final int currentStep;
  final Color? activeColor;

  const AqilSteppedProgressIndicator({
    super.key,
    required this.steps,
    required this.currentStep,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = activeColor ?? theme.colorScheme.primary;

    return Row(
      children: List.generate(steps.length * 2 - 1, (index) {
        if (index.isOdd) {
          // Connecting line
          final stepIndex = index ~/ 2;
          final isCompleted = stepIndex < currentStep;

          return Expanded(
            child: Container(
              height: 2.5,
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              decoration: BoxDecoration(
                color: isCompleted
                    ? primary
                    : (isDark ? Colors.white12 : Colors.black12),
                borderRadius: BorderRadius.circular(2.0),
              ),
            ),
          );
        }

        // Step Node
        final stepIndex = index ~/ 2;
        final step = steps[stepIndex];
        final isCompleted = stepIndex < currentStep;
        final isActive = stepIndex == currentStep;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28.0,
              height: 28.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted
                    ? primary
                    : (isActive
                        ? primary.withValues(alpha: isDark ? 0.25 : 0.15)
                        : (isDark ? const Color(0xFF222228) : const Color(0xFFE5E7EB))),
                border: Border.all(
                  color: (isCompleted || isActive)
                      ? primary
                      : (isDark ? Colors.white24 : Colors.black26),
                  width: isActive ? 2.0 : 1.5,
                ),
              ),
              child: Center(
                child: isCompleted
                    ? const Icon(
                        Icons.check,
                        size: 16.0,
                        color: Colors.white,
                      )
                    : Text(
                        '${stepIndex + 1}',
                        style: TextStyle(
                          fontSize: 12.0,
                          fontWeight: FontWeight.bold,
                          color: isActive
                              ? primary
                              : (isDark ? Colors.white60 : Colors.black54),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 6.0),
            Text(
              step.title,
              style: TextStyle(
                fontSize: 11.0,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive
                    ? (isDark ? Colors.white : Colors.black87)
                    : (isDark ? Colors.white54 : Colors.black45),
              ),
            ),
          ],
        );
      }),
    );
  }
}
