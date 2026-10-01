import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/push_notification_service.dart';
import '../core/theme/app_theme.dart';
import '../providers/trip_provider.dart';
import 'activity/activity_hub_tab.dart';
import 'common/universal_bottom_bar.dart';
import 'home/home_screen.dart';
import 'notifications/in_app_notification_banner.dart';
import 'profile/profile_tab.dart';
import 'trip/current_trip_tab.dart';
import '../core/services/proximity_alert_service.dart';

final activeMainTabProvider = StateProvider<int>((ref) => 0);

class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  StreamSubscription? _bannerSubscription;

  @override
  void initState() {
    super.initState();
    // Delay slightly to ensure ProviderScope is fully mounted
    Future.microtask(() {
      ref.read(pushNotificationServiceProvider).init();
      ref.read(activeMainTabProvider.notifier).state = 0;
    });

    _bannerSubscription = ref.read(proximityAlertServiceProvider).bannerStream.listen((alert) {
      if (mounted) {
        InAppNotificationBanner.show(
          context,
          alert,
          onMuteBanners: () {
            ref.read(proximityAlertServiceProvider).toggleInAppBanners(false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Banner alerts turned off. Notifications will appear silently under Activity tab.'),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 3),
              ),
            );
          },
        );
      }
    });
  }

  @override
  void dispose() {
    _bannerSubscription?.cancel();
    super.dispose();
  }

  final List<Widget> _tabs = const [
    HomeScreen(),
    CurrentTripTab(),
    ActivityHubTab(),
    ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(activeMainTabProvider);
    final isSyncing = ref.watch(isSyncingTripsProvider);

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: currentIndex,
            children: _tabs,
          ),
          if (isSyncing)
            Positioned(
              top: MediaQuery.of(context).padding.top,
              left: 0,
              right: 0,
              child: const SizedBox(
                height: 2.5,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: const UniversalBottomBar(),
    );
  }
}
