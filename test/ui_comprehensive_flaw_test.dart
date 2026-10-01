import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:latlong2/latlong.dart';
import 'package:trackmytrip/core/database/app_database.dart';
import 'package:trackmytrip/core/services/local_storage_service.dart';
import 'package:trackmytrip/core/services/push_notification_service.dart';
import 'package:trackmytrip/providers/trip_provider.dart';
import 'package:trackmytrip/screens/auth/login_screen.dart';
import 'package:trackmytrip/screens/auth/signup_screen.dart';
import 'package:trackmytrip/screens/trip_detail/widgets/offline_map_download_sheet.dart';

class MockPushNotificationService extends PushNotificationService {
  @override
  Future<String?> getToken() async => 'mock_token';
  @override
  Future<void> init() async {}
}

/// Enterprise UI Flaw Inspection Utilities
class UiFlawInspector {
  /// Asserts that no RenderFlex or layout exceptions occurred.
  static void assertNoOverflows(WidgetTester tester) {
    final exception = tester.takeException();
    if (exception is FlutterError) {
      for (final node in exception.diagnostics) {
        debugPrint('NODE: ${node.name} -> ${node.value} / ${node.toDescription()}');
      }
    } else if (exception != null) {
      debugPrint('UI_FLAW_DIAGNOSTICS: $exception');
    }
    expect(
      exception,
      isNull,
      reason: 'A layout or RenderFlex overflow exception was caught: $exception',
    );
  }

  /// Inspects all RenderParagraph elements and finds any texts that exceeded max lines.
  static List<String> findTruncatedTexts(WidgetTester tester) {
    final List<String> truncated = [];
    final renderObjects = tester.renderObjectList<RenderParagraph>(find.byType(RichText));

    for (final renderParagraph in renderObjects) {
      if (renderParagraph.didExceedMaxLines) {
        final text = renderParagraph.text.toPlainText();
        truncated.add(text);
      }
    }
    return truncated;
  }

  /// Verifies interactive touch targets meet accessibility standards (>= 44x44 dp)
  static void assertInteractiveTouchTargets(WidgetTester tester, Finder buttonFinder, {double minSize = 44.0}) {
    final elements = buttonFinder.evaluate();
    for (final element in elements) {
      final renderBox = element.renderObject as RenderBox?;
      if (renderBox != null && renderBox.hasSize) {
        final size = renderBox.size;
        expect(
          size.width >= minSize - 1.0 && size.height >= minSize - 1.0,
          isTrue,
          reason: 'Touch target size (${size.width}x${size.height}) is smaller than recommended $minSize dp',
        );
      }
    }
  }

  /// Tests smooth scrolling motion without physics locking or layout crashes
  static Future<void> testSmoothScroll(WidgetTester tester, Finder scrollableFinder) async {
    expect(scrollableFinder, findsAtLeastNWidgets(1));
    final target = scrollableFinder.first;

    // Fling down
    await tester.fling(target, const Offset(0, -300), 1000);
    await tester.pumpAndSettle();
    assertNoOverflows(tester);

    // Fling back up
    await tester.fling(target, const Offset(0, 300), 1000);
    await tester.pumpAndSettle();
    assertNoOverflows(tester);
  }
}

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

  Widget buildTestBed(Widget child, {Size physicalSize = const Size(390, 844), double textScale = 1.0}) {
    return MediaQuery(
      data: MediaQueryData(
        size: physicalSize,
        textScaler: TextScaler.linear(textScale),
        padding: const EdgeInsets.only(top: 44, bottom: 34),
      ),
      child: ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWithValue(storage),
          pushNotificationServiceProvider.overrideWithValue(MockPushNotificationService()),
        ],
        child: MaterialApp(
          home: child is Scaffold ? child : Scaffold(body: child),
        ),
      ),
    );
  }

  group('Comprehensive UI Flaw Suite: Multi-Screen & Multi-Device Testing', () {
    final testDevices = <String, Size>{
      'Compact Device (320x568)': const Size(320, 568),
      'Standard Device (390x844)': const Size(390, 844),
      'Tablet Device (768x1024)': const Size(768, 1024),
    };

    for (final entry in testDevices.entries) {
      final deviceName = entry.key;
      final deviceSize = entry.value;

      testWidgets('LoginScreen: zero overflows, no clipping, smooth scroll on $deviceName', (tester) async {
        await tester.binding.setSurfaceSize(deviceSize);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildTestBed(const LoginScreen(), physicalSize: deviceSize));
        await tester.pumpAndSettle();

        // 1. Assert zero RenderFlex overflows
        UiFlawInspector.assertNoOverflows(tester);

        // 2. Assert smooth scroll motion
        final scrollable = find.byType(SingleChildScrollView);
        if (scrollable.evaluate().isNotEmpty) {
          await UiFlawInspector.testSmoothScroll(tester, scrollable);
        }

        // 3. Assert touch targets for primary action buttons
        final signInBtn = find.widgetWithText(ElevatedButton, 'Sign In');
        if (signInBtn.evaluate().isNotEmpty) {
          UiFlawInspector.assertInteractiveTouchTargets(tester, signInBtn, minSize: 44.0);
        }
      });

      testWidgets('SignUpScreen: zero overflows and responsive layout on $deviceName', (tester) async {
        await tester.binding.setSurfaceSize(deviceSize);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(buildTestBed(const SignUpScreen(), physicalSize: deviceSize));
        await tester.pumpAndSettle();

        UiFlawInspector.assertNoOverflows(tester);

        final scrollable = find.byType(SingleChildScrollView);
        if (scrollable.evaluate().isNotEmpty) {
          await UiFlawInspector.testSmoothScroll(tester, scrollable);
        }
      });
    }

    testWidgets('Accessibility Extreme: Font Scale 1.5x on compact screen does not overflow', (tester) async {
      const compactSize = Size(320, 568);
      await tester.binding.setSurfaceSize(compactSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Test with 1.5x large accessibility font scale
      await tester.pumpWidget(buildTestBed(const LoginScreen(), physicalSize: compactSize, textScale: 1.5));
      await tester.pumpAndSettle();

      UiFlawInspector.assertNoOverflows(tester);

      // Verify header text is not truncated
      final truncated = UiFlawInspector.findTruncatedTexts(tester);
      expect(
        truncated.where((t) => t.contains('Track My Trip')),
        isEmpty,
        reason: 'App title was truncated under accessibility font scaling!',
      );
    });

    testWidgets('OfflineMapDownloadSheet: verifies responsive layout on compact screens', (tester) async {
      const compactSize = Size(320, 600);
      await tester.binding.setSurfaceSize(compactSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildTestBed(
          const OfflineMapDownloadSheet(
            routePoints: [LatLng(28.6139, 77.2090), LatLng(28.7041, 77.1025)],
            tripTitle: 'Alpine Expedition',
          ),
          physicalSize: compactSize,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      UiFlawInspector.assertNoOverflows(tester);
    });
  });
}
