import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/services/cloud_trip_sync_service.dart';
import '../../core/services/location_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/trip.dart';
import '../../models/trip_member.dart';
import '../../providers/expense_provider.dart';
import '../../providers/memory_provider.dart';
import '../../providers/settlement_provider.dart';
import '../../providers/stoppage_provider.dart';
import '../../providers/trip_provider.dart';
import '../../core/utils/page_transitions.dart';
import '../trip_detail/trip_detail_screen.dart';
import 'create_trip_sheet.dart';
import 'join_trip_sheet.dart';
import '../common/sync_status_badge.dart';
import '../common/sos_badge_icon.dart';
import '../common/pulsing_live_beacon.dart';
import '../notifications/notification_center_sheet.dart';
import '../main_scaffold.dart';
import '../../providers/invitation_provider.dart';
import 'widgets/trip_invitation_card.dart';
import '../expenses/global_expenses_sheet.dart';
import '../../providers/audit_log_provider.dart';
import '../../core/services/ocr_service.dart';
import '../expenses/add_expense_screen.dart';
import 'package:image_picker/image_picker.dart';
import '../common/user_avatar.dart';
import '../stats/trip_analytics_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _activeFilter = 'all'; // all, group, family, solo
  String _sortBy = 'recent'; // recent, oldest, spend, stops
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _displayedCount = 15;
  final ScrollController _scrollController = ScrollController();
  int _totalFilteredCount = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    LocationService.currencyNotifier.addListener(_onCurrencyChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initGlobalSync();
      LocationService.requestPermission().then((granted) {
        if (granted) {
          LocationService.detectLocalCurrency();
        }
      });
    });
  }

  void _onCurrencyChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    LocationService.currencyNotifier.removeListener(_onCurrencyChanged);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 250) {
      if (_displayedCount < _totalFilteredCount) {
        setState(() {
          _displayedCount += 15;
        });
      }
    }
  }

  void _initGlobalSync() {
    final trips = ref.read(tripListProvider);
    for (final trip in trips) {
      final code = CloudTripSyncService.getRoomCode(trip.id, trip: trip);
      CloudTripSyncService.startLiveSync(
        tripId: trip.id,
        roomCode: code,
        onRemoteUpdateReceived: (pkg) async {
          await ref.read(tripListProvider.notifier).syncRemotePackage(pkg);
          ref.read(allStoppagesProvider.notifier).reload();
          ref.read(allExpensesProvider.notifier).reload();
          ref.read(allMemoriesProvider.notifier).reload();
          ref.read(allSettlementsProvider.notifier).reload();
          ref.read(allAuditLogsProvider.notifier).reload();
          if (mounted) setState(() {});
        },
      );
    }
  }

  void _openCreateTripSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CreateTripSheet(),
    );
  }

  void _openJoinTripSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const JoinTripSheet(),
    );
  }

  void _navigateToTripDetail(Trip trip, {int initialTabIndex = 0}) {
    final localTrip = ref.read(localStorageServiceProvider).getTrip(trip.id);
    if (localTrip == null || localTrip.isDeleted) {
      ref.read(tripListProvider.notifier).deleteTripLocally(trip.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This trip is no longer active or was deleted.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    ref.read(selectedTripIdProvider.notifier).state = trip.id;
    AppNavigator.push(
      context,
      TripDetailScreen(
        tripId: trip.id,
        initialTabIndex: initialTabIndex,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trips = ref.watch(tripListProvider);
    final isSyncingTrips = ref.watch(isSyncingTripsProvider);
    final allStoppages = ref.watch(allStoppagesProvider);
    final allExpenses = ref.watch(allExpensesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter by mode + search query
    final query = _searchQuery.trim().toLowerCase();
    final filteredTrips = trips.where((t) {
      // Mode filter
      if (_activeFilter == 'solo' && !t.isSolo) return false;
      if (_activeFilter == 'family' && !t.isFamily) return false;
      if (_activeFilter == 'group' && (t.isSolo || t.isFamily)) return false;

      // Search query filter
      if (query.isNotEmpty) {
        final matchesTitle = t.title.toLowerCase().contains(query);
        final matchesDesc = t.description?.toLowerCase().contains(query) ?? false;
        final matchesMember = t.members.any((m) => m.name.toLowerCase().contains(query));
        if (!matchesTitle && !matchesDesc && !matchesMember) {
          return false;
        }
      }

      return true;
    }).toList();

    // Sort according to _sortBy
    if (_sortBy == 'recent') {
      filteredTrips.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else if (_sortBy == 'oldest') {
      filteredTrips.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    } else if (_sortBy == 'spend') {
      filteredTrips.sort((a, b) {
        final spendA = allExpenses.where((e) => e.tripId == a.id).fold<double>(0, (s, e) => s + e.totalAmount);
        final spendB = allExpenses.where((e) => e.tripId == b.id).fold<double>(0, (s, e) => s + e.totalAmount);
        return spendB.compareTo(spendA);
      });
    } else if (_sortBy == 'stops') {
      filteredTrips.sort((a, b) {
        final stopsA = allStoppages.where((s) => s.tripId == a.id).length;
        final stopsB = allStoppages.where((s) => s.tripId == b.id).length;
        return stopsB.compareTo(stopsA);
      });
    }

    _totalFilteredCount = filteredTrips.length;

    // Paginate visible trips (Page size: 10)
    final visibleTrips = filteredTrips.take(_displayedCount).toList();

    final userTripIds = trips.map((t) => t.id).toSet();
    final userExpenses = allExpenses.where((e) => userTripIds.contains(e.tripId)).toList();
    final currentTrip = ref.watch(currentTripProvider);

    final groupCount = trips.where((t) => !t.isSolo && !t.isFamily).length;
    final familyCount = trips.where((t) => t.isFamily).length;
    final soloCount = trips.where((t) => t.isSolo).length;

    final grandTotalSpent = userExpenses.fold<double>(0.0, (sum, e) => sum + e.totalAmount);
    final detectedCurr = ref.watch(currencyNotifierProvider).value;
    final defaultCurr = trips.isNotEmpty
        ? trips.first.defaultCurrency
        : (detectedCurr.isNotEmpty ? detectedCurr : 'INR');

    final Map<String, double> categoryBreakdown = {};
    for (final e in userExpenses) {
      final cat = e.category.isNotEmpty ? e.category : 'General';
      categoryBreakdown[cat] = (categoryBreakdown[cat] ?? 0.0) + e.totalAmount;
    }
    final sortedCategories = categoryBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Fixed & Crisp App Bar
          SliverAppBar(
            pinned: true,
            floating: false,
            toolbarHeight: 60,
            titleSpacing: 10,
            backgroundColor: isDark ? AppTheme.surfaceDark : Colors.white,
            elevation: 0.5,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.explore_rounded, color: AppTheme.primary, size: 18),
                ),
                const SizedBox(width: 8),
                Text(
                  'Track My Trip',
                  style: TextStyle(
                    color: isDark ? Colors.white : AppTheme.textMainLight,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            actions: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: SyncStatusBadge(),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                iconSize: 22,
                icon: const Icon(Icons.add_location_alt_rounded, color: AppTheme.primary),
                tooltip: 'Join Journey (Code or QR)',
                onPressed: () => _openJoinTripSheet(context),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: SosBadgeIcon(
                  size: 30,
                  tooltip: 'Emergency SOS & Safety Alerts',
                  onTap: () => NotificationCenterSheet.show(context),
                ),
              ),
              const SizedBox(width: 4),
            ],
          ),

          // 1. Professional Travel Metric Overview Banner
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF0F766E), const Color(0xFF134E4A)]
                        : [const Color(0xFF0D6E63), const Color(0xFF0F766E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0D6E63).withAlpha(80),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.insights_rounded, color: Colors.white70, size: 14),
                            SizedBox(width: 6),
                            Text(
                              'TRAVEL OVERVIEW',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(30),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF34D399),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'Live Sync Active',
                                style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const SizedBox(height: 10),
                    // Tier 1: Journeys (50%) and Total Spend (50%)
                    Row(
                      children: [
                        // Metric 1: Journeys / Trips
                        Expanded(
                          child: InkWell(
                            onTap: trips.isNotEmpty
                                ? () {
                                    HapticFeedback.lightImpact();
                                    if (_scrollController.hasClients) {
                                      _scrollController.animateTo(
                                        240,
                                        duration: const Duration(milliseconds: 350),
                                        curve: Curves.easeOutCubic,
                                      );
                                    }
                                  }
                                : null,
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.explore_rounded, color: Colors.white70, size: 13),
                                      SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          'Journeys',
                                          style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${trips.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.3,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Container(height: 28, width: 1, color: Colors.white24),

                        // Metric 2: Total Spend
                        Expanded(
                          child: InkWell(
                            onTap: trips.isNotEmpty
                                ? () {
                                    HapticFeedback.lightImpact();
                                    GlobalExpensesSheet.show(context);
                                  }
                                : null,
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.account_balance_wallet_rounded, color: Colors.white70, size: 13),
                                      SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          'Total Expense',
                                          style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      SizedBox(width: 2),
                                      Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 14),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    CurrencyFormatter.format(grandTotalSpent, currency: defaultCurr),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.3,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (userExpenses.isNotEmpty && grandTotalSpent > 0) ...[
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          AppNavigator.push(context, const TripAnalyticsScreen());
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(22),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withAlpha(40), width: 0.9),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 44,
                                height: 44,
                                child: PieChart(
                                  PieChartData(
                                    sectionsSpace: 2,
                                    centerSpaceRadius: 10,
                                    sections: sortedCategories.map((entry) {
                                      return PieChartSectionData(
                                        color: _getCategoryColor(entry.key),
                                        value: entry.value,
                                        title: '',
                                        radius: 12,
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Text(
                                          'Category Expense Breakdown',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        SizedBox(width: 4),
                                        Icon(Icons.pie_chart_rounded, size: 12, color: Colors.white70),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 2,
                                      children: sortedCategories.take(3).map((entry) {
                                        final pct = (entry.value / grandTotalSpent * 100).toInt();
                                        return Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 6,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: _getCategoryColor(entry.key),
                                              ),
                                            ),
                                            const SizedBox(width: 3),
                                            Text(
                                              '${entry.key}: $pct%',
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // 2. Search & Filter Bar (Only if user has trips)
          if (trips.isNotEmpty)
            SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.surfaceDark : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0),
                          width: 1.1,
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                            _displayedCount = 15;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search journeys, destinations, notes...',
                          hintStyle: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? Colors.grey[500] : const Color(0xFF94A3B8),
                          ),
                          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppTheme.primary),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                      _displayedCount = 15;
                                    });
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white : AppTheme.textMainLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Sort & Filter Dropdown Button
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.surfaceDark : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0),
                        width: 1.1,
                      ),
                    ),
                    child: PopupMenuButton<String>(
                      icon: const Icon(Icons.tune_rounded, size: 20, color: AppTheme.primary),
                      tooltip: 'Filter & Sort Options',
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      position: PopupMenuPosition.under,
                      constraints: const BoxConstraints(maxWidth: 200),
                      onSelected: (val) {
                        setState(() {
                          _sortBy = val;
                        });
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          enabled: false,
                          height: 28,
                          child: Text('SORT BY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey)),
                        ),
                        PopupMenuItem(
                          height: 38,
                          value: 'recent',
                          child: Row(
                            children: [
                              Icon(Icons.history_rounded, size: 16, color: _sortBy == 'recent' ? AppTheme.primary : Colors.grey),
                              const SizedBox(width: 8),
                              Text('Recent First', style: TextStyle(fontSize: 12.5, fontWeight: _sortBy == 'recent' ? FontWeight.bold : FontWeight.normal)),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          height: 38,
                          value: 'oldest',
                          child: Row(
                            children: [
                              Icon(Icons.schedule_rounded, size: 16, color: _sortBy == 'oldest' ? AppTheme.primary : Colors.grey),
                              const SizedBox(width: 8),
                              Text('Oldest First', style: TextStyle(fontSize: 12.5, fontWeight: _sortBy == 'oldest' ? FontWeight.bold : FontWeight.normal)),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          height: 38,
                          value: 'spend',
                          child: Row(
                            children: [
                              Icon(Icons.account_balance_wallet_rounded, size: 16, color: _sortBy == 'spend' ? AppTheme.primary : Colors.grey),
                              const SizedBox(width: 8),
                              Text('Highest Spend', style: TextStyle(fontSize: 12.5, fontWeight: _sortBy == 'spend' ? FontWeight.bold : FontWeight.normal)),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          height: 38,
                          value: 'stops',
                          child: Row(
                            children: [
                              Icon(Icons.place_rounded, size: 16, color: _sortBy == 'stops' ? AppTheme.primary : Colors.grey),
                              const SizedBox(width: 8),
                              Text('Most Stoppages', style: TextStyle(fontSize: 12.5, fontWeight: _sortBy == 'stops' ? FontWeight.bold : FontWeight.normal)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Filter Chips (Only if user has trips)
          if (trips.isNotEmpty)
            SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildPillFilter('all', '🌐 All Trips', trips.length, isDark),
                    const SizedBox(width: 6),
                    _buildPillFilter('group', '👥 Group', groupCount, isDark),
                    const SizedBox(width: 6),
                    _buildPillFilter('family', '👨‍👩‍👧 Family', familyCount, isDark),
                    const SizedBox(width: 6),
                    _buildPillFilter('solo', '🎒 Solo', soloCount, isDark),
                  ],
                ),
              ),
            ),
          ),

          // Pending Trip Invitations Banner (Actionable Accept / Decline)
          Consumer(
            builder: (context, ref, _) {
              final invitations = ref.watch(invitationProvider);
              if (invitations.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Column(
                    children: invitations.map((inv) => TripInvitationCard(invitation: inv)).toList(),
                  ),
                ),
              );
            },
          ),

          // 4. Section Title with Count (Only if user has trips)
          if (trips.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _searchQuery.isNotEmpty
                          ? 'Search Results (${filteredTrips.length})'
                          : _activeFilter == 'all'
                              ? 'Recent Expeditions (${filteredTrips.length})'
                              : '${_activeFilter[0].toUpperCase()}${_activeFilter.substring(1)} Journeys (${filteredTrips.length})',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        letterSpacing: -0.3,
                        color: isDark ? Colors.white : AppTheme.textMainLight,
                      ),
                    ),
                    if (filteredTrips.isNotEmpty)
                      Text(
                        'Showing ${visibleTrips.length} of ${filteredTrips.length}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                        ),
                      ),
                  ],
                ),
              ),
            ),

          // Empty State, Sync Loader, or Trip Cards
          if (isSyncingTrips && trips.isEmpty)
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Loading your trips...',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Syncing your latest journeys and companions from the cloud...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? Colors.grey[400] : AppTheme.textMutedLight,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (trips.isEmpty)
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withAlpha(20),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.travel_explore_rounded, size: 54, color: AppTheme.primary),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No Trips Yet',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Start tracking your journey, stoppages, routes, and shared bills with your companions.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : AppTheme.textMutedLight),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () => _openCreateTripSheet(context),
                      icon: const Icon(Icons.add_location_alt_rounded, size: 18),
                      label: const Text('Create Your First Trip'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (filteredTrips.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Container(
                alignment: const Alignment(0, -0.28),
                padding: const EdgeInsets.fromLTRB(32, 16, 32, 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withAlpha(20),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.search_off_rounded, size: 48, color: AppTheme.primary),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _searchQuery.isNotEmpty
                          ? 'No Journeys Found for "$_searchQuery"'
                          : 'No ${_activeFilter.toUpperCase()} Trips Found',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _searchQuery.isNotEmpty
                          ? 'Try searching by a different name, destination, or companion.'
                          : 'Switch categories above to see trips in other categories.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : AppTheme.textMutedLight),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index >= visibleTrips.length) {
                    // Load More Footer
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _displayedCount += 15;
                            });
                          },
                          icon: const Icon(Icons.expand_more_rounded, size: 18),
                          label: Text(
                            'Load Next 15 Trips (${filteredTrips.length - visibleTrips.length} remaining)',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                          ),
                        ),
                      ),
                    );
                  }

                  final trip = visibleTrips[index];
                  final stoppages = allStoppages.where((s) => s.tripId == trip.id).toList();
                  final expenses = allExpenses.where((e) => e.tripId == trip.id).toList();
                  final totalSpent = expenses.fold<double>(0.0, (sum, e) => sum + e.totalAmount);
                  final distanceKm = LocationService.calculateStoppagesDistanceKm(stoppages);


                  return TweenAnimationBuilder<double>(
                    key: ValueKey('trip_anim_${trip.id}'),
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    duration: Duration(milliseconds: 250 + (index * 40).clamp(0, 300)),
                    curve: Curves.easeOutCubic,
                    builder: (context, animValue, child) {
                      return Transform.translate(
                        offset: Offset(0, (1 - animValue) * 8),
                        child: Opacity(
                          opacity: animValue,
                          child: child,
                        ),
                      );
                    },
                    child: _TripCard(
                      trip: trip,
                      stoppagesCount: stoppages.length,
                      expensesCount: expenses.length,
                      totalSpent: totalSpent,
                      distanceKm: distanceKm,
                      isActiveCockpit: currentTrip?.id == trip.id,
                      onOpenCockpit: () {
                        HapticFeedback.mediumImpact();
                        ref.read(selectedTripIdProvider.notifier).state = trip.id;
                        ref.read(activeMainTabProvider.notifier).state = 1;
                      },
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _navigateToTripDetail(trip);
                      },
                      onStopsTap: () => _navigateToTripDetail(trip, initialTabIndex: 0),
                      onRouteTap: () => _navigateToTripDetail(trip, initialTabIndex: 1),
                      onMembersTap: () => _navigateToTripDetail(trip, initialTabIndex: 2),
                      onBillsTap: () => _navigateToTripDetail(trip, initialTabIndex: 3),
                      onSettleTap: trip.isSolo ? null : () => _navigateToTripDetail(trip, initialTabIndex: 4),
                    ),
                  );
                },
                childCount: visibleTrips.length + (visibleTrips.length < filteredTrips.length ? 1 : 0),
              ),
            ),

          const SliverToBoxAdapter(
            child: SizedBox(height: 80),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: MediaQuery.of(context).viewInsets.bottom > 0
          ? null
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (trips.isNotEmpty)
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0D9488).withAlpha(110),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: Colors.white.withAlpha(45), width: 1),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _openAddBillOcr(trips),
                    borderRadius: BorderRadius.circular(28),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.post_add_rounded, color: Colors.white, size: 18),
                          SizedBox(width: 6.5),
                          Text(
                            'Add Bill (OCR)',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else
              const SizedBox.shrink(),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0D9488).withAlpha(110),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: Colors.white.withAlpha(45), width: 1),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _openCreateTripSheet(context),
                  borderRadius: BorderRadius.circular(28),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_location_alt_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 6.5),
                        Text(
                          'New Trip',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            letterSpacing: -0.2,
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
    );
  }

  Future<void> _openAddBillOcr(List<Trip> trips) async {
    final activeTrips = trips.where((t) => !t.isEnded && t.status != 'concluded').toList();
    if (activeTrips.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No active trips available to add bills. Concluded trips are locked.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    Trip? selectedTrip;
    if (activeTrips.length == 1) {
      selectedTrip = activeTrips.first;
    } else {
      if (!mounted) return;
      selectedTrip = await showModalBottomSheet<Trip>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                child: Text('Select Active Trip for Bill', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const Divider(),
              ...activeTrips.map((t) => ListTile(
                leading: const Icon(Icons.explore_rounded, color: AppTheme.primary),
                title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(DateFormatter.formatTripDateRange(t.startDate, t.endDate)),
                onTap: () => Navigator.of(ctx).pop(t),
              )),
            ],
          ),
        ),
      );
    }

    if (selectedTrip == null || !mounted) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text('Scan Bill / Receipt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Text('Choose source to auto-extract details with OCR'),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: Colors.blue),
                title: const Text('Capture with Camera', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: Colors.purple),
                title: const Text('Select from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null || !mounted) return;

    final picked = await ImagePicker().pickImage(source: source);
    if (picked == null || !mounted) return;

    final ocr = await OcrService.extractFromReceipt(picked.path);
    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => AddExpenseScreen(
          tripId: selectedTrip!.id,
          prefillTitle: ocr.title,
          prefillAmount: ocr.amount,
          prefillImagePath: picked.path,
          prefillCategory: ocr.category,
          prefillDescription: ocr.description,
        ),
      ),
    );
  }



  Widget _buildPillFilter(String key, String title, int count, bool isDark) {
    final isSelected = _activeFilter == key;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isSelected
            ? AppTheme.primary
            : (isDark ? AppTheme.surfaceMutedDark : AppTheme.surfaceMutedLight),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected
              ? AppTheme.primary
              : (isDark ? AppTheme.borderDark : AppTheme.borderLight),
          width: 1.1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() {
            _activeFilter = key;
            _displayedCount = 10;
          }),
          borderRadius: BorderRadius.circular(14),
          splashColor: (isSelected ? Colors.white : AppTheme.primary).withAlpha(40),
          highlightColor: (isSelected ? Colors.white : AppTheme.primary).withAlpha(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? Colors.white : (isDark ? Colors.white : AppTheme.textMainLight),
                  ),
                ),
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white.withAlpha(40) : (isDark ? Colors.black38 : Colors.grey[300]),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : AppTheme.textMainLight),
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

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'food':
      case 'dining':
        return const Color(0xFFF59E0B);
      case 'fuel':
      case 'transport':
      case 'transportation':
        return const Color(0xFF0284C7);
      case 'stay':
      case 'hotel':
      case 'lodging':
      case 'accommodation':
        return const Color(0xFF8B5CF6);
      case 'activities':
      case 'activity':
      case 'sightseeing':
        return const Color(0xFF10B981);
      case 'shopping':
        return const Color(0xFFEC4899);
      case 'general':
      default:
        return const Color(0xFF0D9488);
    }
  }
}

