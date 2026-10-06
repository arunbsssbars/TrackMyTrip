import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Information density modes modeled after Google Workspace (Gmail/Drive) & Microsoft 365 (Outlook/Teams).
enum AqilDensityMode {
  compact,    // Maximum data per screen: 40dp row height, 8dp padding, 12sp typography
  comfortable,// Balanced enterprise default: 52dp row height, 12dp padding, 14sp typography
  spacious,   // High accessibility/relaxed: 64dp row height, 16dp padding, 16sp typography
}

/// Token metrics for each information density mode.
class AqilDensityTokens {
  final double rowHeight;
  final EdgeInsets padding;
  final double iconSize;
  final double bodyFontSize;

  const AqilDensityTokens({
    required this.rowHeight,
    required this.padding,
    required this.iconSize,
    required this.bodyFontSize,
  });

  static AqilDensityTokens forMode(AqilDensityMode mode) {
    switch (mode) {
      case AqilDensityMode.compact:
        return const AqilDensityTokens(
          rowHeight: 40.0,
          padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
          iconSize: 18.0,
          bodyFontSize: 12.0,
        );
      case AqilDensityMode.spacious:
        return const AqilDensityTokens(
          rowHeight: 64.0,
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
          iconSize: 24.0,
          bodyFontSize: 16.0,
        );
      case AqilDensityMode.comfortable:
        return const AqilDensityTokens(
          rowHeight: 52.0,
          padding: EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
          iconSize: 20.0,
          bodyFontSize: 14.0,
        );
    }
  }
}

/// Report emitted by [AqilInformationDensityAuditor.auditDensityModes].
class DensityAuditReport {
  final Map<AqilDensityMode, bool> modeSupported;
  final bool hasZeroOverflowAcrossModes;
  final List<String> densityErrors;

  const DensityAuditReport({
    required this.modeSupported,
    required this.hasZeroOverflowAcrossModes,
    required this.densityErrors,
  });

  bool get isBigTechCompliant =>
      hasZeroOverflowAcrossModes &&
      modeSupported[AqilDensityMode.compact] == true &&
      modeSupported[AqilDensityMode.comfortable] == true &&
      modeSupported[AqilDensityMode.spacious] == true;
}

/// AQIL v11 Frontier 3: Big Tech Information Density & Micro-Typography Ramps Auditor
///
/// Validates seamless UI adaptation across Compact, Comfortable, and Spacious density levels.
abstract final class AqilInformationDensityAuditor {
  /// Audits a responsive widget across Compact, Comfortable, and Spacious density levels.
  static Future<DensityAuditReport> auditDensityModes(
    WidgetTester tester, {
    required Widget Function(BuildContext context, AqilDensityMode mode) widgetBuilder,
  }) async {
    final modeSupported = <AqilDensityMode, bool>{};
    final errors = <String>[];
    var zeroOverflow = true;

    for (final mode in AqilDensityMode.values) {
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => widgetBuilder(context, mode),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final exception = tester.takeException();
        if (exception != null) {
          zeroOverflow = false;
          errors.add('Mode $mode generated layout exception: $exception');
          modeSupported[mode] = false;
        } else {
          modeSupported[mode] = true;
        }
      } catch (e) {
        zeroOverflow = false;
        errors.add('Exception in mode $mode: $e');
        modeSupported[mode] = false;
      }
    }

    return DensityAuditReport(
      modeSupported: modeSupported,
      hasZeroOverflowAcrossModes: zeroOverflow,
      densityErrors: errors,
    );
  }
}
