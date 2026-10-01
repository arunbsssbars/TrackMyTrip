import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../../models/proximity_alert.dart';
import '../../models/stoppage.dart';
import '../../models/trip_member.dart';
import 'local_storage_service.dart';
import 'realtime_sync_service.dart';
import 'firestore_sync_service.dart';
import 'user_service.dart';
import '../../providers/trip_provider.dart';
import '../../providers/stoppage_provider.dart';

class ProximityAlertService extends ChangeNotifier {
  final LocalStorageService _storage;
  final Ref _ref;

  List<ProximityAlert> _alerts = [];
  double _strayThresholdMeters = 1500.0; // Default 1.5 km
  final double _stoppageArrivalRadiusMeters = 350.0; // Default 350 m
  bool _strayAlertsEnabled = true;
  bool _stoppageAlertsEnabled = true;
  bool _inAppBannersEnabled = true;

  // Debounce duplicate alerts (key -> last time triggered)
  final Map<String, DateTime> _debounceTimestamps = {};

  // Debounce duplicate banner emissions within short window (key -> last shown)
  final Map<String, DateTime> _recentlyEmittedBanners = {};

  // Broadcast stream for in-app floating notification banners
  final StreamController<ProximityAlert> _bannerController = StreamController<ProximityAlert>.broadcast();

  final DateTime _sessionStartTime = DateTime.now();

  ProximityAlertService(this._storage, this._ref) {
    _loadAlerts();
  }

  List<ProximityAlert> get alerts => List.unmodifiable(_alerts);
  int get unreadCount => getRelevantAlerts().where((a) => !a.isRead).length;
  double get strayThresholdMeters => _strayThresholdMeters;
  double get stoppageArrivalRadiusMeters => _stoppageArrivalRadiusMeters;
  bool get strayAlertsEnabled => _strayAlertsEnabled;
  bool get stoppageAlertsEnabled => _stoppageAlertsEnabled;
  bool get inAppBannersEnabled => _inAppBannersEnabled;
  Stream<ProximityAlert> get bannerStream => _bannerController.stream;

  void _loadAlerts() {
    final raw = _storage.getAllAlerts();
    final seen = <String>{};
    final seenSemantic = <String>{};
    _alerts = raw.where((a) {
      if (!seen.add(a.id)) return false;
      if (a.type == AlertType.settlementRecorded) {
        final key = '${a.tripId}_${a.senderMemberId}_${a.message}';
        if (!seenSemantic.add(key)) return false;
      }
      return true;
    }).toList();
    _inAppBannersEnabled = _storage.getInAppBannersEnabled();
    _syncAlertsFromTrips();
    notifyListeners();
  }

  void reload() {
    _loadAlerts();
  }

