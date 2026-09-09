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
import '../../providers/trip_provider.dart';

class ProximityAlertService extends ChangeNotifier {
  final LocalStorageService _storage;
  final Ref _ref;

  List<ProximityAlert> _alerts = [];
  double _strayThresholdMeters = 1500.0; // Default 1.5 km
  final double _stoppageArrivalRadiusMeters = 350.0; // Default 350 m
  bool _strayAlertsEnabled = true;
  bool _stoppageAlertsEnabled = true;

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
  Stream<ProximityAlert> get bannerStream => _bannerController.stream;

  void _loadAlerts() {
    _alerts = _storage.getAllAlerts();
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
            title: 'Arrived at Pitstop',
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

  /// Ingests an incoming alert received from a companion over WebSocket
  Future<void> ingestRemoteAlert(ProximityAlert alert) async {
    if (_alerts.any((a) => a.id == alert.id)) return; // Prevent duplicate

    _alerts.insert(0, alert);
    await _storage.addAlert(alert);
    _bannerController.add(alert);
    notifyListeners();
  }

  Future<void> _recordAndBroadcastAlert(ProximityAlert alert) async {
    _alerts.insert(0, alert);
    await _storage.addAlert(alert);
    _bannerController.add(alert);
    notifyListeners();

    try {
      _ref.read(realtimeSyncServiceProvider).broadcastProximityAlert(alert);
    } catch (_) {}
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
    await _storage.saveAllAlerts(_alerts);
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
