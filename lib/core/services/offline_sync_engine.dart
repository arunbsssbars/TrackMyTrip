import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../../models/sync_mutation.dart';
import '../../providers/trip_provider.dart';
import 'local_storage_service.dart';

class OfflineSyncEngine extends ChangeNotifier {
  final LocalStorageService _storage;
  bool _isSyncing = false;
  DateTime? _lastSyncedTime;
  String _serverHost = '172.20.10.11:8086'; // Host Wi-Fi IP default
  String? _lastSyncError;

  // Candidate hosts to try if device is connected to local Wi-Fi, Tailscale, or emulator
  static const List<String> defaultCandidates = [
    '172.20.10.11:8086',
    '100.98.130.99:8086',
    '10.0.2.2:8086',
    '127.0.0.1:8086',
  ];

  OfflineSyncEngine(this._storage) {
    _initAutoSync();
  }

  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncedTime => _lastSyncedTime;
  String? get lastSyncError => _lastSyncError;
  String get serverHost => _serverHost;
  int get pendingCount => _storage.getPendingMutations().where((m) => m.status == SyncStatus.pending).length;
  List<SyncMutation> get pendingMutations => _storage.getPendingMutations();

  Timer? _autoSyncTimer;

  void updateServerHost(String host) {
    _serverHost = host;
    notifyListeners();
  }

  void _initAutoSync() {
    // Periodically check if there are pending offline mutations to flush
    _autoSyncTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (pendingCount > 0 && !_isSyncing) {
        syncPendingMutationsNow();
      }
    });
  }

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    super.dispose();
  }

  /// Queues a local offline action and immediately attempts to sync if online
  Future<void> enqueueMutation({
    required MutationAction action,
    required String entityType,
    required String entityId,
    required String tripId,
    required Map<String, dynamic> payload,
  }) async {
    const uuid = Uuid();
    final mutation = SyncMutation(
      id: 'mut_${uuid.v4().substring(0, 8)}',
      action: action,
      entityType: entityType,
      entityId: entityId,
      tripId: tripId,
      payload: payload,
      createdAt: DateTime.now(),
      status: SyncStatus.pending,
    );

    await _storage.enqueueMutation(mutation);
    notifyListeners();

    // Trigger immediate sync attempt in background
    syncPendingMutationsNow();
  }

  /// Remove single mutation by ID
  Future<void> removeMutation(String id) async {
    await _storage.removeMutation(id);
    if (pendingCount == 0) {
      _lastSyncError = null;
    }
    notifyListeners();
  }

  /// Mark all pending items as synced and clear the local outbox
  Future<void> resolveAllLocally() async {
    await _storage.saveAllMutations([]);
    _lastSyncedTime = DateTime.now();
    _lastSyncError = null;
    notifyListeners();
  }

  /// Clear all offline mutations
  Future<void> clearAll() async {
    await resolveAllLocally();
  }

  /// Manually or automatically flushes all pending mutations to the sync server
  Future<bool> syncPendingMutationsNow() async {
    if (_isSyncing) return false;

    final pending = _storage.getPendingMutations().where((m) => m.status == SyncStatus.pending).toList();
    if (pending.isEmpty) {
      _lastSyncError = null;
      return true;
    }

    _isSyncing = true;
    _lastSyncError = null;
    notifyListeners();

    // Determine working host among candidates
    String activeHost = _serverHost;
    final candidates = [
      _serverHost,
      ...defaultCandidates.where((c) => c != _serverHost),
    ];

    for (final host in candidates) {
      try {
        final probeUri = Uri.parse('http://$host/api/health');
        final probeRes = await http.get(probeUri).timeout(const Duration(milliseconds: 1500));
        if (probeRes.statusCode < 500) {
          activeHost = host;
          _serverHost = host;
          break;
        }
      } catch (_) {
        // Probe next candidate host
      }
    }

    bool allSuccess = true;

    for (final mutation in pending) {
      try {
        final url = Uri.parse('http://$activeHost/api/rooms/${mutation.tripId}');
        final res = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'mutationId': mutation.id,
            'action': mutation.action.name,
            'entityType': mutation.entityType,
            'entityId': mutation.entityId,
            'payload': mutation.payload,
            'timestamp': mutation.createdAt.toIso8601String(),
          }),
        ).timeout(const Duration(seconds: 3));

        if (res.statusCode >= 200 && res.statusCode < 300) {
          await _storage.removeMutation(mutation.id);
        } else {
          allSuccess = false;
        }
      } catch (_) {
        // Network unavailable or server offline (offline mode)
        allSuccess = false;
        break;
      }
    }

    _isSyncing = false;
    if (allSuccess) {
      _lastSyncedTime = DateTime.now();
      _lastSyncError = null;
    } else {
      _lastSyncError = 'Sync server unreachable ($activeHost). All records remain 100% saved on this device.';
    }
    notifyListeners();
    return allSuccess;
  }
}

final offlineSyncEngineProvider = ChangeNotifierProvider<OfflineSyncEngine>((ref) {
  final storage = ref.watch(localStorageServiceProvider);
  return OfflineSyncEngine(storage);
});

final pendingMutationsCountProvider = Provider<int>((ref) {
  final engine = ref.watch(offlineSyncEngineProvider);
  return engine.pendingCount;
});

