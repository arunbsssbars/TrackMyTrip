class TripArchiveBundle {
  final String version;
  final String tripId;
  final String tripTitle;
  final DateTime exportedAt;
  final Map<String, dynamic> tripData;
  final List<Map<String, dynamic>> stoppages;
  final List<Map<String, dynamic>> expenses;
  final List<Map<String, dynamic>> packingItems;
  final String checksumSha256;

  const TripArchiveBundle({
    this.version = '1.0',
    required this.tripId,
    required this.tripTitle,
    required this.exportedAt,
    required this.tripData,
    this.stoppages = const [],
    this.expenses = const [],
    this.packingItems = const [],
    required this.checksumSha256,
  });

  Map<String, dynamic> toSerializableMap() => {
        'version': version,
        'tripId': tripId,
        'tripTitle': tripTitle,
        'exportedAt': exportedAt.toIso8601String(),
        'tripData': tripData,
        'stoppages': stoppages,
        'expenses': expenses,
        'packingItems': packingItems,
      };

  Map<String, dynamic> toJson() => {
        ...toSerializableMap(),
        'checksumSha256': checksumSha256,
      };

  factory TripArchiveBundle.fromJson(Map<String, dynamic> json) {
    return TripArchiveBundle(
      version: json['version'] as String? ?? '1.0',
      tripId: json['tripId'] as String? ?? '',
      tripTitle: json['tripTitle'] as String? ?? 'Trip Archive',
      exportedAt: json['exportedAt'] != null
          ? DateTime.tryParse(json['exportedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      tripData: (json['tripData'] as Map?)?.cast<String, dynamic>() ?? {},
      stoppages: (json['stoppages'] as List?)
              ?.map((e) => (e as Map).cast<String, dynamic>())
              .toList() ??
          [],
      expenses: (json['expenses'] as List?)
              ?.map((e) => (e as Map).cast<String, dynamic>())
              .toList() ??
          [],
      packingItems: (json['packingItems'] as List?)
              ?.map((e) => (e as Map).cast<String, dynamic>())
              .toList() ??
          [],
      checksumSha256: json['checksumSha256'] as String? ?? '',
    );
  }
}