class _TripCard extends StatelessWidget {
  final Trip trip;
  final int stoppagesCount;
  final int expensesCount;
  final double totalSpent;
  final double distanceKm;
  final bool isActiveCockpit;
  final VoidCallback onOpenCockpit;
  final VoidCallback onTap;
  final VoidCallback onBillsTap;
  final VoidCallback onStopsTap;
  final VoidCallback onRouteTap;
  final VoidCallback? onSettleTap;
  final VoidCallback onMembersTap;

  const _TripCard({
    required this.trip,
    required this.stoppagesCount,
    required this.expensesCount,
    required this.totalSpent,
    this.distanceKm = 0.0,
    this.isActiveCockpit = false,
    required this.onOpenCockpit,
    required this.onTap,
    required this.onBillsTap,
    required this.onStopsTap,
    required this.onRouteTap,
    this.onSettleTap,
    required this.onMembersTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final roomCode = CloudTripSyncService.getRoomCode(trip.id, trip: trip);

    Color modeColor;
    String modeLabel;
    IconData modeIcon;

    if (trip.isSolo) {
      modeColor = const Color(0xFF2563EB); // Blue
      modeLabel = 'Solo Log';
      modeIcon = Icons.person_rounded;
    } else if (trip.isFamily) {
      modeColor = const Color(0xFFD97706); // Amber
      modeLabel = 'Family Pool';
      modeIcon = Icons.family_restroom_rounded;
    } else {
      modeColor = AppTheme.primary; // Teal
      modeLabel = 'Group Split';
      modeIcon = Icons.group_rounded;
    }

    final isEnded = trip.isEnded;
    final isRunning = trip.isRunning;

    final Color cardBackground;
    final Color borderColor;
    final double borderWidth;
    final double elevation;

    if (isEnded) {
      if (isActiveCockpit) {
        cardBackground = isDark ? const Color(0xFF181C24) : const Color(0xFFF8FAFC);
        borderColor = isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706);
        borderWidth = 2.0;
        elevation = isDark ? 1.0 : 2.5;
      } else {
        cardBackground = isDark ? const Color(0xFF141923) : const Color(0xFFF8FAFC);
        borderColor = isDark ? const Color(0xFFF59E0B).withAlpha(210) : const Color(0xFFD97706).withAlpha(190);
        borderWidth = 1.6;
        elevation = 0;
      }
    } else if (isActiveCockpit) {
      cardBackground = isDark ? const Color(0xFF0C2424) : const Color(0xFFF0FDF9);
      borderColor = isDark ? const Color(0xFF14B8A6) : const Color(0xFF0D9488);
      borderWidth = 1.8;
      elevation = isDark ? 1.0 : 3.0;
    } else if (isRunning) {
      cardBackground = isDark ? const Color(0xFF0F1E24) : const Color(0xFFF0FDF4);
      borderColor = isDark ? const Color(0xFF10B981).withAlpha(170) : const Color(0xFF059669).withAlpha(150);
      borderWidth = 1.4;
      elevation = isDark ? 0 : 2.0;
    } else {
      cardBackground = isDark ? const Color(0xFF161E2E) : Colors.white;
      borderColor = isDark ? const Color(0xFF334155).withAlpha(120) : const Color(0xFFE2E8F0);
      borderWidth = 1.0;
      elevation = 0;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: cardBackground,
        elevation: elevation,
        shadowColor: isEnded
            ? (isDark ? const Color(0xFFF59E0B).withAlpha(35) : const Color(0xFFD97706).withAlpha(35))
            : (isActiveCockpit
                ? const Color(0xFF0D9488).withAlpha(isDark ? 60 : 40)
                : (isRunning
                    ? const Color(0xFF10B981).withAlpha(isDark ? 35 : 25)
                    : Colors.black.withAlpha(isDark ? 45 : 18))),
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: borderColor,
              width: borderWidth,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Section (Header, Title, Dates, Details) wrapped in InkWell to open details
                InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(12),
                  splashColor: AppTheme.primary.withAlpha(22),
                  highlightColor: AppTheme.primary.withAlpha(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Mode Tag, Status Badges & Total Expense Pill
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 5,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                // Trip Mode Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: modeColor.withAlpha(20),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: modeColor.withAlpha(50)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(modeIcon, size: 11, color: modeColor),
                                      const SizedBox(width: 3.5),
                                      Text(
                                        modeLabel,
                                        style: TextStyle(
                                          color: modeColor,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Live Active Badge
                                if (isActiveCockpit)
                                  const PulsingLiveBeacon(
                                    label: 'LIVE',
                                    color: Color(0xFF0D9488),
                                    dotSize: 7,
                                    labelStyle: TextStyle(
                                      color: Color(0xFF0D9488),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.3,
                                    ),
                                  )
                                else if (!isEnded)
                                  PulsingLiveBeacon(
                                    label: isRunning ? 'LIVE TRIP' : 'ACTIVE',
                                    color: const Color(0xFF10B981),
                                    dotSize: 6,
                                    labelStyle: const TextStyle(
                                      color: Color(0xFF10B981),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.3,
                                    ),
                                  ),

                                // Concluded Trip Badge
                                if (isEnded)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD97706).withAlpha(isDark ? 40 : 25),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFD97706).withAlpha(isDark ? 100 : 70)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.flag_rounded, size: 10.5, color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706)),
                                        const SizedBox(width: 3),
                                        Text(
                                          'CONCLUDED',
                                          style: TextStyle(
                                            color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                // Star Rating Badge
                                if (trip.rating != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withAlpha(isDark ? 35 : 22),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.amber.withAlpha(isDark ? 90 : 60)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.star_rounded, size: 11, color: Colors.amber),
                                        const SizedBox(width: 2.5),
                                        Text(
                                          trip.rating!.toStringAsFixed(1),
                                          style: TextStyle(
                                            color: isDark ? Colors.amber[300] : Colors.amber[900],
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                // Room Code Chip
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.black26 : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: isDark ? AppTheme.borderDark : const Color(0xFFCBD5E1)),
                                  ),
                                  child: Text(
                                    roomCode,
                                    style: TextStyle(
                                      color: isDark ? Colors.grey[400] : const Color(0xFF475569),
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Total Expense Pill in Top Header
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                onBillsTap();
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                                decoration: BoxDecoration(
                                  color: AppTheme.secondary.withAlpha(isDark ? 30 : 18),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppTheme.secondary.withAlpha(isDark ? 80 : 55),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.account_balance_wallet_outlined,
                                      size: 12.5,
                                      color: AppTheme.secondary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      CurrencyFormatter.format(totalSpent, currency: trip.defaultCurrency),
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.3,
                                        color: isDark ? Colors.white : AppTheme.textMainLight,
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      size: 14,
                                      color: isDark ? Colors.grey[300] : const Color(0xFF64748B),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Title & Date Range
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  trip.title,
                                  style: TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                    color: isDark ? Colors.white : AppTheme.textMainLight,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today_rounded, size: 12, color: AppTheme.primary),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        DateFormatter.formatTripDateRange(trip.startDate, trip.endDate),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? Colors.grey[300] : const Color(0xFF475569),
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (trip.members.isNotEmpty && !trip.isSolo) ...[
                                      const Text(' • ', style: TextStyle(color: Colors.grey)),
                                      Material(
                                        color: Colors.transparent,
                                        child: Ink(
                                          decoration: BoxDecoration(
                                            color: AppTheme.primary.withAlpha(16),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: AppTheme.primary.withAlpha(45), width: 0.9),
                                          ),
                                          child: InkWell(
                                            onTap: onMembersTap,
                                            borderRadius: BorderRadius.circular(8),
                                            splashColor: AppTheme.primary.withAlpha(30),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  _buildAvatarStack(trip.members, isDark),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '${trip.members.length}',
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: AppTheme.primary,
                                                      fontWeight: FontWeight.w800,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 2),
                                                  const Icon(Icons.chevron_right_rounded, size: 12, color: AppTheme.primary),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Subtle chevron affordance
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withAlpha(12) : const Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark ? AppTheme.borderDark : const Color(0xFFCBD5E1),
                                width: 0.9,
                              ),
                            ),
                            child: Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                              color: isDark ? Colors.grey[300] : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Key Metrics Summary Chips
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _buildMetricChip(
                            icon: Icons.place_rounded,
                            label: '$stoppagesCount ${stoppagesCount == 1 ? "Stop" : "Stops"}',
                            color: AppTheme.primary,
                            isDark: isDark,
                          ),
                          if (distanceKm > 0.05)
                            _buildMetricChip(
                              icon: Icons.route_rounded,
                              label: '${distanceKm.toStringAsFixed(1)} km',
                              color: const Color(0xFF0F766E),
                              isDark: isDark,
                            ),
                          _buildMetricChip(
                            icon: Icons.receipt_long_rounded,
                            label: '$expensesCount ${expensesCount == 1 ? "Bill" : "Bills"}',
                            color: AppTheme.secondary,
                            isDark: isDark,
                          ),
                        ],
                      ),

                      // Budget Progress Bar (if budget is configured)
                      if (trip.budget != null && trip.budget! > 0) ...[
                        const SizedBox(height: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Budget: ${CurrencyFormatter.format(totalSpent, currency: trip.defaultCurrency)} / ${CurrencyFormatter.format(trip.budget!, currency: trip.defaultCurrency)}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                  ),
                                ),
                                Text(
                                  '${(totalSpent / trip.budget! * 100).clamp(0, 999).toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: (totalSpent > trip.budget!)
                                        ? Colors.redAccent
                                        : (isDark ? Colors.tealAccent : AppTheme.primary),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: (totalSpent / trip.budget!).clamp(0.0, 1.0),
                                minHeight: 4,
                                backgroundColor: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                                color: (totalSpent > trip.budget!)
                                    ? Colors.redAccent
                                    : (isDark ? const Color(0xFF2DD4BF) : AppTheme.primary),
                              ),
                            ),
                          ],
                        ),
                      ],

                      if (trip.description != null && trip.description!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          trip.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? Colors.grey[400] : AppTheme.textMutedLight,
                            height: 1.25,
                          ),
                        ),
                      ],

                      if (trip.experienceReview != null && trip.experienceReview!.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber.withAlpha(isDark ? 25 : 15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber.withAlpha(40)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.rate_review_rounded, size: 12, color: Colors.amber),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  '"${trip.experienceReview!}"',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic,
                                    color: isDark ? Colors.amber[200] : const Color(0xFFB45309),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Separator
                Divider(
                  height: 1,
                  thickness: 0.8,
                  color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0),
                ),
                const SizedBox(height: 9),

                // Launchpad Action Bar: Primary Cockpit Launcher + Quick Utility Shortcuts
                Row(
                  children: [
                    // Primary Hero Action: Launch Cockpit
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onOpenCockpit,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8.5),
                            decoration: BoxDecoration(
                              gradient: isActiveCockpit
                                  ? const LinearGradient(
                                      colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : LinearGradient(
                                      colors: isDark
                                          ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                                          : [const Color(0xFFF1F5F9), const Color(0xFFE2E8F0)],
                                    ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isActiveCockpit
                                    ? const Color(0xFF14B8A6)
                                    : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                width: isActiveCockpit ? 1.2 : 0.9,
                              ),
                              boxShadow: isActiveCockpit
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF0D9488).withAlpha(80),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isActiveCockpit ? Icons.card_travel_rounded : Icons.explore_rounded,
                                  size: 15,
                                  color: isActiveCockpit
                                      ? Colors.white
                                      : (isDark ? Colors.tealAccent : const Color(0xFF0D9488)),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    isActiveCockpit ? 'Active Live' : (isRunning ? 'Launch Live' : 'Open Live'),
                                    style: TextStyle(
                                      color: isActiveCockpit
                                          ? Colors.white
                                          : (isDark ? Colors.white : AppTheme.textMainLight),
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 13,
                                  color: isActiveCockpit
                                      ? Colors.white70
                                      : (isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Quick Utility 1: Route Map
                    _buildActionIconButton(
                      icon: Icons.map_rounded,
                      color: const Color(0xFF0F766E),
                      tooltip: distanceKm > 0.05 ? 'Route Map (${distanceKm.toStringAsFixed(1)} km)' : 'Route Map',
                      onTap: onRouteTap,
                      isDark: isDark,
                    ),
                    const SizedBox(width: 6),

                    // Quick Utility 2: Stoppages
                    _buildActionIconButton(
                      icon: Icons.place_rounded,
                      color: AppTheme.primary,
                      tooltip: 'Stoppages ($stoppagesCount)',
                      badgeCount: stoppagesCount,
                      onTap: onStopsTap,
                      isDark: isDark,
                    ),

                    // Quick Utility 3: Settle Balances (if group/family)
                    if (onSettleTap != null) ...[
                      const SizedBox(width: 6),
                      _buildActionIconButton(
                        icon: Icons.account_balance_wallet_rounded,
                        color: const Color(0xFFD97706),
                        tooltip: 'Settle Balances',
                        onTap: onSettleTap,
                        isDark: isDark,
                      ),
                    ],

                    const SizedBox(width: 6),

                    // Quick Utility 4: Full Trip Management / Details
                    _buildActionIconButton(
                      icon: Icons.tune_rounded,
                      color: isDark ? Colors.grey[300]! : const Color(0xFF475569),
                      tooltip: 'Trip Management & Tabs',
                      onTap: onTap,
                      isDark: isDark,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildAvatarStack(List<TripMember> members, bool isDark) {
    if (members.isEmpty) return const SizedBox.shrink();
    final displayed = members.take(3).toList();
    final remaining = members.length - displayed.length;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < displayed.length; i++)
          Align(
            widthFactor: 0.72,
            child: UserAvatar(
              name: displayed[i].name,
              colorHex: displayed[i].colorHex,
              size: 20,
              fontSize: 9,
              border: Border.all(
                color: isDark ? const Color(0xFF161E2E) : Colors.white,
                width: 1.4,
              ),
            ),
          ),
        if (remaining > 0)
          Align(
            widthFactor: 0.72,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? const Color(0xFF161E2E) : Colors.white,
                  width: 1.4,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '+$remaining',
                style: TextStyle(
                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }

  static Widget _buildMetricChip({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(isDark ? 28 : 16),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(isDark ? 70 : 40), width: 0.9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3.5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.grey[200] : const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildActionIconButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback? onTap,
    int? badgeCount,
    required bool isDark,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withAlpha(isDark ? 28 : 16),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap != null
              ? () {
                  HapticFeedback.lightImpact();
                  onTap();
                }
              : null,
          borderRadius: BorderRadius.circular(10),
          splashColor: color.withAlpha(40),
          highlightColor: color.withAlpha(25),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7.5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: color.withAlpha(isDark ? 70 : 45),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: color),
                if (badgeCount != null && badgeCount > 0) ...[
                  const SizedBox(width: 4),
                  Text(
                    '$badgeCount',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
