class ExecutiveLedgerData {
  final String tripTitle;
  final String tripId;
  final DateTime generatedAt;
  final double totalExpenses;
  final String currency;
  final List<Map<String, dynamic>> expenseEntries;
  final List<String> settlementNotes;
  final String organizerName;
  final String auditorName;

  const ExecutiveLedgerData({
    required this.tripTitle,
    required this.tripId,
    required this.generatedAt,
    required this.totalExpenses,
    this.currency = 'INR',
    required this.expenseEntries,
    required this.settlementNotes,
    this.organizerName = 'Expedition Leader',
    this.auditorName = 'Treasurer / Auditor',
  });

  Map<String, dynamic> toJson() => {
        'tripTitle': tripTitle,
        'tripId': tripId,
        'generatedAt': generatedAt.toIso8601String(),
        'totalExpenses': totalExpenses,
        'currency': currency,
        'expenseEntries': expenseEntries,
        'settlementNotes': settlementNotes,
        'organizerName': organizerName,
        'auditorName': auditorName,
      };

  factory ExecutiveLedgerData.fromJson(Map<String, dynamic> json) {
    return ExecutiveLedgerData(
      tripTitle: json['tripTitle'] as String? ?? 'Trip Ledger',
      tripId: json['tripId'] as String? ?? '',
      generatedAt: json['generatedAt'] != null
          ? DateTime.tryParse(json['generatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      totalExpenses: (json['totalExpenses'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'INR',
      expenseEntries: (json['expenseEntries'] as List?)
              ?.map((e) => (e as Map).cast<String, dynamic>())
              .toList() ??
          [],
      settlementNotes: (json['settlementNotes'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      organizerName: json['organizerName'] as String? ?? 'Expedition Leader',
      auditorName: json['auditorName'] as String? ?? 'Treasurer / Auditor',
    );
  }
}