  void _syncAlertsFromTrips() {
    final trips = _storage.getTrips();
    final allExpenses = _storage.getAllExpenses();
    final allSettlements = _storage.getAllSettlements();
    final allStoppages = _storage.getAllStoppages();
    final existingAlertIds = _alerts.map((a) => a.id).toSet();
    final clearedAt = _storage.getAlertsClearedAt();
    final newAlerts = <ProximityAlert>[];

    for (final trip in trips) {
      final creator = trip.currentUserMember ?? (trip.members.isNotEmpty ? trip.members.first : null);
      final creatorId = creator?.id ?? 'usr_me';
      final creatorName = creator?.name ?? 'Trip Leader';

      // Budget Notification
      final budgetAlertId = 'alert_budget_${trip.id}';
      if (trip.budget != null && trip.budget! > 0 && 
          !existingAlertIds.contains(budgetAlertId) &&
          !_storage.isAlertDismissed(budgetAlertId) &&
          (clearedAt == null || !trip.startDate.isBefore(clearedAt))) {
        newAlerts.add(ProximityAlert(
          id: budgetAlertId,
          tripId: trip.id,
          type: AlertType.general,
          title: 'Budget Target Set',
          message: 'Allocated budget cap of ${trip.defaultCurrency} ${trip.budget!.toStringAsFixed(0)} set for "${trip.title}".',
          senderMemberId: creatorId,
          senderName: creatorName,
          timestamp: trip.startDate,
          isRead: true,
          urgency: AlertUrgency.normal,
        ));
      }

      // 3. Stoppages
      for (final s in allStoppages.where((stop) => stop.tripId == trip.id)) {
        final stopAlertId = 'alert_stop_${s.id}';
        final alreadyLogged = existingAlertIds.contains(stopAlertId) ||
            existingAlertIds.contains('act_stop_${s.id}') ||
            _alerts.any((a) =>
                a.id == stopAlertId ||
                a.id == 'act_stop_${s.id}' ||
                (a.tripId == trip.id && (a.itemId == s.id || a.id.contains(s.id))));
        if (!alreadyLogged &&
            !_storage.isAlertDismissed(stopAlertId) &&
            !_storage.isAlertDismissed('act_stop_${s.id}') &&
            (clearedAt == null || !s.arrivedAt.isBefore(clearedAt))) {
          final authorName = s.createdByName ??
              (s.createdBy.isNotEmpty ? trip.getMemberName(s.createdBy) : creatorName);
          newAlerts.add(ProximityAlert(
            id: stopAlertId,
            tripId: trip.id,
            type: AlertType.stoppageAdded,
            title: 'Stop Added',
            message: '$authorName added stop "${s.name}".',
            senderMemberId: s.createdBy.isNotEmpty ? s.createdBy : creatorId,
            senderName: authorName,
            timestamp: s.arrivedAt,
            isRead: true,
            urgency: AlertUrgency.normal,
            itemId: s.id,
            itemType: 'stop',
          ));
        }
      }

      // 4. Expenses (exclude personal expenses, deduplicate, and respect dismissal/clear tombstones)
      for (final e in allExpenses.where((exp) => exp.tripId == trip.id)) {
        if (e.isPersonal) continue;
        final expAlertId = 'alert_exp_${e.id}';
        final alreadyLogged = existingAlertIds.contains(expAlertId) ||
            _alerts.any((a) => a.id == expAlertId || (a.tripId == trip.id && a.type == AlertType.billAdded && a.id.contains(e.id)));
        if (!alreadyLogged &&
            !_storage.isAlertDismissed(expAlertId) &&
            (clearedAt == null || !e.createdAt.isBefore(clearedAt))) {
          final payerName = trip.getMemberName(e.paidByMemberId);
          newAlerts.add(ProximityAlert(
            id: expAlertId,
            tripId: trip.id,
            type: AlertType.billAdded,
            title: 'Bill Added',
            message: '${payerName.isNotEmpty && payerName != "Unknown Member" ? payerName : creatorName} logged "${e.title}" (${e.currency} ${e.totalAmount.toStringAsFixed(0)})',
            senderMemberId: e.paidByMemberId,
            senderName: payerName.isNotEmpty && payerName != 'Unknown Member' ? payerName : creatorName,
            timestamp: e.createdAt,
            isRead: true,
            urgency: AlertUrgency.normal,
            itemId: e.id,
            itemType: 'bill',
            amount: e.totalAmount,
            currency: e.currency,
          ));
        }
      }

      // 5. Settlements
      for (final s in allSettlements.where((settle) => settle.tripId == trip.id)) {
        final alertId = 'alert_settle_${s.id}';
        final alreadyLogged = existingAlertIds.contains(alertId) ||
            _alerts.any((a) => a.tripId == trip.id && a.type == AlertType.settlementRecorded && (a.id == alertId || a.id.contains(s.id)));
        if (!alreadyLogged &&
            !_storage.isAlertDismissed(alertId) &&
            (clearedAt == null || !s.settledAt.isBefore(clearedAt))) {
          final payerName = trip.getMemberName(s.payerMemberId);
          final payeeName = trip.getMemberName(s.receiverMemberId);
          final isAdv = s.isAdvance;
          newAlerts.add(ProximityAlert(
            id: alertId,
            tripId: trip.id,
            type: AlertType.settlementRecorded,
            title: isAdv ? 'Advance Payment Recorded' : 'Settlement Recorded',
            message: isAdv
                ? '$payerName paid $payeeName an advance of ${s.currency} ${s.amount.toStringAsFixed(0)}'
                : '$payerName paid $payeeName (${s.currency} ${s.amount.toStringAsFixed(0)})',
            senderMemberId: s.payerMemberId,
            senderName: payerName,
            timestamp: s.settledAt,
            isRead: true,
            urgency: AlertUrgency.normal,
            itemId: s.id,
            itemType: 'settlement',
            amount: s.amount,
            currency: s.currency,
          ));
        }
      }
    }

    if (newAlerts.isNotEmpty) {
      final combined = [..._alerts, ...newAlerts];
      final seen = <String>{};
      _alerts = combined.where((a) => seen.add(a.id)).toList();
      _alerts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      _storage.saveAllAlerts(_alerts);
    }
  }

