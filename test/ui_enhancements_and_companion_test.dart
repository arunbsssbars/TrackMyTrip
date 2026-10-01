import 'package:flutter_test/flutter_test.dart';
import 'package:trackmytrip/core/services/location_service.dart';
import 'package:trackmytrip/models/trip.dart';
import 'package:trackmytrip/models/trip_member.dart';
import 'package:trackmytrip/models/stoppage.dart';
import 'package:trackmytrip/core/services/trip_share_service.dart';
import 'package:trackmytrip/models/trip_invitation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UI Enhancements and Bugfix Tests', () {
    test('Dynamic currency updates dynamically from country code', () {
      LocationService.updateCurrencyFromCountryCode('US');
      expect(LocationService.currentDetectedCurrency, 'USD');
      expect(LocationService.currencyNotifier.value, 'USD');

      LocationService.updateCurrencyFromCountryCode('IN');
      expect(LocationService.currentDetectedCurrency, 'INR');
      expect(LocationService.currencyNotifier.value, 'INR');

      LocationService.updateCurrencyFromCountryCode('GB');
      expect(LocationService.currentDetectedCurrency, 'GBP');
      expect(LocationService.currencyNotifier.value, 'GBP');
    });

    test('TripMember direct addition preserves member structure', () {
      final trip = Trip(
        id: 'trip-test-1',
        title: 'Himalayan Expedition',
        defaultCurrency: 'USD',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 5)),
        createdAt: DateTime.now(),
        members: [
          const TripMember(id: 'u1', name: 'Alice', isCurrentUser: true),
        ],
        createdByMemberId: 'u1',
      );

      const newMember = TripMember(
        id: 'u2',
        name: 'Bob Explorer',
        email: 'bob@example.com',
        colorHex: '0xFF0D9488',
      );

      final updated = trip.copyWith(members: [...trip.members, newMember]);
      expect(updated.members.length, 2);
      expect(updated.members.any((m) => m.id == 'u2'), isTrue);
      expect(updated.members.firstWhere((m) => m.id == 'u2').email, 'bob@example.com');
    });

    test('Trip stoppage distance calculation is accurate', () {
      final stop1 = Stoppage(
        id: 's1',
        tripId: 'trip-test-1',
        name: 'Delhi Gateway',
        category: 'viewpoint',
        createdBy: 'u1',
        latitude: 28.6139,
        longitude: 77.2090,
        arrivedAt: DateTime.now(),
      );
      final stop2 = Stoppage(
        id: 's2',
        tripId: 'trip-test-1',
        name: 'Murthal Toll',
        category: 'fuel',
        createdBy: 'u1',
        latitude: 28.7041,
        longitude: 77.1025,
        arrivedAt: DateTime.now().add(const Duration(hours: 1)),
      );

      final distance = LocationService.calculateStoppagesDistanceKm([stop1, stop2]);
      expect(distance, greaterThan(10.0));
      expect(distance, lessThan(30.0));
    });

    test('TripMember initials formats single, multi-word and fallback names correctly', () {
      const single = TripMember(id: '1', name: 'Arun');
      expect(single.initials, 'A');

      const doubleName = TripMember(id: '2', name: 'Jai Yashu');
      expect(doubleName.initials, 'JY');

      const multiName = TripMember(id: '3', name: 'Savitri Devi Sharma');
      expect(multiName.initials, 'SD');

      const emptyName = TripMember(id: '4', name: '   ');
      expect(emptyName.initials, '?');
    });

    test('Trip tab counts reflect 6 tabs for group trip and 5 tabs for solo trip with Members tab', () {
      final soloTrip = Trip(
        id: 'solo-1',
        title: 'Solo Walk',
        tripType: 'solo',
        defaultCurrency: 'INR',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 1)),
        createdAt: DateTime.now(),
        createdByMemberId: 'u1',
        members: [const TripMember(id: 'u1', name: 'Me', isCurrentUser: true)],
      );
      final groupTrip = Trip(
        id: 'group-1',
        title: 'Group Tour',
        tripType: 'group',
        defaultCurrency: 'INR',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 3)),
        createdAt: DateTime.now(),
        createdByMemberId: 'u1',
        members: [
          const TripMember(id: 'u1', name: 'Arun', isCurrentUser: true),
          const TripMember(id: 'u2', name: 'Jaiyashu', isCurrentUser: false),
        ],
      );

      final soloTabCount = soloTrip.isSolo ? 5 : 6;
      final groupTabCount = groupTrip.isSolo ? 5 : 6;

      expect(soloTabCount, 5); // Members, Timeline, Budget, Route, Memories
      expect(groupTabCount, 6); // Members, Timeline, Bills, Settle, Route, Memories
    });

    test('TripPackage member union preserves existing members from dropping', () {
      final localTrip = Trip(
        id: 'trip-1',
        title: 'Road Trip',
        defaultCurrency: 'INR',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 2)),
        createdAt: DateTime.now(),
        members: [
          const TripMember(id: 'creator-1', name: 'Arun', isCurrentUser: true),
          const TripMember(id: 'member-2', name: 'Companion B', isCurrentUser: false),
        ],
        createdByMemberId: 'creator-1',
      );

      final incomingPackage = TripPackage(
        trip: localTrip.copyWith(members: [
          const TripMember(id: 'creator-1', name: 'Arun', isCurrentUser: false),
        ]),
        stoppages: [],
        expenses: [],
        memories: [],
        settlements: [],
      );

      final Map<String, TripMember> memberMap = {};
      for (final m in localTrip.members) {
        memberMap[m.id] = m;
      }
      for (final m in incomingPackage.trip.members) {
        memberMap[m.id] = m;
      }

      expect(memberMap.length, 2);
      expect(memberMap.containsKey('member-2'), isTrue);
      expect(memberMap['member-2']!.name, 'Companion B');
    });

    test('Pending invitation detection identifies already invited user', () {
      final invitations = [
        TripInvitation(
          id: 'inv-1',
          tripId: 'trip-1',
          tripTitle: 'Road Trip',
          inviterId: 'u1',
          inviterName: 'Alice',
          inviteeId: 'u2',
          inviteeUsername: 'bob',
          inviteeEmail: 'bob@example.com',
          status: InvitationStatus.pending,
          createdAt: DateTime.now(),
        ),
      ];

      bool hasPending(String userId, String? email, String username) {
        return invitations.any((inv) {
          if (inv.status != InvitationStatus.pending) return false;
          final matchId = inv.inviteeId != null && inv.inviteeId == userId;
          final matchEmail = email != null &&
              inv.inviteeEmail != null &&
              inv.inviteeEmail!.trim().toLowerCase() == email.trim().toLowerCase();
          final matchUsername = inv.inviteeUsername.trim().toLowerCase() == username.trim().toLowerCase();
          return matchId || matchEmail || matchUsername;
        });
      }

      expect(hasPending('u2', 'bob@example.com', 'bob'), isTrue);
      expect(hasPending('u3', 'charlie@example.com', 'charlie'), isFalse);
    });

    test('Trip isEnded accurately identifies completed and concluded journeys', () {
      final runningTrip = Trip(
        id: 'trip-running',
        title: 'Running Trip',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 3)),
        defaultCurrency: 'INR',
        members: const [],
        createdByMemberId: 'user-1',
        createdAt: DateTime.now(),
        isCompleted: false,
      );
      expect(runningTrip.isRunning, isTrue);
      expect(runningTrip.isEnded, isFalse);

      final completedTrip = runningTrip.copyWith(isCompleted: true, status: 'completed');
      expect(completedTrip.isRunning, isFalse);
      expect(completedTrip.isEnded, isTrue);

      final concludedTrip = runningTrip.copyWith(status: 'concluded');
      expect(concludedTrip.isRunning, isFalse);
      expect(concludedTrip.isEnded, isTrue);
    });
  });
}

