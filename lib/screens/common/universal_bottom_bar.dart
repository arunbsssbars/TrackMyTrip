import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    final currentIndex = (selectedIndexOverride ?? activeTab).clamp(0, 3);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unreadAlerts = ref.watch(proximityAlertServiceProvider).unreadCount;
    final pendingInvites = ref.watch(invitationProvider).length;
    final totalActivityUnread = unreadAlerts + pendingInvites;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceDark : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white.withAlpha(20) : const Color(0xFFE2E8F0),
            width: 0.8,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 50 : 15),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 54,
          child: Row(
            children: [
              _buildNavItem(
                context: context,
                ref: ref,
                index: 0,
                selectedIndex: currentIndex,
                tooltip: 'Journeys Dashboard',
                selectedIcon: Icons.dashboard_rounded,
                unselectedIcon: Icons.dashboard_outlined,
                isDark: isDark,
              ),
              _buildNavItem(
                context: context,
                ref: ref,
                index: 1,
                selectedIndex: currentIndex,
                tooltip: 'Live',
                selectedIcon: Icons.card_travel_rounded,
                unselectedIcon: Icons.card_travel_outlined,
                isDark: isDark,
              ),
              _buildNavItem(
                context: context,
                ref: ref,
                index: 2,
                selectedIndex: currentIndex,
                tooltip: 'Activity Hub',
                selectedIcon: Icons.local_activity_rounded,
                unselectedIcon: Icons.local_activity_outlined,
                isDark: isDark,
                badgeCount: totalActivityUnread,
              ),
              _buildNavItem(
                context: context,
                ref: ref,
                index: 3,
                selectedIndex: currentIndex,
                tooltip: 'Profile',
                selectedIcon: Icons.person_rounded,
                unselectedIcon: Icons.person_outline_rounded,
                isDark: isDark,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required WidgetRef ref,
    required int index,
    required int selectedIndex,
    required String tooltip,
    required IconData selectedIcon,
    required IconData unselectedIcon,
    required bool isDark,
    int badgeCount = 0,
  }) {
    final isSelected = index == selectedIndex;
    const activeColor = AppTheme.primary;
    final inactiveColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Expanded(
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            if (onDestinationSelected != null) {
              onDestinationSelected!(index);
            } else {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
              ref.read(activeMainTabProvider.notifier).state = index;
            }
          },
          splashColor: activeColor.withAlpha(20),
          highlightColor: Colors.transparent,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? activeColor.withAlpha(26) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Icon(
                    isSelected ? selectedIcon : unselectedIcon,
                    size: 24,
                    color: isSelected ? activeColor : inactiveColor,
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      top: -4,
                      right: -8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE11D48),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark ? AppTheme.surfaceDark : Colors.white,
                            width: 1.5,
                          ),
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          badgeCount > 99 ? '99+' : '$badgeCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
