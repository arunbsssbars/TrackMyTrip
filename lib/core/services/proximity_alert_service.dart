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
    _alerts = raw.where((a) => seen.add(a.id)).toList();
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
    final newAlerts = <ProximityAlert>[];

    for (final trip in trips) {
      final creator = trip.currentUserMember ?? (trip.members.isNotEmpty ? trip.members.first : null);
      final creatorId = creator?.id ?? 'usr_me';
      final creatorName = creator?.name ?? 'Trip Leader';

      // 1. Trip Creation Alert
      if (!existingAlertIds.contains('alert_create_${trip.id}')) {
        newAlerts.add(ProximityAlert(
          id: 'alert_create_${trip.id}',
          tripId: trip.id,
          type: AlertType.general,
          title: 'Journey Initialized',
          message: 'Welcome to "${trip.title}". Itinerary & expense ledger ready.',
          senderMemberId: creatorId,
          senderName: creatorName,
          timestamp: trip.startDate,
          isRead: true,
          urgency: AlertUrgency.normal,
        ));
      }

      // 2. Budget Notification
      if (trip.budget != null && trip.budget! > 0 && !existingAlertIds.contains('alert_budget_${trip.id}')) {
        newAlerts.add(ProximityAlert(
          id: 'alert_budget_${trip.id}',
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
        if (!existingAlertIds.contains('alert_stop_${s.id}')) {
          newAlerts.add(ProximityAlert(
            id: 'alert_stop_${s.id}',
            tripId: trip.id,
            type: AlertType.stoppageArrival,
            title: 'Waypoint Added',
            message: 'Stop "${s.name}" registered on journey route.',
            senderMemberId: s.createdBy.isNotEmpty ? s.createdBy : creatorId,
            senderName: creatorName,
            timestamp: s.arrivedAt,
            isRead: true,
            urgency: AlertUrgency.normal,
          ));
        }
      }

      // 4. Expenses
      for (final e in allExpenses.where((exp) => exp.tripId == trip.id)) {
        if (!existingAlertIds.contains('alert_exp_${e.id}')) {
          final payerName = trip.getMemberName(e.paidByMemberId);
          newAlerts.add(ProximityAlert(
            id: 'alert_exp_${e.id}',
            tripId: trip.id,
            type: AlertType.billAdded,
            title: 'Bill Added',
            message: '${payerName.isNotEmpty && payerName != "Unknown Member" ? payerName : creatorName} logged "${e.title}" (${e.currency} ${e.totalAmount.toStringAsFixed(0)})',
            senderMemberId: e.paidByMemberId,
            senderName: payerName.isNotEmpty && payerName != 'Unknown Member' ? payerName : creatorName,
            timestamp: e.createdAt,
            isRead: true,
            urgency: AlertUrgency.normal,
          ));
        }
      }

      // 5. Settlements
      for (final s in allSettlements.where((settle) => settle.tripId == trip.id)) {
        if (!existingAlertIds.contains('alert_settle_${s.id}')) {
          final payerName = trip.getMemberName(s.payerMemberId);
          final payeeName = trip.getMemberName(s.receiverMemberId);
          newAlerts.add(ProximityAlert(
            id: 'alert_settle_${s.id}',
            tripId: trip.id,
            type: AlertType.settlementRecorded,
            title: 'Settlement Recorded',
            message: '$payerName paid $payeeName (${s.currency} ${s.amount.toStringAsFixed(0)})',
            senderMemberId: s.payerMemberId,
            senderName: payerName,
            timestamp: s.settledAt,
            isRead: true,
            urgency: AlertUrgency.normal,
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
    if (trip != null && (trip.isCompleted || trip.status == 'completed')) return;

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
    if (trip != null && (trip.isCompleted || trip.status == 'completed')) return;

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

  /// Sends a critical SOS Emergency broadcast to all companions with live GPS
  Future<void> triggerEmergencySos({
    required String tripId,
    required String memberId,
    required String memberName,
    required double lat,
    required double lng,
    String? customNote,
  }) async {
    final alert = ProximityAlert(
      id: 'sos_${const Uuid().v4().substring(0, 8)}',
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
      timestamp: DateTime.now(),
      urgency: AlertUrgency.critical,
    );

    await _recordAndBroadcastAlert(alert);
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
      type: AlertType.general,
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
    required String tripId,
    required AlertType type,
    required String title,
    required String message,
    AlertUrgency urgency = AlertUrgency.normal,
    String? senderMemberId,
    String? senderName,
  }) async {
    final currentUser = UserService.getCurrentUser();
    final alert = ProximityAlert(
      id: 'act_${const Uuid().v4().substring(0, 8)}',
      tripId: tripId,
      type: type,
      title: title,
      message: message,
      senderMemberId: senderMemberId ?? currentUser.id,
      senderName: senderName ?? currentUser.displayName,
      timestamp: DateTime.now(),
      urgency: urgency,
    );

    await _recordAndBroadcastAlert(alert);
  }

  Future<void> _recordAndBroadcastAlert(ProximityAlert alert) async {
    _alerts.insert(0, alert);
    await _storage.addAlert(alert);
    if (_inAppBannersEnabled || alert.urgency == AlertUrgency.critical) {
      _bannerController.add(alert);
    }
    notifyListeners();

    try {
      _ref.read(realtimeSyncServiceProvider).broadcastProximityAlert(alert);
    } catch (_) {}
    try {
      _ref.read(firestoreSyncServiceProvider).pushProximityAlert(alert);
    } catch (_) {}
  }

  Future<void> updateAlert(ProximityAlert updatedAlert) async {
    final idx = _alerts.indexWhere((a) => a.id == updatedAlert.id);
    if (idx != -1) {
      _alerts[idx] = updatedAlert;
      await _storage.saveAllAlerts(_alerts);
      notifyListeners();
    }
  }

  Future<void> deleteAlert(String alertId) async {
    _alerts.removeWhere((a) => a.id == alertId);
    await _storage.deleteAlert(alertId);
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

  Future<void> clearAll() async {
    _alerts.clear();
    await _storage.clearAllAlerts();
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
