import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/cloud_trip_sync_service.dart';
import '../../core/services/location_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/trip.dart';
import '../../providers/expense_provider.dart';
import '../../providers/memory_provider.dart';
import '../../providers/settlement_provider.dart';
import '../../providers/stoppage_provider.dart';
import '../../providers/trip_provider.dart';
import 'create_trip_sheet.dart';
import 'join_trip_sheet.dart';
import '../common/sync_status_badge.dart';
import '../common/sos_badge_icon.dart';
import '../notifications/notification_center_sheet.dart';
import '../../providers/invitation_provider.dart';
import 'widgets/trip_invitation_card.dart';
import '../main_scaffold.dart';

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
  int _displayedCount = 10;
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
          _displayedCount += 10;
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

    // Senior Dev Unified Cockpit Architecture (Req 8):
    // Directly activate the trip and smoothly switch to the Current Trip Cockpit (Tab 1)
    ref.read(selectedTripIdProvider.notifier).state = trip.id;
    ref.read(activeMainTabProvider.notifier).state = 1;
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
    final userStoppages = allStoppages.where((s) => userTripIds.contains(s.tripId)).toList();

    final groupCount = trips.where((t) => !t.isSolo && !t.isFamily).length;
    final familyCount = trips.where((t) => t.isFamily).length;
    final soloCount = trips.where((t) => t.isSolo).length;

    final grandTotalSpent = userExpenses.fold<double>(0.0, (sum, e) => sum + e.totalAmount);
    final detectedCurr = ref.watch(currencyNotifierProvider).value;
    final defaultCurr = detectedCurr.isNotEmpty
        ? detectedCurr
        : (trips.isNotEmpty ? trips.first.defaultCurrency : LocationService.currentDetectedCurrency);

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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildHeroStat(
                          icon: Icons.map_rounded,
                          value: '${trips.length}',
                          label: 'Trips',
                        ),
                        Container(height: 28, width: 1, color: Colors.white24),
                        _buildHeroStat(
                          icon: Icons.place_rounded,
                          value: '${userStoppages.length}',
                          label: 'Stoppages',
                          onTap: trips.isNotEmpty
                              ? () {
                                  HapticFeedback.lightImpact();
                                  ref.read(activeMainTabProvider.notifier).state = 1;
                                }
                              : null,
                        ),
                        Container(height: 28, width: 1, color: Colors.white24),
                        _buildHeroStat(
                          icon: Icons.account_balance_wallet_rounded,
                          value: CurrencyFormatter.format(grandTotalSpent, currency: defaultCurr),
                          label: 'Total Spent',
                          onTap: () {
                            HapticFeedback.lightImpact();
                            ref.read(activeMainTabProvider.notifier).state = 3;
                          },
                        ),
                      ],
                    ),
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
                            _displayedCount = 10;
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
                                      _displayedCount = 10;
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
                              _displayedCount += 10;
                            });
                          },
                          icon: const Icon(Icons.expand_more_rounded, size: 18),
                          label: Text(
                            'Load Next 10 Trips (${filteredTrips.length - visibleTrips.length} remaining)',
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
                      onTap: () => _navigateToTripDetail(trip, initialTabIndex: 0),
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
      floatingActionButton: Container(
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
    );
  }

  Widget _buildHeroStat({required IconData icon, required String value, required String label, VoidCallback? onTap}) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 16),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 3),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white70,
                size: 9,
              ),
            ],
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 2),
              const Icon(
                Icons.touch_app_rounded,
                color: Colors.white60,
                size: 9,
              ),
            ],
          ],
        ),
      ],
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: content,
        ),
      );
    }
    return content;
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
}

