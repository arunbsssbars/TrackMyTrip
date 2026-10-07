import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trackmytrip/core/services/emergency_directory_service.dart';
import 'package:trackmytrip/models/ice_medical_profile.dart';
import 'package:trackmytrip/screens/emergency/ice_emergency_card_dialog.dart';

void main() {
  group('EmergencyDirectoryService Unit Tests', () {
    test('Contains standard emergency dispatch helplines', () {
      expect(EmergencyDirectoryService.helplines.isNotEmpty, isTrue);
      expect(EmergencyDirectoryService.helplines.any((h) => h.number == '112'), isTrue);
      expect(EmergencyDirectoryService.helplines.any((h) => h.number == '108'), isTrue);
      expect(EmergencyDirectoryService.helplines.any((h) => h.number == '1033'), isTrue);
    });

    test('Saves and retrieves ICE medical profile accurately', () {
      const profile = IceMedicalProfile(
        memberId: 'mem_ice_01',
        memberName: 'Arun V (Expedition Lead)',
        bloodGroup: 'O+',
        allergies: ['Dust', 'Sulfa Drugs'],
        medications: ['Altitude acclimatization tablets'],
        emergencyContactName: 'Emergency Primary Contact',
        emergencyContactPhone: '+91 99999 88888',
      );

      EmergencyDirectoryService.saveIceProfile(profile);

      final retrieved = EmergencyDirectoryService.getIceProfile('mem_ice_01');
      expect(retrieved.bloodGroup, equals('O+'));
      expect(retrieved.allergies.length, equals(2));
      expect(retrieved.emergencyContactPhone, equals('+91 99999 88888'));
    });
  });

  group('AQIL Multi-Viewport & Accessibility Tests: IceEmergencyCardDialog', () {
    const viewports = [
      Size(320, 600),  // Compact Mobile
      Size(393, 852),  // Standard Mobile
      Size(412, 915),  // Large Mobile
      Size(800, 1200), // Tablet Portrait
      Size(1280, 800), // Landscape Desktop
    ];

    const testProfile = IceMedicalProfile(
      memberId: 'mem_test',
      memberName: 'Arun & Convoy Lead',
      bloodGroup: 'B+',
      allergies: ['Penicillin'],
      emergencyContactName: 'Primary Emergency Contact',
      emergencyContactPhone: '+91 98765 43210',
    );

    for (final viewport in viewports) {
      testWidgets('Renders zero overflow at ${viewport.width}x${viewport.height} with 1.5x font scale', (tester) async {
        await tester.binding.setSurfaceSize(viewport);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: viewport,
                textScaler: const TextScaler.linear(1.5),
              ),
              child: const Scaffold(
                body: IceEmergencyCardDialog(profile: testProfile),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('ICE Medical Rescue Card'), findsOneWidget);
        expect(find.text('B+'), findsOneWidget);
        expect(find.byType(ElevatedButton), findsOneWidget);
      });
    }
  });
}
