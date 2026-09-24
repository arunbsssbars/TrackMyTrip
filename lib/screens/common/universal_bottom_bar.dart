import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/proximity_alert_service.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/invitation_provider.dart';
import '../main_scaffold.dart';

class UniversalBottomBar extends ConsumerWidget {
  final int? selectedIndexOverride;
  final ValueChanged<int>? onDestinationSelected;

  const UniversalBottomBar({
    super.key,
    this.selectedIndexOverride,
    this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTab = ref.watch(activeMainTabProvider);
    final currentIndex = selectedIndexOverride ?? activeTab;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unreadAlerts = ref.watch(proximityAlertServiceProvider).unreadCount;
    final pendingInvites = ref.watch(invitationProvider).length;
    final totalActivityUnread = unreadAlerts + pendingInvites;

    return NavigationBar(
      selectedIndex: currentIndex.clamp(0, 4),
      onDestinationSelected: (index) {
        if (onDestinationSelected != null) {
          onDestinationSelected!(index);
        } else {
          // If we are on a pushed sub-screen (e.g. TripDetailScreen), pop back to root scaffold first
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
          ref.read(activeMainTabProvider.notifier).state = index;
        }
      },
      backgroundColor: isDark ? AppTheme.surfaceDark : Colors.white,
      elevation: 8,
      indicatorColor: AppTheme.primary.withAlpha(40),
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.explore_outlined),
          selectedIcon: Icon(Icons.explore_rounded, color: AppTheme.primary),
          label: 'Journeys',
        ),
        const NavigationDestination(
          icon: Icon(Icons.navigation_outlined),
          selectedIcon: Icon(Icons.navigation_rounded, color: AppTheme.primary),
          label: 'Current Trip',
        ),
        NavigationDestination(
          icon: Badge(
            isLabelVisible: totalActivityUnread > 0,
            label: Text('$totalActivityUnread', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            child: const Icon(Icons.notifications_outlined),
          ),
          selectedIcon: Badge(
            isLabelVisible: totalActivityUnread > 0,
            label: Text('$totalActivityUnread', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            child: const Icon(Icons.notifications_rounded, color: AppTheme.primary),
          ),
          label: 'Activity',
        ),
        const NavigationDestination(
          icon: Icon(Icons.photo_library_outlined),
          selectedIcon: Icon(Icons.photo_library_rounded, color: AppTheme.primary),
          label: 'Memories',
        ),
        const NavigationDestination(
          icon: Icon(Icons.account_circle_outlined),
          selectedIcon: Icon(Icons.account_circle_rounded, color: AppTheme.primary),
          label: 'Profile',
        ),
      ],
    );
  }
}