  void toggleInAppBanners(bool enabled) {
    _inAppBannersEnabled = enabled;
    _storage.setInAppBannersEnabled(enabled);
    notifyListeners();
  }

  void setStrayThreshold(double meters) {
    _strayThresholdMeters = meters;
    notifyListeners();
  }

  void toggleStrayAlerts(bool enabled) {
    _strayAlertsEnabled = enabled;
    notifyListeners();
  }

  void toggleStoppageAlerts(bool enabled) {
    _stoppageAlertsEnabled = enabled;
    notifyListeners();
  }

  /// Calculates distances to all companions and triggers separation alerts if exceeding threshold
  void evaluateCompanionProximities({
    required String tripId,
    required double myLat,
    required double myLng,
    required List<TripMember> companions,
    required String myName,
  }) {
    if (!_strayAlertsEnabled) return;
    final trip = _storage.getTrips().where((t) => t.id == tripId).firstOrNull;
    if (trip != null && trip.isEnded) return;

    for (final companion in companions) {
      if (companion.isCurrentUser || companion.latitude == null || companion.longitude == null) {
        continue;
      }

      final distance = Geolocator.distanceBetween(
        myLat,
        myLng,
        companion.latitude!,
        companion.longitude!,
      );

      if (distance > _strayThresholdMeters) {
        final debounceKey = 'stray_${companion.id}';
        final lastSent = _debounceTimestamps[debounceKey];
        if (lastSent == null || DateTime.now().difference(lastSent).inMinutes >= 10) {
          _debounceTimestamps[debounceKey] = DateTime.now();

          final km = (distance / 1000).toStringAsFixed(1);
          final alert = ProximityAlert(
            id: 'alert_${const Uuid().v4().substring(0, 8)}',
            tripId: tripId,
            type: AlertType.companionStray,
            title: 'Companion Separation Alert',
            message: '${companion.name} is $km km away from your position.',
            senderMemberId: companion.id,
            senderName: companion.name,
            latitude: companion.latitude,
            longitude: companion.longitude,
            distanceMeters: distance,
            timestamp: DateTime.now(),
            urgency: AlertUrgency.high,
          );

          _recordAndBroadcastAlert(alert);
        }
      }
    }
  }

  /// Seeds debounce for a stoppage that was just manually added at current location,
  /// preventing an immediate duplicate "Arrived at Stop" alert.
  void seedStoppageArrivalDebounce({
    required String tripId,
    required String stoppageId,
  }) {
    _debounceTimestamps['arrival_${tripId}_$stoppageId'] = DateTime.now();
  }

