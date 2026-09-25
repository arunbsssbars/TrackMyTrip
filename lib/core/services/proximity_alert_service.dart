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

  ProximityAlertService(this._storage, this._ref) {
    _loadAlerts();
  }

  List<ProximityAlert> get alerts => List.unmodifiable(_alerts);
  int get unreadCount => _alerts.where((a) => !a.isRead).length;
  double get strayThresholdMeters => _strayThresholdMeters;
  double get stoppageArrivalRadiusMeters => _stoppageArrivalRadiusMeters;
  bool get strayAlertsEnabled => _strayAlertsEnabled;
  bool get stoppageAlertsEnabled => _stoppageAlertsEnabled;
  bool get inAppBannersEnabled => _inAppBannersEnabled;
  Stream<ProximityAlert> get bannerStream => _bannerController.stream;

  void _loadAlerts() {
    _alerts = _storage.getAllAlerts();
    _inAppBannersEnabled = _storage.getInAppBannersEnabled();
    notifyListeners();
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

    for (final stop in activeStoppages) {
      final distance = Geolocator.distanceBetween(
        myLat,
        myLng,
        stop.latitude,
        stop.longitude,
      );

      if (distance <= _stoppageArrivalRadiusMeters) {
        final debounceKey = 'arrival_${stop.id}';
        final lastSent = _debounceTimestamps[debounceKey];
        if (lastSent == null || DateTime.now().difference(lastSent).inMinutes >= 20) {
          _debounceTimestamps[debounceKey] = DateTime.now();

          final alert = ProximityAlert(
            id: 'alert_${const Uuid().v4().substring(0, 8)}',
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

    // Check persistent read state: if user already marked this alert read, maintain read state!
    if (_storage.isAlertRead(alert.id)) {
      alert = alert.copyWith(isRead: true);
    }

    _alerts.insert(0, alert);
    await _storage.addAlert(alert);

    // Suppress notification banners for historical snapshots, stale alerts, or already-read alerts!
    final isStale = DateTime.now().difference(alert.timestamp).inMinutes > 2;
    if (!isHistorical && !isStale && !alert.isRead) {
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
        final isMember = trip.isCreator(currentUser.id) || trip.hasMember(currentUser.id, currentUser.email);
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
