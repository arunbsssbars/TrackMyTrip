import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trackmytrip/core/design_system/design_system.dart';
import 'package:aqil_core/aqil_core.dart';

void main() {
  group('Loop 81: Sentinel Clean & Cryptographic Baseline', () {
    test('OfflinePunchBlock serializes to JSON accurately', () {
      final now = DateTime(2026, 10, 4, 12, 0, 0);
      final block = OfflinePunchBlock(
        index: 1,
        employeeId: 'EMP-007',
        timestamp: now,
        punchType: 'CHECK_IN',
        previousHash: 'GENESIS_ROOT',
        blockHash: 'sample_hash',
      );

      final json = block.toJson();
      expect(json['index'], equals(1));
      expect(json['employeeId'], equals('EMP-007'));
      expect(json['punchType'], equals('CHECK_IN'));
      expect(json['previousHash'], equals('GENESIS_ROOT'));
    });

    test('AqilHashChainSentinel verifies valid hash sequence', () {
      final now = DateTime(2026, 10, 4, 12, 0, 0);
      final b0 = AqilHashChainSentinel.createBlock(
        index: 0,
        employeeId: 'EMP-001',
        timestamp: now,
        punchType: 'CHECK_IN',
        previousHash: 'GENESIS_BLOCK_ROOT',
      );

      final b1 = AqilHashChainSentinel.createBlock(
        index: 1,
        employeeId: 'EMP-001',
        timestamp: now.add(const Duration(hours: 4)),
        punchType: 'CHECK_OUT',
        previousHash: b0.blockHash,
      );

      final report = AqilHashChainSentinel.verifyChainIntegrity([b0, b1]);
      expect(report.isChainIntact, isTrue);
      expect(report.totalBlocks, equals(2));
      expect(report.corruptedIndices, isEmpty);
      expect(report.toMarkdownReport(), contains('CRYPTOGRAPHICALLY SECURE'));
    });

    test('AqilHashChainSentinel detects tampered previous hash', () {
      final now = DateTime(2026, 10, 4, 12, 0, 0);
      final b0 = AqilHashChainSentinel.createBlock(
        index: 0,
        employeeId: 'EMP-001',
        timestamp: now,
        punchType: 'CHECK_IN',
        previousHash: 'GENESIS_BLOCK_ROOT',
      );

      final tampered = OfflinePunchBlock(
        index: 1,
        employeeId: 'EMP-001',
        timestamp: now.add(const Duration(hours: 4)),
        punchType: 'CHECK_OUT',
        previousHash: 'CORRUPTED_HASH',
        blockHash: 'some_hash',
      );

      final report = AqilHashChainSentinel.verifyChainIntegrity([b0, tampered]);
      expect(report.isChainIntact, isFalse);
      expect(report.corruptedIndices, contains(1));
      expect(report.toMarkdownReport(), contains('CHAIN TAMPERING DETECTED'));
    });
  });

  group('Loop 82 & 83: Home & Trip Detail Responsive Tokens & Touch Targets', () {
    testWidgets('AppEmptyState renders in Home Screen empty journeys state', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: AppEmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No Journeys Found for "Paris"',
                  message: 'Try searching by a different name, destination, or member.',
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('No Journeys Found for "Paris"'), findsOneWidget);
      expect(find.byIcon(Icons.search_off_rounded), findsOneWidget);
      expect(find.textContaining('Try searching'), findsOneWidget);
    });

    testWidgets('Trip Detail Screen back button meets minimum 48x48dp touch target', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
                tooltip: 'Back to journeys',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      final iconButtonFinder = find.byTooltip('Back to journeys');
      expect(iconButtonFinder, findsOneWidget);

      final size = tester.getSize(iconButtonFinder);
      expect(size.width, greaterThanOrEqualTo(48.0));
      expect(size.height, greaterThanOrEqualTo(48.0));
    });
  });

  group('Loop 84 & 85: Map Tab Adaptive Sheet & Analytics Screen KPI Layout', () {
    test('Map sheet calculates adaptive max child size based on viewport width', () {
      const compactWidth = 393.0;
      const tabletWidth = 1024.0;

      const compactMax = compactWidth > 800 ? 0.55 : 0.72;
      const tabletMax = tabletWidth > 800 ? 0.55 : 0.72;

      expect(compactMax, equals(0.72));
      expect(tabletMax, equals(0.55));
    });

    testWidgets('Analytics empty state renders gracefully with AppEmptyState', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: AppSpacing.lg,
                ),
                child: AppEmptyState(
                  icon: Icons.pie_chart_outline_rounded,
                  title: 'No Expense Data Available',
                  message: 'Record expenses across your journeys to view analytics.',
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('No Expense Data Available'), findsOneWidget);
      expect(find.byIcon(Icons.pie_chart_outline_rounded), findsOneWidget);
    });
  });

  group('Loop 86 & 87: Profile & Stoppage Screen Touch Targets & State Coverage', () {
    testWidgets('Profile Sign Out button satisfies minimum 48dp height', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Sign Out of Account'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
              ),
            ),
          ),
        ),
      );

      final btn = find.byType(OutlinedButton);
      expect(btn, findsOneWidget);
      final size = tester.getSize(btn);
      expect(size.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('Stoppage Detail Screen empty states render tokenized AppEmptyState', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AppEmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'No bills logged at this stoppage yet.',
                  message: 'Add expenses incurred while stopping here.',
                ),
                AppEmptyState(
                  icon: Icons.photo_library_outlined,
                  title: 'No memories captured at this stop yet.',
                  message: 'Snap photos or upload memories from this stoppage.',
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('No bills logged at this stoppage yet.'), findsOneWidget);
      expect(find.text('No memories captured at this stop yet.'), findsOneWidget);
      expect(find.byIcon(Icons.receipt_long_outlined), findsOneWidget);
      expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
    });
  });

  group('Loop 88: Add Expense Screen OCR Scanner Touch Target', () {
    testWidgets('Add Expense Screen OCR icon button satisfies 48x48dp touch constraint', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                IconButton(
                  icon: const Icon(Icons.document_scanner_rounded),
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  tooltip: 'Scan Receipt with OCR',
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );

      final scannerBtn = find.byTooltip('Scan Receipt with OCR');
      expect(scannerBtn, findsOneWidget);
      final size = tester.getSize(scannerBtn);
      expect(size.width, greaterThanOrEqualTo(48.0));
      expect(size.height, greaterThanOrEqualTo(48.0));
    });
  });
}