  /// Evaluates distance to upcoming pitstops and triggers arrival alerts
  void evaluateStoppageArrivals({
    required String tripId,
    required double myLat,
    required double myLng,
    required List<Stoppage> activeStoppages,
    required String myMemberId,
    required String myName,
  }) {
    if (!_stoppageAlertsEnabled) return;
    final trip = _storage.getTrips().where((t) => t.id == tripId).firstOrNull;
    if (trip != null && trip.isEnded) return;

    for (final stop in activeStoppages) {
      final distance = Geolocator.distanceBetween(
        myLat,
        myLng,
        stop.latitude,
        stop.longitude,
      );

      if (distance <= _stoppageArrivalRadiusMeters) {
        final alertId = 'arrival_${tripId}_${stop.id}';
        if (_alerts.any((a) => a.id == alertId)) continue;

        final debounceKey = 'arrival_${tripId}_${stop.id}';
        final lastSent = _debounceTimestamps[debounceKey];
        if (lastSent == null || DateTime.now().difference(lastSent).inHours >= 12) {
          _debounceTimestamps[debounceKey] = DateTime.now();

          final alert = ProximityAlert(
            id: alertId,
            tripId: tripId,
            type: AlertType.stoppageArrival,
            title: 'Arrived at Stop',
            message: '$myName has arrived at ${stop.name}.',
            senderMemberId: myMemberId,
            senderName: myName,
            latitude: myLat,
            longitude: myLng,
            distanceMeters: distance,
            timestamp: DateTime.now(),
            urgency: AlertUrgency.normal,
          );

          _recordAndBroadcastAlert(alert);
        }
      }
    }
  }

  /// Evaluates and notifies companions if a member's battery falls <= 15% and not charging
  void evaluateBatteryWarning({
    required String tripId,
    required String memberId,
    required String memberName,
    required int batteryLevel,
  }) {
    final debounceKey = 'battery_${tripId}_$memberId';
    final lastSent = _debounceTimestamps[debounceKey];
    if (lastSent == null || DateTime.now().difference(lastSent).inMinutes >= 30) {
      _debounceTimestamps[debounceKey] = DateTime.now();

      final alert = ProximityAlert(
        id: 'battery_${memberId}_${DateTime.now().millisecondsSinceEpoch}',
        tripId: tripId,
        type: AlertType.general,
        title: '⚠️ Low Battery Warning',
        message: "$memberName's battery is at $batteryLevel%. They may lose connection soon.",
        senderMemberId: memberId,
        senderName: memberName,
        timestamp: DateTime.now(),
        urgency: AlertUrgency.high,
      );

      _recordAndBroadcastAlert(alert);
    }
  }

  /// Sends a critical SOS Emergency broadcast to all companions with live GPS
  Future<void> triggerEmergencySos({
    required String tripId,
    required String memberId,
    required String memberName,
    required double lat,
    required double lng,
    String? customNote,
  }) async {
    final alertId = 'sos_${const Uuid().v4().substring(0, 8)}';
    final now = DateTime.now();

    // Broadcast alert payload to all companions
    final broadcastAlert = ProximityAlert(
      id: alertId,
      tripId: tripId,
      type: AlertType.sosEmergency,
      title: '🚨 EMERGENCY SOS ALERT',
      message: customNote != null && customNote.isNotEmpty
          ? '$memberName triggered Emergency SOS: "$customNote"'
          : '$memberName needs urgent assistance! Exact coordinates attached.',
      senderMemberId: memberId,
      senderName: memberName,
      latitude: lat,
      longitude: lng,
      timestamp: now,
      urgency: AlertUrgency.critical,
    );

    // Customized reassuring local record for the sender with crisp coordinate reference
    final senderAlert = ProximityAlert(
      id: alertId,
      tripId: tripId,
      type: AlertType.sosEmergency,
      title: '🚨 SOS Emergency Active',
      message: 'SOS broadcast sent • Location shared with companions',
      senderMemberId: memberId,
      senderName: memberName,
      latitude: lat,
      longitude: lng,
      timestamp: now,
      urgency: AlertUrgency.critical,
    );

    _alerts.insert(0, senderAlert);
    await _storage.addAlert(senderAlert);
    if (_inAppBannersEnabled || senderAlert.urgency == AlertUrgency.critical) {
      _bannerController.add(senderAlert);
    }
    notifyListeners();

    // Automatically create an emergency stoppage on the trip
    if (tripId.isNotEmpty && tripId != 'trip_general') {
      try {
        final sosStoppage = Stoppage(
          id: 'sos_stop_${const Uuid().v4().substring(0, 8)}',
          tripId: tripId,
          name: '🚨 Emergency SOS ($memberName)',
          latitude: lat,
          longitude: lng,
          category: 'emergency',
          arrivedAt: now,
          notes: customNote != null && customNote.isNotEmpty
              ? 'Emergency SOS: "$customNote"'
              : 'Emergency SOS broadcast by $memberName at ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
          createdBy: memberId,
          createdByName: memberName,
        );
        _ref.read(allStoppagesProvider.notifier).addStoppage(sosStoppage, broadcast: false);
      } catch (e) {
        if (kDebugMode) debugPrint('[ProximityAlertService] SOS stoppage creation error: $e');
      }
    }

    try {
      _ref.read(realtimeSyncServiceProvider).broadcastProximityAlert(broadcastAlert);
    } catch (_) {}
    try {
      _ref.read(firestoreSyncServiceProvider).pushProximityAlert(broadcastAlert);
    } catch (_) {}

    // Improvement 4: Enqueue a direct RTDB wake message for every trip member
    // as a reliable delivery fallback for companions with stale FCM tokens or
    // who are temporarily offline. Messages are consumed on next app open.
    try {
      final trips = _storage.getTrips();
      final trip = trips.where((t) => t.id == tripId).firstOrNull;
      if (trip != null) {
        final rtdb = _ref.read(realtimeSyncServiceProvider);
        final myUid = UserService.getCurrentUser().id;
        final wakePayload = <String, dynamic>{
          ...broadcastAlert.toJson(),
          'type': 'PROXIMITY_ALERT',
        };
        for (final member in trip.members) {
          final memberUid = member.id;
          if (memberUid.isEmpty || memberUid == myUid) continue;
          rtdb.enqueueDirectMessage(
            targetUid: memberUid,
            msgId: broadcastAlert.id,
            payload: wakePayload,
            senderUid: myUid,
            ttlMs: 3600000, // SOS wake messages expire in 1 hour
          );
        }
      }
    } catch (_) {}
  }

