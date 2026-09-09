enum MutationAction {
  createTrip,
  updateTrip,
  deleteTrip,
  addStoppage,
  updateStoppage,
  deleteStoppage,
  addExpense,
  updateExpense,
  deleteExpense,
  addSettlement,
  updateMemberLocation,
  addMemory,
  deleteMemory,
}

enum SyncStatus {
  pending,
  syncing,
  synced,
  failed,
}

class SyncMutation {
  final String id;
  final MutationAction action;
  final String entityType;
  final String entityId;
  final String tripId;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final SyncStatus status;
  final int retryCount;
  final String? errorMessage;

  const SyncMutation({
    required this.id,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.tripId,
    required this.payload,
    required this.createdAt,
    this.status = SyncStatus.pending,
    this.retryCount = 0,
    this.errorMessage,
  });

  SyncMutation copyWith({
    String? id,
    MutationAction? action,
    String? entityType,
    String? entityId,
    String? tripId,
    Map<String, dynamic>? payload,
    DateTime? createdAt,
    SyncStatus? status,
    int? retryCount,
    String? errorMessage,
  }) {
    return SyncMutation(
      id: id ?? this.id,
      action: action ?? this.action,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      tripId: tripId ?? this.tripId,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'action': action.name,
      'entityType': entityType,
      'entityId': entityId,
      'tripId': tripId,
      'payload': payload,
      'createdAt': createdAt.toIso8601String(),
      'status': status.name,
      'retryCount': retryCount,
      'errorMessage': errorMessage,
    };
  }

  factory SyncMutation.fromJson(Map<String, dynamic> json) {
    return SyncMutation(
      id: json['id'] as String,
      action: MutationAction.values.firstWhere(
        (a) => a.name == json['action'],
        orElse: () => MutationAction.updateTrip,
      ),
      entityType: json['entityType'] as String,
      entityId: json['entityId'] as String,
      tripId: json['tripId'] as String? ?? '',
      payload: Map<String, dynamic>.from(json['payload'] as Map),
      createdAt: DateTime.parse(json['createdAt'] as String),
      status: SyncStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => SyncStatus.pending,
      ),
      retryCount: json['retryCount'] as int? ?? 0,
      errorMessage: json['errorMessage'] as String?,
    );
  }
}
