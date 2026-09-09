class TripAuditLog {
  final String id;
  final String tripId;
  final String actionType; // create_expense, edit_expense, delete_expense, create_settlement, edit_settlement, delete_settlement, create_stoppage, edit_stoppage, delete_stoppage, add_memory, delete_memory, update_budget
  final String itemTitle;
  final String performedByMemberId;
  final String performedByName;
  final DateTime timestamp;
  final String? reason;
  final String? changeDetails;

  const TripAuditLog({
    required this.id,
    required this.tripId,
    required this.actionType,
    required this.itemTitle,
    required this.performedByMemberId,
    required this.performedByName,
    required this.timestamp,
    this.reason,
    this.changeDetails,
  });

  String get category {
    if (actionType.contains('expense')) return 'expense';
    if (actionType.contains('settlement')) return 'settlement';
    if (actionType.contains('stoppage')) return 'stoppage';
    if (actionType.contains('memory')) return 'memory';
    if (actionType.contains('budget') || actionType.contains('trip')) return 'trip';
    return 'general';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tripId': tripId,
      'actionType': actionType,
      'itemTitle': itemTitle,
      'performedByMemberId': performedByMemberId,
      'performedByName': performedByName,
      'timestamp': timestamp.toIso8601String(),
      'reason': reason,
      'changeDetails': changeDetails,
    };
  }

  factory TripAuditLog.fromJson(Map<String, dynamic> json) {
    return TripAuditLog(
      id: json['id'] as String,
      tripId: json['tripId'] as String,
      actionType: json['actionType'] as String,
      itemTitle: json['itemTitle'] as String,
      performedByMemberId: json['performedByMemberId'] as String? ?? 'User',
      performedByName: json['performedByName'] as String? ?? 'Companion',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      reason: json['reason'] as String?,
      changeDetails: json['changeDetails'] as String?,
    );
  }
}

