import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/proximity_alert.dart';
import '../../providers/trip_provider.dart';
import '../utils/app_logger.dart';
import 'proximity_alert_service.dart';
import 'realtime_sync_service.dart';

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService(ref);
});

/// Background message handler for FCM
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  AppLogger.info('[FCM] Background message received: ${message.messageId}');
  // Background processing handled at native/system level
}

class PushNotificationService {
  final Ref? _ref;
  FirebaseMessaging get _fcm => FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  // Dedicated Android Notification Channels
  static const AndroidNotificationChannel sosChannel = AndroidNotificationChannel(
    'emergency_sos_channel',
    '🚨 Emergency SOS & Critical Safety Alerts',
    description: 'Life-critical SOS beacons and urgent companion safety alerts. Always loud and bypasses standard mutes.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  static const AndroidNotificationChannel activityChannel = AndroidNotificationChannel(
    'activity_updates_channel',
    'Trip Activity & Financial Updates',
    description: 'Notifications for shared bills, expenses, settlements, waypoints, and companion invitations.',
    importance: Importance.defaultImportance,
    playSound: true,
    enableVibration: true,
  );

  PushNotificationService([this._ref]);

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Request permissions for iOS and Android 13+
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        criticalAlert: true, // For iOS Critical Alerts
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        AppLogger.info('Push notification permission granted');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        AppLogger.info('Push notification provisional permission granted');
      } else {
        AppLogger.warn('Push notification permission declined or not accepted');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[PushNotificationService] FCM permission error: $e');
    }

    try {
      // Configure Local Notifications for foreground display
      const AndroidInitializationSettings androidInitSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings iosInitSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        requestCriticalPermission: true,
      );
      const InitializationSettings initSettings = InitializationSettings(
        android: androidInitSettings,
        iOS: iosInitSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (details) {
          AppLogger.info('Notification tapped: ${details.payload}');
        },
      );

      // Create Android notification channels
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(sosChannel);
        await androidPlugin.createNotificationChannel(activityChannel);
      }

      // Listen for foreground FCM messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _handleIncomingMessage(message);
      });

      // Listen for notification taps when opening app from background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        AppLogger.info('App opened from push notification: ${message.data}');
      });

      // Listen for token refresh to avoid stale FCM tokens
      _fcm.onTokenRefresh.listen((newToken) async {
        AppLogger.info('[PushNotificationService] FCM token refreshed');
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        if (currentUserId != null && currentUserId.isNotEmpty) {
          // Dual-write: Firestore (cold backup) + RTDB hot path with onDisconnect guard
          unawaited(FirebaseFirestore.instance.collection('users').doc(currentUserId).set({
            'fcmToken': newToken,
            'lastActive': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true)));
          if (_ref != null) {
            unawaited(
              _ref.read(realtimeSyncServiceProvider).registerFcmTokenInRtdb(currentUserId, newToken),
            );
          }
        }
      });

      _isInitialized = true;
    } catch (e) {
      if (kDebugMode) debugPrint('[PushNotificationService] Local notifications init error: $e');
    }
  }

  void _handleIncomingMessage(RemoteMessage message) {
    AppLogger.info('Incoming FCM message: ${message.data}');

    final data = message.data;
    final notification = message.notification;

    final String typeStr = data['type']?.toString() ?? '';
    final String urgencyStr = data['urgency']?.toString() ?? '';
    final String title = notification?.title ?? data['title']?.toString() ?? 'Trip Activity';
    final String body = notification?.body ?? data['message']?.toString() ?? '';

    final bool isSos = typeStr == 'sosEmergency' ||
        urgencyStr == 'critical' ||
        title.toLowerCase().contains('sos') ||
        title.toLowerCase().contains('emergency') ||
        title.contains('🚨');

    // 1. Check user's notification mute setting
    final storage = _ref?.read(localStorageServiceProvider);
    final bool notificationsEnabled = storage?.getInAppBannersEnabled() ?? true;

    // 2. Ingest the alert into ProximityAlertService for the Activity Hub
    if (_ref != null) {
      try {
        final alert = ProximityAlert(
          id: data['id']?.toString() ?? 'fcm_${DateTime.now().millisecondsSinceEpoch}',
          tripId: data['tripId']?.toString() ?? 'trip_general',
          type: isSos ? AlertType.sosEmergency : _parseAlertType(typeStr),
          title: title,
          message: body,
          senderMemberId: data['senderMemberId']?.toString() ?? 'fcm_sender',
          senderName: data['senderName']?.toString() ?? 'Companion',
          latitude: double.tryParse(data['latitude']?.toString() ?? ''),
          longitude: double.tryParse(data['longitude']?.toString() ?? ''),
          timestamp: DateTime.now(),
          urgency: isSos ? AlertUrgency.critical : _parseUrgency(urgencyStr),
        );
        _ref.read(proximityAlertServiceProvider).ingestRemoteAlert(alert);
      } catch (e) {
        if (kDebugMode) debugPrint('[PushNotificationService] Ingest error: $e');
      }
    }

    // 3. Display Push Notification according to Industry Standards
    if (isSos) {
      // Emergency SOS ALWAYS notifies with maximum importance and sound!
      _showLocalNotification(
        id: message.hashCode,
        title: title,
        body: body,
        channel: sosChannel,
        isCritical: true,
        payload: jsonEncode(data),
      );
      // Improvement 2: Write delivery ACK to RTDB so the SOS sender can show
      // a live "X/N companions notified" counter without Cloud Functions.
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null && _ref != null) {
        final msgId = data['id']?.toString() ?? message.messageId ?? '';
        final tripId = data['tripId']?.toString() ?? '';
        unawaited(
          _ref.read(realtimeSyncServiceProvider).ackNotification(
            myUid: uid,
            msgId: msgId.isNotEmpty ? msgId : 'sos_${DateTime.now().millisecondsSinceEpoch}',
            type: 'sosEmergency',
            tripId: tripId,
          ),
        );
      }
    } else if (notificationsEnabled && notification != null) {
      // Improvement 3: Suppress duplicate system notification if user is
      // already live in this trip's RTDB room (they already saw the in-app banner).
      // SOS is intentionally excluded — always shows regardless.
      final tripId = data['tripId']?.toString() ?? '';
      if (tripId.isNotEmpty && _ref != null) {
        final rtdb = _ref.read(realtimeSyncServiceProvider);
        if (!rtdb.shouldShowSystemNotif(tripId)) {
          AppLogger.info('[FCM] Suppressed duplicate system notif — user is live in trip room $tripId.');
          return;
        }
      }
      // Regular activity notification only if notifications are enabled
      _showLocalNotification(
        id: message.hashCode,
        title: title,
        body: body,
        channel: activityChannel,
        isCritical: false,
        payload: jsonEncode(data),
      );
    } else {
      AppLogger.info('Activity notification delivered silently (notifications muted by user).');
    }
  }

  void _showLocalNotification({
    required int id,
    required String title,
    required String body,
    required AndroidNotificationChannel channel,
    required bool isCritical,
    String? payload,
  }) {
    try {
      _localNotifications.show(
        id,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            icon: '@mipmap/ic_launcher',
            importance: isCritical ? Importance.max : Importance.defaultImportance,
            priority: isCritical ? Priority.max : Priority.defaultPriority,
            fullScreenIntent: isCritical,
            category: isCritical ? AndroidNotificationCategory.alarm : AndroidNotificationCategory.social,
            playSound: true,
            enableVibration: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            interruptionLevel: isCritical
                ? InterruptionLevel.critical
                : InterruptionLevel.active,
          ),
        ),
        payload: payload,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[PushNotificationService] showNotification error: $e');
    }
  }

  AlertType _parseAlertType(String typeStr) {
    switch (typeStr) {
      case 'billAdded':
        return AlertType.billAdded;
      case 'billUpdated':
        return AlertType.billUpdated;
      case 'settlementRecorded':
        return AlertType.settlementRecorded;
      case 'stoppageArrival':
        return AlertType.stoppageArrival;
      case 'stoppageDeparture':
        return AlertType.stoppageDeparture;
      case 'invitation':
        return AlertType.invitation;
      case 'invitationAccepted':
        return AlertType.invitationAccepted;
      case 'invitationRejected':
        return AlertType.invitationRejected;
      case 'memberJoined':
        return AlertType.memberJoined;
      case 'memberLeft':
        return AlertType.memberLeft;
      case 'companionStray':
        return AlertType.companionStray;
      case 'sosEmergency':
        return AlertType.sosEmergency;
      default:
        return AlertType.general;
    }
  }

  AlertUrgency _parseUrgency(String urgencyStr) {
    switch (urgencyStr) {
      case 'critical':
        return AlertUrgency.critical;
      case 'high':
        return AlertUrgency.high;
      case 'low':
        return AlertUrgency.low;
      default:
        return AlertUrgency.normal;
    }
  }

  Future<void> subscribeToTripTopic(String tripId) async {
    try {
      await _fcm.subscribeToTopic('trip_$tripId');
    } catch (_) {}
  }

  Future<void> unsubscribeFromTripTopic(String tripId) async {
    try {
      await _fcm.unsubscribeFromTopic('trip_$tripId');
    } catch (_) {}
  }

  Future<String?> getToken() async {
    try {
      return await _fcm.getToken();
    } catch (_) {
      return null;
    }
  }
}
