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
  final double? amount;
  final String? currency;
  final String? targetItemId;

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
    this.amount,
    this.currency,
    this.targetItemId,
  });

  String get category {
    if (actionType.contains('expense') || actionType.contains('bill')) return 'expense';
    if (actionType.contains('settlement') || actionType.contains('payment')) return 'settlement';
    if (actionType.contains('stoppage')) return 'stoppage';
    if (actionType.contains('memory') || actionType.contains('photo')) return 'memory';
    if (actionType.contains('budget') || actionType.contains('trip')) return 'trip';
    if (actionType.contains('sos') || actionType.contains('emergency')) return 'emergency';
    return 'general';
  }

  /// Action-specific semantic color hex for unified UI styling across the app
  int get semanticColorValue {
    if (actionType.contains('sos') || actionType.contains('emergency')) return 0xFFDC2626; // Crimson
    if (actionType.contains('delete') || actionType.contains('remove') || actionType.contains('conclude')) return 0xFFEF4444; // Rose Red
    if (actionType.contains('create') || actionType.contains('add') || actionType.contains('join')) return 0xFF10B981; // Emerald Teal
    if (actionType.contains('edit') || actionType.contains('update')) return 0xFF3B82F6; // Dodger Blue
    if (actionType.contains('settlement') || actionType.contains('payment')) return 0xFFD97706; // Amber
    if (actionType.contains('expense') || actionType.contains('bill')) return 0xFF6366F1; // Indigo
    return 0xFF10B981;
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
      'amount': amount,
      'currency': currency,
      'targetItemId': targetItemId,
    };
  }

  factory TripAuditLog.fromJson(Map<String, dynamic> json) {
    final rawAmt = json['amount'];
    final double? parsedAmt = rawAmt is num ? rawAmt.toDouble() : null;
    return TripAuditLog(
      id: json['id'] as String? ?? '',
      tripId: json['tripId'] as String? ?? '',
      actionType: json['actionType'] as String? ?? 'action',
      itemTitle: json['itemTitle'] as String? ?? 'Item',
      performedByMemberId: json['performedByMemberId'] as String? ?? 'User',
      performedByName: json['performedByName'] as String? ?? 'Companion',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      reason: json['reason'] as String?,
      changeDetails: json['changeDetails'] as String?,
      amount: parsedAmt,
      currency: json['currency'] as String?,
      targetItemId: json['targetItemId'] as String?,
    );
  }
}