  /// Broadcasts an alert when a concluded trip is reopened
  Future<void> broadcastTripReopened({
    required String tripId,
    required String tripTitle,
    required String reopenerName,
  }) async {
    final alert = ProximityAlert(
      id: 'reopen_${const Uuid().v4().substring(0, 8)}',
      tripId: tripId,
      type: AlertType.tripReopened,
      title: 'Journey Reopened',
      message: '$reopenerName reopened "$tripTitle". Edits and live tracking are re-enabled.',
      senderMemberId: UserService.getCurrentUser().id,
      senderName: reopenerName,
      timestamp: DateTime.now(),
      urgency: AlertUrgency.normal,
    );
    await _recordAndBroadcastAlert(alert);
  }

  /// Records a local alert strictly in this user's workspace without remote broadcasting
  Future<void> addLocalAlert(ProximityAlert alert) async {
    if (_alerts.any((a) => a.id == alert.id)) return;
    _alerts.insert(0, alert);
    await _storage.addAlert(alert);
    if (_inAppBannersEnabled || alert.urgency == AlertUrgency.critical) {
      _bannerController.add(alert);
    }
    notifyListeners();
  }

  /// Ingests an incoming alert received from a companion over WebSocket or Firestore
  Future<void> ingestRemoteAlert(ProximityAlert alert, {bool isHistorical = false}) async {
    if (_alerts.any((a) => a.id == alert.id)) return; // Prevent duplicate

    // Prevent resurrection of deleted / dismissed alerts
    if (_storage.isAlertDismissed(alert.id)) return;

    // Prevent resurrection of alerts cleared globally or trip-wise
    final globalClearedAt = _storage.getAlertsClearedAt();
    if (globalClearedAt != null && alert.timestamp.isBefore(globalClearedAt)) return;

    final tripClearedAt = _storage.getTripAlertsClearedAt(alert.tripId);
    if (tripClearedAt != null && alert.timestamp.isBefore(tripClearedAt)) return;

    final currentUser = UserService.getCurrentUser();
    // Do not re-ingest self-sent alerts
    if (alert.senderMemberId == currentUser.id) return;

    // Audience relevance check (Requirements 4, 5, 6):
    // Shared trip events must ONLY be shown to verified trip members
    if (alert.type != AlertType.sosEmergency && alert.type != AlertType.invitation) {
      final userTrips = _ref.read(tripListProvider);
      final isTripMember = userTrips.any((t) =>
        t.id == alert.tripId && (t.isCreator(currentUser.id) || t.hasMember(currentUser.id, currentUser.email))
      );
      if (!isTripMember) {
        return; // Non-trip user or unaccepted companion
      }
    }

    // If alert was emitted prior to current session, ingest silently as read
    // so it shows in historical logs without incrementing unread counters or firing banners.
    final bool isBeforeSession = alert.timestamp.isBefore(_sessionStartTime.subtract(const Duration(seconds: 45)));
    if (isHistorical || isBeforeSession) {
      alert = alert.copyWith(isRead: true);
    }

    // Check persistent read state: if user already marked this alert read, maintain read state!
    if (_storage.isAlertRead(alert.id)) {
      alert = alert.copyWith(isRead: true);
    }

    _alerts.insert(0, alert);
    await _storage.addAlert(alert);

    // Suppress notification banners for historical snapshots, stale alerts, session-initial alerts, or already-read alerts!
    final isStale = DateTime.now().difference(alert.timestamp).inSeconds > 60;
    if (!isHistorical && !isBeforeSession && !isStale && !alert.isRead) {
      if (_inAppBannersEnabled || alert.urgency == AlertUrgency.critical) {
        _bannerController.add(alert);
      }
    }
    notifyListeners();
  }

