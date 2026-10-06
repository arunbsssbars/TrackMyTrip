import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/design_system/design_system.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../models/stoppage.dart';
import '../../../models/trip.dart';
import '../../../providers/expense_provider.dart';
import '../../../providers/memory_provider.dart';
import '../../../providers/stoppage_provider.dart';
import '../../stoppage/add_stoppage_dialog.dart';
import '../../stoppage/stoppage_detail_screen.dart';
import '../../../core/utils/trip_guard_helper.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/live_location_tracker_service.dart';

class TimelineTab extends ConsumerStatefulWidget {
  final Trip trip;
  final void Function(Stoppage stoppage)? onNavigateToMap;

  const TimelineTab({
    super.key,
    required this.trip,
    this.onNavigateToMap,
  });

  @override
  ConsumerState<TimelineTab> createState() => _TimelineTabState();
}

class _TimelineTabState extends ConsumerState<TimelineTab> {
  final Set<String> _expandedDateKeys = {};
  String? _selectedDateFilterKey;
  String? _selectedCategory;
  bool _hasInitializedExpandedDates = false;
  bool _isCompactDensity = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openAddStoppageDialog(BuildContext context, {bool autoDetectGps = true}) async {
    final canProceed = await TripGuardHelper.ensureTripOpenForEdit(
      context,
      ref,
      widget.trip,
      actionLabel: 'add a stoppage',
    );
    if (!canProceed || !context.mounted) return;

    AddStoppageDialog.show(
      context,
      tripId: widget.trip.id,
      autoDetectGps: autoDetectGps,
    );
  }

