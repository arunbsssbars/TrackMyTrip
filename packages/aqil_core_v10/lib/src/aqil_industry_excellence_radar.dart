import 'aqil_ambient_glow.dart';
import 'aqil_synced_shimmer_group.dart';
import 'aqil_visual_weight_auditor.dart';
import 'aqil_z_index_layer_auditor.dart';
import 'package:flutter/material.dart';

/// Comprehensive scorecard summarizing 6 vectors of Silicon Valley visual design excellence.
class AqilIndustryRadarScorecard {
  final double ambientScore;
  final double shimmerScore;
  final double visualBalanceScore;
  final double zIndexScore;
  final double compositeScore;
  final String ratingTier;
  final List<String> findings;

  const AqilIndustryRadarScorecard({
    required this.ambientScore,
    required this.shimmerScore,
    required this.visualBalanceScore,
    required this.zIndexScore,
    required this.compositeScore,
    required this.ratingTier,
    required this.findings,
  });
}

/// Diagnostic benchmark engine assessing UI against Apple, Vercel, Linear, and Stripe standards.
class AqilIndustryExcellenceRadar {
  /// Evaluates screen components across industry design pillars.
  static AqilIndustryRadarScorecard evaluate({
    required double ambientIntensity,
    required Duration shimmerDuration,
    required Size leftCardSize,
    required Size rightCardSize,
    required double cardElevation,
    required double modalElevation,
  }) {
    final findings = <String>[];

    // 1. Ambient Lighting
    final isAmbientSafe = AqilAmbientGlowAuditor.isSafeGlowIntensity(ambientIntensity);
    final ambientScore = isAmbientSafe ? 100.0 : 60.0;
    if (!isAmbientSafe) {
      findings.add('Ambient Lighting: Glow intensity ($ambientIntensity) is outside safe range (0.05 - 0.40).');
    }

    // 2. Shimmer Synchronization
    final isShimmerSmooth = AqilShimmerWaveAuditor.isSmoothDuration(shimmerDuration);
    final shimmerScore = isShimmerSmooth ? 100.0 : 60.0;
    if (!isShimmerSmooth) {
      findings.add('Shimmer Timing: Sweep duration (${shimmerDuration.inMilliseconds}ms) deviates from 1200ms-2000ms golden window.');
    }

    // 3. Visual Weight Balance
    final balance = AqilVisualWeightAuditor.evaluateHorizontalBalance(
      leftSize: leftCardSize,
      rightSize: rightCardSize,
    );
    final visualBalanceScore = balance.isBalanced ? 100.0 : 50.0;
    if (!balance.isBalanced) {
      findings.add('Visual Weight: ${balance.recommendation}');
    }

    // 4. Z-Index Elevation Hierarchy
    final zIndexIssue = AqilZIndexLayerAuditor.auditLayerPair(
      backgroundElevation: cardElevation,
      foregroundElevation: modalElevation,
    );
    final zIndexScore = zIndexIssue == null ? 100.0 : 40.0;
    if (zIndexIssue != null) {
      findings.add('Z-Index Elevation: $zIndexIssue');
    }

    // Composite
    final composite = (ambientScore * 0.25) +
        (shimmerScore * 0.25) +
        (visualBalanceScore * 0.25) +
        (zIndexScore * 0.25);

    final ratingTier = composite >= 90.0
        ? 'World-Class Enterprise'
        : (composite >= 75.0 ? 'Advanced' : 'Needs Hardening');

    return AqilIndustryRadarScorecard(
      ambientScore: ambientScore,
      shimmerScore: shimmerScore,
      visualBalanceScore: visualBalanceScore,
      zIndexScore: zIndexScore,
      compositeScore: composite,
      ratingTier: ratingTier,
      findings: findings,
    );
  }
}
