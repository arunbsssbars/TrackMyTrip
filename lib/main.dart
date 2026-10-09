import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/services/local_storage_service.dart';
import 'core/services/map_tile_cache_service.dart';
import 'core/theme/app_theme.dart';
import 'providers/trip_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/main_scaffold.dart';
import 'screens/auth/login_screen.dart';
import 'providers/theme_provider.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_database/firebase_database.dart';

import 'screens/auth/email_verification_screen.dart';
import 'models/auth_user.dart';

import 'core/utils/app_logger.dart';
import 'core/database/app_database.dart';
import 'core/services/crash_reporting_service.dart';
import 'core/services/live_currency_service.dart';
import 'core/services/secret_config_service.dart';
import 'screens/common/app_error_boundary.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  AppLogger.info("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize multi-tier environment secrets configuration (.env / --dart-define)
  await SecretConfigService.initialize();

  // Lock application strictly to portrait orientation (Point 4)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Production Global Error Telemetry & Crash Logging
  await CrashReportingService.initialize();
  await LiveCurrencyService.initialize();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    CrashReportingService.recordError(
      details.exception,
      details.stack,
      reason: 'Flutter Framework Error: ${details.exceptionAsString()}',
      fatal: false,
    );
  };

  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    CrashReportingService.recordError(
      error,
      stack,
      reason: 'Unhandled Platform Exception',
      fatal: true,
    );
    return true;
  };

  // Graceful visual error recovery instead of red screen of death
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return AppErrorBoundary(details: details);
  };

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Enable offline persistence explicitly
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  try {
    FirebaseDatabase.instance.setPersistenceEnabled(true);
  } catch (e) {
    AppLogger.warn('Firebase RTDB persistence: $e');
  }

  await MapTileCacheService.purgeLegacyCache();
  await AppDatabase.purgeLegacyDatabase();

  final initialUser = FirebaseAuth.instance.currentUser;
  final storageService = await LocalStorageService.init(
    initialUserId: initialUser?.uid,
  );

  runApp(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(storageService),
      ],
      child: const TripStopsApp(),
    ),
  );
}

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }
}

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class TripStopsApp extends ConsumerWidget {
  const TripStopsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final authService = ref.watch(authServiceProvider);

    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'TrackMyTrip',
      debugShowCheckedModeBanner: false,
      scrollBehavior: const AppScrollBehavior(),
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ref.watch(themeModeProvider),
      home: authState.when(
        data: (user) {
          if (user == null) return const LoginScreen();
          // Require email verification for email-based accounts
          if (user.provider == AuthProviderType.email && !authService.isEmailVerified) {
            return EmailVerificationScreen(email: user.email);
          }
          return const MainScaffold();
        },
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => const LoginScreen(),
      ),
    );
  }
}