class _TripCard extends StatelessWidget {
  final Trip trip;
  final int stoppagesCount;
  final int expensesCount;
  final double totalSpent;
  final double distanceKm;
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

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Material(
        color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
        elevation: isDark ? 0 : 2,
        shadowColor: Colors.black.withAlpha(isDark ? 45 : 18),
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? AppTheme.borderDark : AppTheme.borderLight,
              width: 1.1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Section (Header, Title, Dates, Description) wrapped in InkWell to open details
                InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(12),
                  splashColor: AppTheme.primary.withAlpha(22),
                  highlightColor: AppTheme.primary.withAlpha(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Mode Tag, Sync Code & Right Arrow (replacing 3 dots)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
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

                                // Persistent Trip Ended Badge
                                if (trip.isCompleted)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF64748B).withAlpha(isDark ? 40 : 25),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFF64748B).withAlpha(isDark ? 90 : 60)),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.flag_rounded, size: 10.5, color: Color(0xFF64748B)),
                                        SizedBox(width: 3),
                                        Text(
                                          'ENDED',
                                          style: TextStyle(
                                            color: Color(0xFF64748B),
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                // Distinct Rating Badge (Never replaces ENDED badge)
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

                                // Trip ID / Share Room Code Badge
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

                          // Interactive Clickable Total Spend in Top Header
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                onBillsTap();
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
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
                                    const SizedBox(width: 3.5),
                                    Text(
                                      CurrencyFormatter.format(totalSpent, currency: trip.defaultCurrency),
                                      style: TextStyle(
                                        fontSize: 13,
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
                      const SizedBox(height: 8),

                      // Middle Section: Trip Details on Left, Tactile > Chevron on Middle-Rightmost
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Title
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
                                const SizedBox(height: 3.5),

                                // Dates & Companions count
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
                                            color: AppTheme.primary.withAlpha(18),
                                            borderRadius: BorderRadius.circular(7),
                                            border: Border.all(color: AppTheme.primary.withAlpha(50), width: 0.9),
                                          ),
                                          child: InkWell(
                                            onTap: onMembersTap,
                                            borderRadius: BorderRadius.circular(7),
                                            splashColor: AppTheme.primary.withAlpha(30),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.people_outline_rounded, size: 12, color: AppTheme.primary),
                                                  const SizedBox(width: 3.5),
                                                  Text(
                                                    '${trip.members.length} members',
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: AppTheme.primary,
                                                      fontWeight: FontWeight.w800,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 2.5),
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
                          const SizedBox(width: 10),
                          // Middle-Rightmost > Chevron
                          Container(
                            padding: const EdgeInsets.all(5.5),
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
                              size: 17,
                              color: isDark ? Colors.grey[300] : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Thin border above all 4 subbuttons on the card
                Divider(
                  height: 1,
                  thickness: 0.8,
                  color: isDark ? AppTheme.borderDark : const Color(0xFFE2E8F0),
                ),
                const SizedBox(height: 9),

                // Card Footer: Compact, Tactile Action Pills with Instant Touch Feedback
                Row(
                  children: [
                    // Route Map Pill Button
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: Ink(
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F766E).withAlpha(isDark ? 28 : 18),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                              color: const Color(0xFF0F766E).withAlpha(isDark ? 80 : 55),
                              width: 1.1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0F766E).withAlpha(isDark ? 16 : 8),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: InkWell(
                            onTap: onRouteTap,
                            borderRadius: BorderRadius.circular(9),
                            splashColor: const Color(0xFF0F766E).withAlpha(35),
                            highlightColor: const Color(0xFF0F766E).withAlpha(20),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.map_rounded, size: 12.5, color: Color(0xFF0F766E)),
                                  const SizedBox(width: 3.5),
                                  Flexible(
                                    child: Text(
                                      distanceKm > 0.05
                                          ? '${distanceKm.toStringAsFixed(1)} km'
                                          : 'Route',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFF0F766E),
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),

                    // Stops / Timeline Pill Button
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: Ink(
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withAlpha(isDark ? 28 : 18),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                              color: AppTheme.primary.withAlpha(isDark ? 80 : 55),
                              width: 1.1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary.withAlpha(isDark ? 16 : 8),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: InkWell(
                            onTap: onStopsTap,
                            borderRadius: BorderRadius.circular(9),
                            splashColor: AppTheme.primary.withAlpha(35),
                            highlightColor: AppTheme.primary.withAlpha(20),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.place_rounded, size: 12.5, color: AppTheme.primary),
                                  const SizedBox(width: 3.5),
                                  Flexible(
                                    child: Text(
                                      '$stoppagesCount ${stoppagesCount == 1 ? "Stop" : "Stops"}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppTheme.primary,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),

                    // Bills & Splits Pill Button
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: Ink(
                          decoration: BoxDecoration(
                            color: AppTheme.secondary.withAlpha(isDark ? 28 : 18),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                              color: AppTheme.secondary.withAlpha(isDark ? 80 : 55),
                              width: 1.1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.secondary.withAlpha(isDark ? 16 : 8),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: InkWell(
                            onTap: onBillsTap,
                            borderRadius: BorderRadius.circular(9),
                            splashColor: AppTheme.secondary.withAlpha(35),
                            highlightColor: AppTheme.secondary.withAlpha(20),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.receipt_rounded, size: 12.5, color: AppTheme.secondary),
                                  const SizedBox(width: 3.5),
                                  Flexible(
                                    child: Text(
                                      '$expensesCount ${expensesCount == 1 ? "Bill" : "Bills"}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppTheme.secondary,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Settle Balances Pill Button (Group & Family mode)
                    if (onSettleTap != null) ...[
                      const SizedBox(width: 5),
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: Ink(
                            decoration: BoxDecoration(
                              color: const Color(0xFFD97706).withAlpha(isDark ? 28 : 18),
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(
                                color: const Color(0xFFD97706).withAlpha(isDark ? 80 : 55),
                                width: 1.1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFD97706).withAlpha(isDark ? 16 : 8),
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: InkWell(
                              onTap: onSettleTap,
                              borderRadius: BorderRadius.circular(9),
                              splashColor: const Color(0xFFD97706).withAlpha(35),
                              highlightColor: const Color(0xFFD97706).withAlpha(20),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 7, horizontal: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.account_balance_rounded, size: 12.5, color: Color(0xFFD97706)),
                                    SizedBox(width: 3.5),
                                    Flexible(
                                      child: Text(
                                        'Settle',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Color(0xFFD97706),
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
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
        ),
      ),
    );
  }
}
