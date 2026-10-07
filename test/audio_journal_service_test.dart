import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trackmytrip/models/voice_journal_memo.dart';
import 'package:trackmytrip/core/services/audio_journal_service.dart';
import 'package:trackmytrip/screens/memories/voice_memo_player_widget.dart';

void main() {
  group('AudioJournalService Logic Tests', () {
    final service = AudioJournalService();

    test('Formats seconds into mm:ss time labels', () {
      expect(service.formatSeconds(0), '00:00');
      expect(service.formatSeconds(65), '01:05');
      expect(service.formatSeconds(214), '03:34');
    });

    test('Calculates playback progress ratio safely', () {
      const total = Duration(seconds: 120);
      expect(service.calculateProgressRatio(Duration.zero, total), 0.0);
      expect(service.calculateProgressRatio(const Duration(seconds: 60), total), 0.5);
      expect(service.calculateProgressRatio(const Duration(seconds: 120), total), 1.0);
      expect(service.calculateProgressRatio(const Duration(seconds: 150), total), 1.0); // clamped
    });

    test('Creates and serializes voice memo correctly', () {
      final memo = service.createVoiceMemo(
        tripId: 'trip_10',
        title: 'Campfire Stories at Pangong',
        duration: const Duration(seconds: 154),
        audioUri: 'file:///data/audio/memo_01.m4a',
        transcriptSummary: 'Campfire was warm, night sky had milky way clearly visible.',
        authorName: 'Sneha',
      );

      expect(memo.formattedDuration, '02:34');
      expect(memo.authorName, 'Sneha');

      final json = memo.toJson();
      final restored = VoiceJournalMemo.fromJson(json);

      expect(restored.id, memo.id);
      expect(restored.title, memo.title);
      expect(restored.duration.inSeconds, 154);
      expect(restored.transcriptSummary, memo.transcriptSummary);
    });
  });

  group('AQIL Multi-Viewport & Accessibility Tests for VoiceMemoPlayerWidget', () {
    final memo = VoiceJournalMemo(
      id: 'memo_test_01',
      tripId: 'trip_spiti',
      title: 'Crossing Rohtang Tunnel at Dusk',
      duration: const Duration(seconds: 95),
      audioUri: 'file:///data/memos/01.m4a',
      recordedAt: DateTime(2026, 10, 8, 18, 0),
      transcriptSummary: 'Snow flurries outside the north portal. Convoy regrouped safely.',
      authorName: 'Captain Aditya',
    );

    final viewports = <String, Size>{
      'Compact Mobile (320px)': const Size(320, 568),
      'Standard Mobile (393px)': const Size(393, 852),
      'Large Mobile (412px)': const Size(412, 915),
      'Tablet Portrait (800px)': const Size(800, 1280),
      'Desktop Landscape (1280px)': const Size(1280, 800),
    };

    for (final entry in viewports.entries) {
      testWidgets('Renders zero overflow on ${entry.key}', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: VoiceMemoPlayerWidget(memo: memo),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.text('Crossing Rohtang Tunnel at Dusk'), findsOneWidget);
        expect(find.byType(VoiceMemoPlayerWidget), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Renders with 1.5x font scale without overflow and toggles play', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData.fromView(tester.view).copyWith(
              textScaler: const TextScaler.linear(1.5),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: VoiceMemoPlayerWidget(memo: memo),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Crossing Rohtang Tunnel at Dusk'), findsOneWidget);

      final playBtn = find.byTooltip('Play');
      expect(playBtn, findsOneWidget);
      await tester.tap(playBtn);
      await tester.pumpAndSettle();

      expect(find.byTooltip('Pause'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