  void _viewStoppageOnMap(BuildContext context, Stoppage stop) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stopPos = LatLng(stop.latitude, stop.longitude);
    final userPos = ref.read(liveLocationTrackerProvider).currentPosition;
    double? distKm;
    if (userPos != null) {
      distKm = LocationService.calculatePolylineDistanceKm([
        LatLng(userPos.latitude, userPos.longitude),
        stopPos,
      ]);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: const [
            BoxShadow(color: Colors.black38, blurRadius: 16, offset: Offset(0, -4)),
          ],
        ),
        child: Column(
          children: [
            // Handle bar
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withAlpha(isDark ? 80 : 100),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),

            // Top Header: Title, Category Icon, Close Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      AppConstants.getStoppageIcon(stop.category),
                      color: AppTheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stop.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${stop.category.toUpperCase()}${distKm != null ? " • ${distKm.toStringAsFixed(1)} km away" : ""}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Embedded Interactive Mini Map
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    options: MapOptions(
                      initialCenter: stopPos,
                      initialZoom: 15.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: AppConstants.getMapTileUrl(isDark: isDark),
                        userAgentPackageName: 'com.trackmytrip.app',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: stopPos,
                            width: 48,
                            height: 48,
                            alignment: Alignment.topCenter,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppTheme.primary,
                                shape: BoxShape.circle,
                                boxShadow: const [
                                  BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 3)),
                                ],
                                border: Border.all(color: Colors.white, width: 2.5),
                              ),
                              child: Icon(
                                AppConstants.getStoppageIcon(stop.category),
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Floating quick shortcut to full map
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Material(
                      color: isDark ? const Color(0xFF0F172A).withAlpha(220) : Colors.white.withAlpha(230),
                      borderRadius: BorderRadius.circular(20),
                      elevation: 3,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          ref.read(focusedStoppageProvider.notifier).state = stop;
                          widget.onNavigateToMap?.call(stop);
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.fullscreen_rounded, size: 16, color: AppTheme.primary),
                              SizedBox(width: 4),
                              Text('Expand Map', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Action Controls Container
            Container(
              padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (stop.address != null && stop.address!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              stop.address!,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.grey[300] : const Color(0xFF334155),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Action Buttons Row: View on Full Map & Turn-by-Turn Navigation
                  Row(
                    children: [
                      // View on Full Map (In-App Route Map)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            ref.read(focusedStoppageProvider.notifier).state = stop;
                            widget.onNavigateToMap?.call(stop);
                          },
                          icon: const Icon(Icons.map_rounded, size: 18),
                          label: const Text(
                            'View on Route Map',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primary,
                            side: const BorderSide(color: AppTheme.primary, width: 1.4),
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Start External Turn-by-Turn Navigation
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () async {
                            final success = await LocationService.openExternalNavigation(
                              stop.latitude,
                              stop.longitude,
                              label: stop.name,
                            );
                            if (!success && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Could not open external navigation maps.')),
                              );
                            }
                          },
                          icon: const Icon(Icons.navigation_rounded, size: 18),
                          label: const Text(
                            'Navigate (GPS)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Stoppage Details Screen
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => StoppageDetailScreen(
                            stoppageId: stop.id,
                            tripId: widget.trip.id,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.info_outline_rounded, size: 15),
                    label: const Text(
                      'Open Stoppage Details & Bills',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getDateKey(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  String _formatDateHeading(DateTime dt, int dayIndex) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final logDate = DateTime(dt.year, dt.month, dt.day);

    if (logDate == today) {
      return 'Today • ${DateFormatter.formatShortDate(dt)}';
    } else if (logDate == yesterday) {
      return 'Yesterday • ${DateFormatter.formatShortDate(dt)}';
    } else {
      return 'Day $dayIndex • ${DateFormatter.formatShortDate(dt)}';
    }
  }

  void _toggleDateExpanded(String dateKey) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_expandedDateKeys.contains(dateKey)) {
        _expandedDateKeys.remove(dateKey);
      } else {
        _expandedDateKeys.add(dateKey);
      }
    });
  }

  void _selectDayFilter(String? dateKey) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedDateFilterKey = dateKey;
      if (dateKey != null) {
        _expandedDateKeys.add(dateKey);
      }
    });
  }

  Widget _buildDayFilterPill({
    required String label,
    required String subLabel,
    int? count,
    required bool isSelected,
    bool isToday = false,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primary
                : (isDark ? AppTheme.surfaceDark : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primary
                  : (isToday
                      ? AppTheme.primary.withAlpha(120)
                      : (isDark ? AppTheme.borderDark : AppTheme.borderLight)),
              width: isSelected || isToday ? 1.4 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.primary.withAlpha(70),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isToday && !isSelected) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white : AppTheme.textMainLight),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withAlpha(50)
                      : (isDark ? Colors.grey[800] : const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  count != null ? '$count' : subLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.grey[300] : AppTheme.textMutedLight),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilterChip({
    required String label,
    IconData? icon,
    int? count,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primary
                : (isDark ? AppTheme.surfaceDark : Colors.white),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primary
                  : (isDark ? AppTheme.borderDark : AppTheme.borderLight),
              width: isSelected ? 1.4 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 13,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.grey[300] : AppTheme.primary),
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white : AppTheme.textMainLight),
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withAlpha(50)
                        : (isDark ? Colors.grey[800] : const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.grey[300] : AppTheme.textMutedLight),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactStoppageTile(
    BuildContext context,
    Stoppage stop,
    double stopTotalSpent,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
          width: 1.1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        stop.name,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    if (stop.isOngoing) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: Colors.green.withAlpha(25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Live', style: TextStyle(color: Colors.green, fontSize: 8.5, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2.5),
                Text(
                  '${stop.category} • ${DateFormatter.formatDateTime(stop.arrivedAt)} • ${stop.formattedDuration}',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (stopTotalSpent > 0.01)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withAlpha(isDark ? 35 : 20),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                CurrencyFormatter.format(stopTotalSpent, currency: widget.trip.defaultCurrency),
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
              ),
            ),
          Icon(
            Icons.chevron_right_rounded,
            size: 19,
            color: isDark ? Colors.grey[400] : const Color(0xFF94A3B8),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stoppages = ref.watch(currentTripStoppagesProvider);
    final expenses = ref.watch(currentTripExpensesProvider);
    final memories = ref.watch(currentTripMemoriesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chronologicalStoppages = [...stoppages]..sort((a, b) => a.arrivedAt.compareTo(b.arrivedAt));
    final activeStoppage = chronologicalStoppages.where((s) => s.isOngoing).lastOrNull;

    final availableCategories = stoppages.map((s) => s.category).toSet().toList()..sort();
    List<Stoppage> effectiveStoppages = _selectedCategory == null
        ? stoppages
        : stoppages.where((s) => s.category.toLowerCase() == _selectedCategory!.toLowerCase()).toList();

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      effectiveStoppages = effectiveStoppages.where((s) {
        return s.name.toLowerCase().contains(q) ||
            (s.address?.toLowerCase().contains(q) ?? false) ||
            (s.notes?.toLowerCase().contains(q) ?? false) ||
            s.category.toLowerCase().contains(q);
      }).toList();
    }

    int totalStoppedMinutes = 0;
    for (final stop in stoppages) {
      if (stop.duration != null) {
        totalStoppedMinutes += stop.duration!.inMinutes;
      }
    }
    final totalSpentOnStoppages = expenses
        .where((e) => e.stoppageId != null && e.stoppageId!.isNotEmpty)
        .fold<double>(0.0, (sum, e) => sum + e.totalAmount);

    String formattedTotalDuration = '';
    if (totalStoppedMinutes > 0) {
      final h = totalStoppedMinutes ~/ 60;
      final m = totalStoppedMinutes % 60;
      if (h > 0 && m > 0) {
        formattedTotalDuration = '${h}h ${m}m paused';
      } else if (h > 0) {
        formattedTotalDuration = '${h}h paused';
      } else {
        formattedTotalDuration = '${m}m paused';
      }
    }

    // Group effective stoppages date-wise
    final Map<String, List<Stoppage>> groupedStoppages = {};
    for (final stop in effectiveStoppages) {
      final key = _getDateKey(stop.arrivedAt);
      groupedStoppages.putIfAbsent(key, () => []).add(stop);
    }

    // Sort dates with MOST RECENT first (Descending order)
    final sortedDateKeys = groupedStoppages.keys.toList()..sort((a, b) => b.compareTo(a));
    final todayKey = _getDateKey(DateTime.now());

    // Expand current date (or most recent date at top) by default on initial load
    if (!_hasInitializedExpandedDates && sortedDateKeys.isNotEmpty) {
      if (sortedDateKeys.contains(todayKey)) {
        _expandedDateKeys.add(todayKey);
      } else {
        _expandedDateKeys.add(sortedDateKeys.first);
      }
      _hasInitializedExpandedDates = true;
    }

    final displayedDateKeys = _selectedDateFilterKey != null &&
            groupedStoppages.containsKey(_selectedDateFilterKey!)
        ? [_selectedDateFilterKey!]
        : sortedDateKeys;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final hPad = screenWidth >= 800 ? ((screenWidth - 760) / 2).clamp(16.0, 380.0) : 16.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 96),
        children: [
          // Timeline Overview Header Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppTheme.borderDark : AppTheme.borderLight, width: 1.1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(15),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withAlpha(25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.timeline_rounded, size: 18, color: AppTheme.primary),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Journey Timeline & Stops',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: -0.2),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withAlpha(20),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _selectedCategory == null
                                ? '${stoppages.length} Stoppages'
                                : '${effectiveStoppages.length}/${stoppages.length} Filtered',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primary),
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Loop 113: Batch Expand / Collapse All Days Action
                        if (sortedDateKeys.length > 1)
                          Semantics(
                            button: true,
                            label: _expandedDateKeys.length == sortedDateKeys.length
                                ? 'Collapse all days'
                                : 'Expand all days',
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  if (_expandedDateKeys.length == sortedDateKeys.length) {
                                    _expandedDateKeys.clear();
                                  } else {
                                    _expandedDateKeys.addAll(sortedDateKeys);
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Tooltip(
                                message: _expandedDateKeys.length == sortedDateKeys.length
                                    ? 'Collapse All Days'
                                    : 'Expand All Days',
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    _expandedDateKeys.length == sortedDateKeys.length
                                        ? Icons.unfold_less_rounded
                                        : Icons.unfold_more_rounded,
                                    size: 19,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(width: 4),
                        Semantics(
                          button: true,
                          label: _isCompactDensity ? 'Switch to detailed timeline' : 'Switch to compact timeline',
                          child: InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _isCompactDensity = !_isCompactDensity);
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Tooltip(
                              message: _isCompactDensity ? 'Detailed View' : 'Compact View',
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  _isCompactDensity ? Icons.view_agenda_rounded : Icons.view_headline_rounded,
                                  size: 19,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (stoppages.isNotEmpty && (formattedTotalDuration.isNotEmpty || totalSpentOnStoppages > 0.01)) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (formattedTotalDuration.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withAlpha(12) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.timer_outlined, size: 12, color: AppTheme.secondary),
                              const SizedBox(width: 4),
                              Text(
                                formattedTotalDuration,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.grey[300] : AppTheme.textMainLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (totalSpentOnStoppages > 0.01)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withAlpha(12) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.receipt_long_rounded, size: 12, color: Color(0xFF10B981)),
                              const SizedBox(width: 4),
                              Text(
                                '${CurrencyFormatter.format(totalSpentOnStoppages, currency: widget.trip.defaultCurrency)} spent',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.grey[300] : AppTheme.textMainLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Active Stoppage Banner (Loop 61)
          if (activeStoppage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF064E3B), const Color(0xFF0F172A)]
                      : [const Color(0xFFD1FAE5), const Color(0xFFF0FDF4)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF10B981).withAlpha(isDark ? 100 : 80),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withAlpha(isDark ? 30 : 20),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.location_on_rounded, size: 16, color: Colors.white),
                ),
                title: Text(
                  'CURRENTLY AT • ${activeStoppage.formattedDuration}',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w900,
                    color: isDark ? const Color(0xFF34D399) : const Color(0xFF047857),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  activeStoppage.name,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
                    color: isDark ? Colors.white70 : const Color(0xFF065F46),
                  ),
                  tooltip: 'Inspect',
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => StoppageDetailScreen(
                          stoppageId: activeStoppage.id,
                          tripId: widget.trip.id,
                        ),
                      ),
                    );
                  },
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Search Input Bar
          if (stoppages.isNotEmpty) ...[
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: isDark ? AppTheme.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                  width: 1,
                ),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search stops by name, address or note...',
                  hintStyle: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? Colors.grey[500] : const Color(0xFF94A3B8),
                  ),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppTheme.primary),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Horizontal Category Quick Filter Bar
          if (stoppages.isNotEmpty && availableCategories.length > 1) ...[
            SizedBox(
              height: 32,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildCategoryFilterChip(
                    label: 'All Stops',
                    icon: Icons.grid_view_rounded,
                    count: stoppages.length,
                    isSelected: _selectedCategory == null,
                    onTap: () => setState(() => _selectedCategory = null),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 6),
                  ...availableCategories.map((cat) {
                    final catCount = stoppages.where((s) => s.category.toLowerCase() == cat.toLowerCase()).length;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _buildCategoryFilterChip(
                        label: cat,
                        icon: AppConstants.getStoppageIcon(cat),
                        count: catCount,
                        isSelected: _selectedCategory == cat,
                        onTap: () => setState(() => _selectedCategory = (_selectedCategory == cat ? null : cat)),
                        isDark: isDark,
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Active Category Filter Indicator
          if (_selectedCategory != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppTheme.primary.withAlpha(isDark ? 25 : 15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primary.withAlpha(isDark ? 60 : 40)),
              ),
              child: Row(
                children: [
                  Icon(AppConstants.getStoppageIcon(_selectedCategory!), size: 14, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Filtered: $_selectedCategory (${effectiveStoppages.length} stops)',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.primary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => setState(() => _selectedCategory = null),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Clear',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white70 : AppTheme.primary,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Icon(
                              Icons.close_rounded,
                              size: 13,
                              color: isDark ? Colors.white70 : AppTheme.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Sticky Horizontal Day Navigation Bar
          if (sortedDateKeys.length > 1) ...[
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildDayFilterPill(
                    label: 'All Days',
                    subLabel: '${effectiveStoppages.length}',
                    isSelected: _selectedDateFilterKey == null,
                    onTap: () => _selectDayFilter(null),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  ...sortedDateKeys.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final dateKey = entry.value;
                    final count = groupedStoppages[dateKey]?.length ?? 0;
                    final firstStopDate = groupedStoppages[dateKey]!.first.arrivedAt;
                    final dayTitle = 'Day ${sortedDateKeys.length - idx}';
                    final dateSubtitle = DateFormatter.formatShortDate(firstStopDate);
                    final isSelected = _selectedDateFilterKey == dateKey;
                    final isToday = dateKey == todayKey;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _buildDayFilterPill(
                        label: isToday ? 'Today' : dayTitle,
                        subLabel: dateSubtitle,
                        count: count,
                        isSelected: isSelected,
                        isToday: isToday,
                        onTap: () => _selectDayFilter(dateKey),
                        isDark: isDark,
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

        if (stoppages.isEmpty)
          AppEmptyState(
            icon: Icons.add_location_alt_outlined,
            title: 'No Stoppages Tagged Yet',
            message: 'Tag viewpoints, cafes, stays, and gas stations along your route to organize your itinerary and bills.',
            actionLabel: 'Add First Stop',
            onAction: () => _openAddStoppageDialog(context),
          )
        else if (effectiveStoppages.isEmpty)
          AppEmptyState(
            icon: AppConstants.getStoppageIcon(_selectedCategory ?? 'Other'),
            title: 'No "$_selectedCategory" Stoppages Found',
            message: 'Try selecting a different category or clear the active filter to view all itinerary stops.',
            actionLabel: 'Show All Stoppages',
            onAction: () => setState(() => _selectedCategory = null),
          )
        else
          ...displayedDateKeys.map((dateKey) {
            final dayIndex = sortedDateKeys.indexOf(dateKey) + 1;
            final dayStoppages = groupedStoppages[dateKey]!;
            final firstDate = dayStoppages.first.arrivedAt;
            final isExpanded = _expandedDateKeys.contains(dateKey);
            final isToday = dateKey == todayKey;

            // Loop 53: Rollup stay duration for day header
            int dayStayMinutes = 0;
            for (final s in dayStoppages) {
              if (s.duration != null) {
                dayStayMinutes += s.duration!.inMinutes;
              }
            }
            String dayDurationLabel = '';
            if (dayStayMinutes > 0) {
              final h = dayStayMinutes ~/ 60;
              final m = dayStayMinutes % 60;
              if (h > 0 && m > 0) {
                dayDurationLabel = '${h}h ${m}m';
              } else if (h > 0) {
                dayDurationLabel = '${h}h';
              } else {
                dayDurationLabel = '${m}m';
              }
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: Material(
                color: isDark ? AppTheme.surfaceDark.withAlpha(120) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
                clipBehavior: Clip.antiAlias,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isToday
                          ? AppTheme.primary.withAlpha(120)
                          : (isDark ? AppTheme.borderDark : AppTheme.borderLight),
                      width: isToday ? 1.4 : 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Fold / Unfold Date Header Accordion Banner
                      InkWell(
                        onTap: () => _toggleDateExpanded(dateKey),
                        borderRadius: BorderRadius.circular(18),
                        splashColor: AppTheme.primary.withAlpha(20),
                        highlightColor: AppTheme.primary.withAlpha(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isToday ? AppTheme.primary : (isDark ? Colors.grey[800] : const Color(0xFFE2E8F0)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.calendar_today_rounded,
                              size: 13,
                              color: isToday ? Colors.white : (isDark ? Colors.grey[300] : AppTheme.primary),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _formatDateHeading(firstDate, dayIndex),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12.5,
                                      letterSpacing: -0.2,
                                      color: isToday ? AppTheme.primary : (isDark ? Colors.white : AppTheme.textMainLight),
                                    ),
                                  ),
                                ),
                                if (isToday) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withAlpha(25),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'Now',
                                      style: TextStyle(color: Colors.green, fontSize: 8.5, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isToday ? AppTheme.primary.withAlpha(25) : (isDark ? Colors.grey[800] : Colors.grey[200]),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                dayDurationLabel.isNotEmpty
                                    ? '${dayStoppages.length} stops • $dayDurationLabel'
                                    : '${dayStoppages.length} stops',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isToday ? AppTheme.primary : (isDark ? Colors.grey[300] : Colors.grey[700]),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                            size: 20,
                            color: Colors.grey[500],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Stoppages on this Date (Unfolded state)
                  if (isExpanded) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 12, 10, 4),
                      child: Column(
                        children: [
                          ...dayStoppages.asMap().entries.map((entry) {
                            final index = entry.key;
                            final stop = entry.value;
                            final isLastOnDay = index == dayStoppages.length - 1;
                            final stopExpenses = expenses.where((e) => e.stoppageId == stop.id).toList();
                            final stopMemories = memories.where((m) => m.stoppageId == stop.id).toList();
                            final stopTotalSpent = stopExpenses.fold<double>(0, (sum, e) => sum + e.totalAmount);

                            return IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Timeline Column (Dots and Line)
                                  SizedBox(
                                    width: 38,
                                  child: Column(
                                    children: [
                                      // Node Marker
                                      Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: stop.isOngoing ? Colors.green : AppTheme.primary,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isDark ? AppTheme.bgDark : Colors.white,
                                            width: 2.5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: (stop.isOngoing ? Colors.green : AppTheme.primary).withAlpha(80),
                                              blurRadius: 5,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: Icon(
                                            AppConstants.getStoppageIcon(stop.category),
                                            color: Colors.white,
                                            size: 13,
                                          ),
                                        ),
                                      ),
                                      // Connecting Line
                                      if (!isLastOnDay)
                                        Expanded(
                                          child: Container(
                                            width: 2.5,
                                            color: AppTheme.primary.withAlpha(60),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),

                                // Stoppage Card
                                Expanded(
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: Material(
                                      color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
                                      elevation: isDark ? 0 : 1.5,
                                      shadowColor: Colors.black.withAlpha(isDark ? 40 : 16),
                                      borderRadius: BorderRadius.circular(16),
                                      clipBehavior: Clip.antiAlias,
                                      child: InkWell(
                                        onTap: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (context) => StoppageDetailScreen(
                                                stoppageId: stop.id,
                                                tripId: widget.trip.id,
                                              ),
                                            ),
                                          );
                                        },
                                        borderRadius: BorderRadius.circular(16),
                                        splashColor: AppTheme.primary.withAlpha(22),
                                        highlightColor: AppTheme.primary.withAlpha(12),
                                        child: _isCompactDensity
                                            ? _buildCompactStoppageTile(context, stop, stopTotalSpent, isDark)
                                            : Container(
                                          padding: const EdgeInsets.all(12.5),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(
                                              color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
                                              width: 1.1,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                crossAxisAlignment: CrossAxisAlignment.center,
                                                children: [
                                                  Builder(
                                                    builder: (context) {
                                                      final stopNumber = chronologicalStoppages.indexWhere((s) => s.id == stop.id) + 1;
                                                      if (stopNumber <= 0) return const SizedBox.shrink();
                                                      return Container(
                                                        margin: const EdgeInsets.only(right: 6),
                                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                        decoration: BoxDecoration(
                                                          color: AppTheme.primary.withAlpha(20),
                                                          borderRadius: BorderRadius.circular(6),
                                                          border: Border.all(color: AppTheme.primary.withAlpha(50), width: 0.8),
                                                        ),
                                                        child: Text(
                                                          '#$stopNumber',
                                                          style: const TextStyle(
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.w900,
                                                            color: AppTheme.primary,
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                  Expanded(
                                                    child: Text(
                                                      stop.name,
                                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, letterSpacing: -0.2),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (stopTotalSpent > 0 || stopMemories.isNotEmpty) ...[
                                                    const SizedBox(width: 4),
                                                    Tooltip(
                                                      message: 'Milestone: ${stopTotalSpent > 0 ? "Has bills" : ""} ${stopMemories.isNotEmpty ? "Has memories" : ""}',
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                        decoration: BoxDecoration(
                                                          color: Colors.amber.withAlpha(isDark ? 40 : 25),
                                                          borderRadius: BorderRadius.circular(6),
                                                          border: Border.all(color: Colors.amber.withAlpha(80), width: 0.8),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Icon(Icons.star_rounded, size: 11, color: isDark ? Colors.amber[300] : Colors.amber[800]),
                                                            if (stopMemories.isNotEmpty) ...[
                                                              const SizedBox(width: 2),
                                                              Icon(Icons.camera_alt_rounded, size: 10, color: isDark ? Colors.amber[300] : Colors.amber[800]),
                                                            ],
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                  const SizedBox(width: 6),
                                                  if (stop.isOngoing)
                                                    Flexible(
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: Colors.green.withAlpha(25),
                                                          borderRadius: BorderRadius.circular(10),
                                                          border: Border.all(color: Colors.green.withAlpha(60), width: 0.8),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            const Icon(Icons.circle, color: Colors.green, size: 5),
                                                            const SizedBox(width: 3.5),
                                                            Flexible(
                                                              child: AppResilientText.badge(
                                                                stop.formattedDuration,
                                                                style: const TextStyle(color: Colors.green, fontSize: 9.5, fontWeight: FontWeight.bold),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    )
                                                  else
                                                    Flexible(
                                                      child: Text(
                                                        stop.formattedDuration,
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: TextStyle(fontSize: 10.5, color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.w600),
                                                      ),
                                                    ),
                                                  const SizedBox(width: 3),
                                                  Icon(
                                                    Icons.chevron_right_rounded,
                                                    size: 19,
                                                    color: isDark ? Colors.grey[400] : const Color(0xFF94A3B8),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 3),

                                              // Category + Time
                                              Text.rich(
                                                TextSpan(
                                                  children: [
                                                    TextSpan(
                                                      text: stop.category,
                                                      style: const TextStyle(fontSize: 10.5, color: AppTheme.secondary, fontWeight: FontWeight.bold),
                                                    ),
                                                    const TextSpan(text: ' • ', style: TextStyle(color: Colors.grey)),
                                                    TextSpan(
                                                      text: DateFormatter.formatDateTime(stop.arrivedAt),
                                                      style: TextStyle(fontSize: 10.5, color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.w500),
                                                    ),
                                                  ],
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),

                                              // Creator & Location Chips
                                              const SizedBox(height: 5),
                                              Wrap(
                                                spacing: 6,
                                                runSpacing: 4,
                                                crossAxisAlignment: WrapCrossAlignment.center,
                                                children: [
                                                  if (stop.createdByName != null && stop.createdByName!.isNotEmpty)
                                                    Container(
                                                      constraints: const BoxConstraints(maxWidth: 160),
                                                      padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 3),
                                                      decoration: BoxDecoration(
                                                        color: AppTheme.primary.withAlpha(isDark ? 30 : 15),
                                                        borderRadius: BorderRadius.circular(6),
                                                        border: Border.all(color: AppTheme.primary.withAlpha(isDark ? 60 : 35), width: 0.8),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          const Icon(Icons.person_pin_circle_outlined, size: 10.5, color: AppTheme.primary),
                                                          const SizedBox(width: 3.5),
                                                          Flexible(
                                                            child: Text(
                                                              'Added by ${stop.createdByName}',
                                                              style: const TextStyle(
                                                                fontSize: 9.5,
                                                                fontWeight: FontWeight.w700,
                                                                color: AppTheme.primary,
                                                              ),
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ConstrainedBox(
                                                    constraints: const BoxConstraints(maxWidth: 160),
                                                    child: Material(
                                                      color: Colors.transparent,
                                                      child: Ink(
                                                        decoration: BoxDecoration(
                                                          color: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
                                                          borderRadius: BorderRadius.circular(8),
                                                          border: Border.all(color: isDark ? AppTheme.borderDark : const Color(0xFFCBD5E1), width: 0.9),
                                                        ),
                                                        child: InkWell(
                                                          onTap: () => _viewStoppageOnMap(context, stop),
                                                          borderRadius: BorderRadius.circular(8),
                                                          splashColor: AppTheme.primary.withAlpha(30),
                                                          child: Padding(
                                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                                                            child: Row(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                const Icon(Icons.location_on_outlined, size: 11, color: AppTheme.primary),
                                                                const SizedBox(width: 4),
                                                                Flexible(
                                                                  child: Text(
                                                                    stop.address != null && stop.address!.isNotEmpty
                                                                        ? stop.address!
                                                                        : '${stop.latitude.toStringAsFixed(4)}, ${stop.longitude.toStringAsFixed(4)}',
                                                                    style: TextStyle(
                                                                      fontSize: 9.5,
                                                                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                                                                    ),
                                                                    maxLines: 1,
                                                                    overflow: TextOverflow.ellipsis,
                                                                  ),
                                                                ),
                                                                const SizedBox(width: 4),
                                                                const Icon(Icons.map_rounded, size: 11, color: AppTheme.secondary),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (stop.notes != null && stop.notes!.isNotEmpty) ...[
                                                const SizedBox(height: 5),
                                                Text(
                                                  '"${stop.notes}"',
                                                  style: TextStyle(
                                                    fontStyle: FontStyle.italic,
                                                    fontSize: 11.5,
                                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],

                                              // Badges for expenditure and memories
                                              if (stopExpenses.isNotEmpty || stopMemories.isNotEmpty) ...[
                                                const SizedBox(height: 7),
                                                Wrap(spacing: 6, runSpacing: 4,
                                                  children: [
                                                    if (stopExpenses.isNotEmpty)
                                                      Material(
                                                        color: Colors.transparent,
                                                        child: Ink(
                                                          decoration: BoxDecoration(
                                                            color: AppTheme.primary.withAlpha(isDark ? 28 : 18),
                                                            borderRadius: BorderRadius.circular(7),
                                                            border: Border.all(color: AppTheme.primary.withAlpha(isDark ? 80 : 50), width: 0.9),
                                                          ),
                                                          child: Padding(
                                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                                            child: Row(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                const Icon(Icons.receipt_long_rounded, size: 11, color: AppTheme.primary),
                                                                const SizedBox(width: 3.5),
                                                                Text(
                                                                  CurrencyFormatter.format(stopTotalSpent, currency: widget.trip.defaultCurrency),
                                                                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.primary),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    if (stopExpenses.isNotEmpty && stopMemories.isNotEmpty)
                                                      const SizedBox(width: 6),
                                                    if (stopMemories.isNotEmpty)
                                                      Material(
                                                        color: Colors.transparent,
                                                        child: Ink(
                                                          decoration: BoxDecoration(
                                                            color: AppTheme.secondary.withAlpha(isDark ? 28 : 18),
                                                            borderRadius: BorderRadius.circular(7),
                                                            border: Border.all(color: AppTheme.secondary.withAlpha(isDark ? 80 : 50), width: 0.9),
                                                          ),
                                                          child: Padding(
                                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                                            child: Row(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                const Icon(Icons.photo_library_rounded, size: 11, color: AppTheme.secondary),
                                                                const SizedBox(width: 3.5),
                                                                Text(
                                                                  '${stopMemories.length} Photos',
                                                                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.secondary),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),

                        // Inline Connected "+ Add Stoppage to this Day" action node
                        Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 8),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 38,
                                child: Center(
                                  child: Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppTheme.primary.withAlpha(140),
                                        width: 1.5,
                                      ),
                                      color: AppTheme.primary.withAlpha(isDark ? 30 : 15),
                                    ),
                                    child: const Icon(Icons.add_rounded, size: 14, color: AppTheme.primary),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => _openAddStoppageDialog(context, autoDetectGps: true),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8.5),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: AppTheme.primary.withAlpha(isDark ? 80 : 60),
                                          width: 1,
                                        ),
                                        color: AppTheme.primary.withAlpha(isDark ? 20 : 10),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.add_location_alt_rounded, size: 15, color: AppTheme.primary),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Add Stoppage to this Day',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: isDark ? Colors.white70 : AppTheme.primary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      }),
    ],
  ),
);
  }
}
