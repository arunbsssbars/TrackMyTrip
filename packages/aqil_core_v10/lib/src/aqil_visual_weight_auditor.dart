import 'package:flutter/material.dart';

/// Diagnostic assessment of visual balance.
class VisualWeightBalanceResult {
  final double leftWeight;
  final double rightWeight;
  final double ratio;
  final bool isBalanced;
  final String recommendation;

  const VisualWeightBalanceResult({
    required this.leftWeight,
    required this.rightWeight,
    required this.ratio,
    required this.isBalanced,
    required this.recommendation,
  });
}

/// Evaluates spatial visual weight distribution across dual-column or horizontal layouts (Dieter Rams / Swiss graphic principles).
class AqilVisualWeightAuditor {
  /// Evaluates balance between left and right components in a horizontal section.
  ///
  /// Visual weight is estimated as: width * height * visualProminenceFactor
  /// - Text: factor 1.0
  /// - Prominent Button/Badge: factor 1.8
  /// - Graphic/Icon: factor 1.4
  static VisualWeightBalanceResult evaluateHorizontalBalance({
    required Size leftSize,
    double leftProminence = 1.0,
    required Size rightSize,
    double rightProminence = 1.0,
  }) {
    final leftWeight = (leftSize.width * leftSize.height * leftProminence).clamp(1.0, double.infinity);
    final rightWeight = (rightSize.width * rightSize.height * rightProminence).clamp(1.0, double.infinity);

    final maxWeight = leftWeight > rightWeight ? leftWeight : rightWeight;
    final minWeight = leftWeight < rightWeight ? leftWeight : rightWeight;
    final ratio = maxWeight / minWeight;

    // Ratios exceeding 4.0:1 cause noticeable visual imbalance/tilt
    final isBalanced = ratio <= 4.0;

    String recommendation = 'Visual weight is balanced across the horizontal axis.';
    if (!isBalanced) {
      final heavierSide = leftWeight > rightWeight ? 'Left' : 'Right';
      recommendation =
          '$heavierSide side dominates with a $ratio:1 weight ratio. Consider pairing with secondary metadata or evening out padding.';
    }

    return VisualWeightBalanceResult(
      leftWeight: leftWeight,
      rightWeight: rightWeight,
      ratio: double.parse(ratio.toStringAsFixed(2)),
      isBalanced: isBalanced,
      recommendation: recommendation,
    );
  }
}
