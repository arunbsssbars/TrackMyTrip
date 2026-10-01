import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_constants.dart';
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

class TimelineTab extends ConsumerStatefulWidget {
  final Trip trip;

  const TimelineTab({super.key, required this.trip});

  @override
  ConsumerState<TimelineTab> createState() => _TimelineTabState();
}

class _TimelineTabState extends ConsumerState<TimelineTab> {
  final Set<String> _expandedDateKeys = {};
  String? _selectedDateFilterKey;
  String? _selectedCategory;
  bool _hasInitializedExpandedDates = false;

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

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height * 0.7,
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
                          width: 50,
                          height: 50,
                          alignment: Alignment.topCenter,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                              boxShadow: const [
                                BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 3)),
                              ],
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Icon(
                              AppConstants.getStoppageIcon(stop.category),
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Top Header
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A).withAlpha(230) : Colors.white.withAlpha(240),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.place_rounded, color: AppTheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            stop.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom Info Card
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, -4)),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          stop.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        if (stop.address != null && stop.address!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            stop.address!,
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          'Coordinates: ${stop.latitude.toStringAsFixed(4)}, ${stop.longitude.toStringAsFixed(4)}',
                          style: const TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'monospace'),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
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
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Open Stoppage Details'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
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

  @override
  Widget build(BuildContext context) {
    final stoppages = ref.watch(currentTripStoppagesProvider);
    final expenses = ref.watch(currentTripExpensesProvider);
    final memories = ref.watch(currentTripMemoriesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final availableCategories = stoppages.map((s) => s.category).toSet().toList()..sort();
    final effectiveStoppages = _selectedCategory == null
        ? stoppages
        : stoppages.where((s) => s.category.toLowerCase() == _selectedCategory!.toLowerCase()).toList();

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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
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
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_location_alt_outlined, size: 56, color: Colors.grey[400]),
                const SizedBox(height: 14),
                const Text('No Stoppages Tagged Yet', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text(
                  'Tag viewpoints, cafes, stays, and gas stations along your route to organize your itinerary and bills.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          )
        else if (effectiveStoppages.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  AppConstants.getStoppageIcon(_selectedCategory ?? 'Other'),
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 14),
                Text(
                  'No "$_selectedCategory" Stoppages Found',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Try selecting a different category or clear the active filter to view all itinerary stops.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  onPressed: () => setState(() => _selectedCategory = null),
                  icon: const Icon(Icons.clear_all_rounded, size: 16),
                  label: const Text('Show All Stoppages'),
                ),
              ],
            ),
          )
        else
          ...displayedDateKeys.map((dateKey) {
            final dayIndex = sortedDateKeys.indexOf(dateKey) + 1;
            final dayStoppages = groupedStoppages[dateKey]!;
            final firstDate = dayStoppages.first.arrivedAt;
            final isExpanded = _expandedDateKeys.contains(dateKey);
            final isToday = dateKey == todayKey;

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
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isToday ? AppTheme.primary.withAlpha(25) : (isDark ? Colors.grey[800] : Colors.grey[200]),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${dayStoppages.length} stops',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: isToday ? AppTheme.primary : (isDark ? Colors.grey[300] : Colors.grey[700]),
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
                                        child: Container(
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
                                                  Expanded(
                                                    child: Text(
                                                      stop.name,
                                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, letterSpacing: -0.2),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  if (stop.isOngoing)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: Colors.green.withAlpha(25),
                                                        borderRadius: BorderRadius.circular(10),
                                                        border: Border.all(color: Colors.green.withAlpha(60), width: 0.8),
                                                      ),
                                                      child: const Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(Icons.circle, color: Colors.green, size: 5),
                                                          SizedBox(width: 3),
                                                          Text(
                                                            'Active',
                                                            style: TextStyle(color: Colors.green, fontSize: 9.5, fontWeight: FontWeight.bold),
                                                          ),
                                                        ],
                                                      ),
                                                    )
                                                  else if (stop.duration != null)
                                                    Text(
                                                      DateFormatter.formatDuration(stop.duration!),
                                                      style: TextStyle(fontSize: 10.5, color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.w600),
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
