import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:trackmytrip/core/database/app_database.dart';
import 'package:trackmytrip/core/services/admin_service.dart';
import 'package:trackmytrip/core/services/local_storage_service.dart';
import 'package:trackmytrip/core/theme/app_theme.dart';
import 'package:trackmytrip/providers/admin_provider.dart';
import 'package:trackmytrip/providers/trip_provider.dart';
import 'package:trackmytrip/screens/admin/super_admin_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late LocalStorageService storage;

  setUpAll(() async {
    FlutterError.onError = (details) {
      FlutterError.dumpErrorToConsole(details, forceReport: true);
    };
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final appDb = await AppDatabase.open(customPath: inMemoryDatabasePath);
    storage = await LocalStorageService.init(prefs: prefs, database: appDb);
  });

  final mockMetrics = FreeTierQuotaMetrics(
    firestoreDocCount: 120,
    firestoreTripsCount: 15,
    firestoreRoomsCount: 10,
    firestoreUsersCount: 8,
    firestoreTombstonesCount: 4,
    firestoreInvitationsCount: 20,
    firestoreEstimatedReads: 4500,
    firestoreEstimatedWrites: 1200,
    firestoreStorageMb: 24.5,
    rtdbActiveConnections: 3,
    rtdbStorageMb: 1.5,
    rtdbBandwidthMb: 12.0,
    storageFileCount: 5,
    storageUsedMb: 15.0,
    authTotalUsers: 8,
    timestamp: DateTime.now(),
    isCloudinaryActive: true,
    cloudinaryCloudName: 'trackmytrip-media',
    cloudinaryStorageMb: 12450.0,
    cloudinaryMaxStorageMb: 25600.0,
    cloudinaryStoragePercent: (12450.0 / 25600.0) * 100.0,
    cloudinaryEstimatedPhotoCount: 415,
    isCloudinaryWarning: false,
    isCloudinaryCritical: false,
  );

  Widget buildTestBed(Widget child, {required Size size, double fontScale = 1.0, bool isDark = false}) {
    return ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storage),
        adminMetricsProvider.overrideWith((ref) => mockMetrics),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(fontScale),
            padding: const EdgeInsets.only(top: 24, bottom: 16),
            viewInsets: EdgeInsets.zero,
          ),
          child: child,
        ),
      ),
    );
  }

  const viewports = [
    Size(320, 568),  // Compact mobile (320px)
    Size(390, 844),  // Standard mobile (390px)
    Size(412, 915),  // Large mobile (412px)
    Size(768, 1024), // Tablet portrait (768px)
    Size(1280, 800), // Desktop landscape (1280px)
  ];

  group('SuperAdminScreen AQIL Multi-Viewport Responsive Layout Verification', () {
    testWidgets('Cloudinary Media Storage Card renders without overflow across viewports and font scales', (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      for (final vp in viewports) {
        for (final fontScale in [1.0, 1.3, 1.5]) {
          tester.view.physicalSize = vp;
          tester.view.devicePixelRatio = 1.0;

          FlutterError.onError = (details) {
            FlutterError.dumpErrorToConsole(details, forceReport: true);
          };

          await tester.pumpWidget(buildTestBed(const SuperAdminScreen(), size: vp, fontScale: fontScale));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          // Verify Cloudinary Card Header is displayed
          expect(find.text('Cloudinary Media Storage'), findsOneWidget);
          expect(find.text('25 GB CAP'), findsOneWidget);

          // Assert zero RenderFlex overflow or layout errors
          expect(tester.takeException(), isNull);
        }
      }
    });
  });
}
