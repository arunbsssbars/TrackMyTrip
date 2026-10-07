import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trackmytrip/models/timeline_playback_state.dart';
import 'package:trackmytrip/core/services/route_replay_service.dart';
import 'package:trackmytrip/screens/timeline/route_playback_controller_card.dart';

void main() {
  group('RouteReplayService State Machine Tests', () {
    final service = RouteReplayService();
    final waypoints = ['Delhi', 'Chandigarh', 'Manali', 'Sissu', 'Leh'];

    test('Steps forward and backward with bound clamping', () {
      var state = TimelinePlaybackState(
        currentIndex: 0,
        totalWaypoints: waypoints.length,
        currentWaypointTitle: waypoints.first,
      );

      expect(state.isAtStart, true);
      expect(state.progressRatio, 0.0);

      // Step forward to index 1
      state = service.stepForward(state: state, waypointTitles: waypoints);
      expect(state.currentIndex, 1);
      expect(state.currentWaypointTitle, 'Chandigarh');

      // Step backward to index 0
      state = service.stepBackward(state: state, waypointTitles: waypoints);
      expect(state.currentIndex, 0);
      expect(state.currentWaypointTitle, 'Delhi');

      // Attempt backward past start -> clamped at 0
      state = service.stepBackward(state: state, waypointTitles: waypoints);
      expect(state.currentIndex, 0);
    });

    test('Seeks directly and clamps to end correctly', () {
      var state = TimelinePlaybackState(
        currentIndex: 0,
        totalWaypoints: waypoints.length,
        currentWaypointTitle: waypoints.first,
      );

      state = service.seekTo(state: state, index: 4, waypointTitles: waypoints);
      expect(state.currentIndex, 4);
      expect(state.isAtEnd, true);
      expect(state.currentWaypointTitle, 'Leh');
      expect(state.progressRatio, 1.0);
    });

    test('Cycles speed multiplier in sequence: 1x -> 2x -> 5x -> 1x', () {
      var speed = 1.0;
      speed = service.cycleSpeedMultiplier(speed);
      expect(speed, 2.0);

      speed = service.cycleSpeedMultiplier(speed);
      expect(speed, 5.0);

      speed = service.cycleSpeedMultiplier(speed);
      expect(speed, 1.0);
    });

    test('Json serialization and deserialization retains accuracy', () {
      final original = TimelinePlaybackState(
        currentIndex: 2,
        totalWaypoints: 5,
        isPlaying: true,
        speedMultiplier: 2.0,
        currentWaypointTitle: 'Manali',
        currentTimestamp: DateTime.utc(2026, 10, 8, 12, 0),
      );

      final json = original.toJson();
      final restored = TimelinePlaybackState.fromJson(json);

      expect(restored.currentIndex, 2);
      expect(restored.totalWaypoints, 5);
      expect(restored.isPlaying, true);
      expect(restored.speedMultiplier, 2.0);
      expect(restored.currentWaypointTitle, 'Manali');
    });
  });

  group('AQIL Multi-Viewport & Accessibility Tests for RoutePlaybackControllerCard', () {
    final waypoints = ['Chandigarh Start', 'Shimla Ridge', 'Rampur Bushahr', 'Kaza HQ'];

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
                child: RoutePlaybackControllerCard(waypointTitles: waypoints),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.text('Chandigarh Start'), findsOneWidget);
        expect(find.byType(RoutePlaybackControllerCard), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Renders with 1.5x font scale without overflow and steps forward', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      int? selectedIndex;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData.fromView(tester.view).copyWith(
              textScaler: const TextScaler.linear(1.5),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: RoutePlaybackControllerCard(
                  waypointTitles: waypoints,
                  onWaypointSelected: (idx) => selectedIndex = idx,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Chandigarh Start'), findsOneWidget);

      // Step to next
      final nextBtn = find.byTooltip('Next Waypoint');
      await tester.ensureVisible(nextBtn);
      await tester.tap(nextBtn);
      await tester.pumpAndSettle();

      expect(selectedIndex, 1);
      expect(find.text('Shimla Ridge'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