  /// Returns alerts relevant to the current user (filtering out unaccepted foreign trip events)
  List<ProximityAlert> getRelevantAlerts() {
    final currentUser = UserService.getCurrentUser();
    final userTrips = _ref.read(tripListProvider);

    return _alerts.where((alert) {
      if (alert.type == AlertType.sosEmergency) return true;
      if (alert.recipientId != null && alert.recipientId == currentUser.id) return true;
      if (alert.type == AlertType.invitation) return true;

      if (alert.tripId.isNotEmpty && alert.tripId != 'trip_general') {
        final trip = userTrips.where((t) => t.id == alert.tripId).firstOrNull;
        if (trip == null) return false;
        final isMember = trip.currentUserMember != null ||
            trip.isCreator(currentUser.id) ||
            trip.hasMember(currentUser.id, currentUser.email);
        if (!isMember) return false;
      }
      return true;
    }).toList();
  }

  /// Broadcasts an activity notification to all trip members (bills, memories, stops, settlements, invites, joins, leaves)
  Future<void> broadcastActivityAlert({
    String? id,
    required String tripId,
    required AlertType type,
    required String title,
    required String message,
    AlertUrgency urgency = AlertUrgency.normal,
    String? senderMemberId,
    String? senderName,
    String? itemId,
    String? itemType,
    double? amount,
    String? currency,
    bool showLocalBanner = true,
  }) async {
    final alertId = id ?? 'act_${const Uuid().v4().substring(0, 8)}';
    if (_alerts.any((a) => a.id == alertId)) return;

    final currentUser = UserService.getCurrentUser();
    final alert = ProximityAlert(
      id: alertId,
      tripId: tripId,
      type: type,
      title: title,
      message: message,
      senderMemberId: senderMemberId ?? currentUser.id,
      senderName: senderName ?? currentUser.displayName,
      timestamp: DateTime.now(),
      urgency: urgency,
      itemId: itemId,
      itemType: itemType,
      amount: amount,
      currency: currency,
    );

    await _recordAndBroadcastAlert(alert, showLocalBanner: showLocalBanner);
  }

  Future<void> _recordAndBroadcastAlert(ProximityAlert alert, {bool showLocalBanner = true}) async {
    _alerts.insert(0, alert);
    if (_alerts.length > 150) {
      _alerts.removeRange(150, _alerts.length);
    }
    await _storage.addAlert(alert);

    // Prune stale banner history (> 1 minute old)
    final now = DateTime.now();
    _recentlyEmittedBanners.removeWhere((_, time) => now.difference(time).inSeconds > 60);

    // Debounce duplicate banner emissions for identical item or action within 4 seconds
    final bannerKey = alert.itemId != null && alert.itemId!.isNotEmpty
        ? '${alert.type.name}_${alert.itemId}'
        : '${alert.type.name}_${alert.tripId}_${alert.title}';
    final lastBannerTime = _recentlyEmittedBanners[bannerKey];
    final isDuplicateBanner = lastBannerTime != null && now.difference(lastBannerTime).inSeconds < 4;

    if (showLocalBanner && !isDuplicateBanner && (_inAppBannersEnabled || alert.urgency == AlertUrgency.critical)) {
      _recentlyEmittedBanners[bannerKey] = now;
      _bannerController.add(alert);
    }
    notifyListeners();

    try {
      _ref.read(realtimeSyncServiceProvider).broadcastProximityAlert(alert);
    } catch (_) {}
    try {
      // Improvement 3: Set RTDB deduplication gate before Firestore push.
      // This prevents duplicate system notifications for companions who are
      // already live in the trip room and received the event via RTDB socket.
      final rtdb = _ref.read(realtimeSyncServiceProvider);
      final myUid = UserService.getCurrentUser().id;
      rtdb.setNotifGate(
        tripId: alert.tripId,
        alertId: alert.id,
        type: alert.type.name,
        senderUid: myUid,
        ttlMs: alert.urgency == AlertUrgency.critical ? 5000 : 30000,
      ).then((_) {
        _ref.read(firestoreSyncServiceProvider).pushProximityAlert(alert);
      }).catchError((_) {
        // Fail open: if RTDB gate fails, still push via Firestore
        try { _ref.read(firestoreSyncServiceProvider).pushProximityAlert(alert); } catch (_) {}
      });
    } catch (_) {
      try { _ref.read(firestoreSyncServiceProvider).pushProximityAlert(alert); } catch (_) {}
    }
  }

  Future<void> updateAlert(ProximityAlert updatedAlert) async {
    final idx = _alerts.indexWhere((a) => a.id == updatedAlert.id);
    if (idx != -1) {
      _alerts[idx] = updatedAlert;
      await _storage.saveAllAlerts(_alerts);
      notifyListeners();
    }
  }

  Future<void> deleteAlert(String alertId, {String? tripId}) async {
    final alert = _alerts.where((a) => a.id == alertId).firstOrNull;
    final effectiveTripId = tripId ?? alert?.tripId;
    _alerts.removeWhere((a) => a.id == alertId);
    await _storage.deleteAlert(alertId, tripId: effectiveTripId);
    if (effectiveTripId != null && effectiveTripId.isNotEmpty) {
      try {
        _ref.read(firestoreSyncServiceProvider).deleteRemoteAlert(effectiveTripId, alertId);
      } catch (_) {}
      if (alert?.type == AlertType.sosEmergency && alert?.senderMemberId != null) {
        try {
          _ref.read(realtimeSyncServiceProvider).resolveActiveSos(effectiveTripId, alert!.senderMemberId);
        } catch (_) {}
      }
    }
    notifyListeners();
  }

  Future<void> markAsRead(String alertId) async {
    final idx = _alerts.indexWhere((a) => a.id == alertId);
    if (idx != -1) {
      _alerts[idx] = _alerts[idx].copyWith(isRead: true);
      await _storage.markAlertAsRead(alertId);
      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    _alerts = _alerts.map((a) => a.copyWith(isRead: true)).toList();
    await _storage.markAllAlertsAsRead();
    notifyListeners();
  }

  Future<void> clearAlertsForTrip(String tripId) async {
    _alerts.removeWhere((a) => a.tripId == tripId);
    await _storage.clearAlertsForTrip(tripId);
    try {
      _ref.read(firestoreSyncServiceProvider).clearRemoteAlertsForTrip(tripId);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> clearAll() async {
    _alerts.clear();
    await _storage.clearAllAlerts();
    try {
      _ref.read(firestoreSyncServiceProvider).clearAllRemoteAlerts();
    } catch (_) {}
    notifyListeners();
  }

  @override
  void dispose() {
    _bannerController.close();
    super.dispose();
  }
}

final proximityAlertServiceProvider = ChangeNotifierProvider<ProximityAlertService>((ref) {
  final storage = ref.watch(localStorageServiceProvider);
  return ProximityAlertService(storage, ref);
});
