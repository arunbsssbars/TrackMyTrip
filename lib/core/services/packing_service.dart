import '../../models/packing_item.dart';

class PackingStats {
  final int totalCount;
  final int packedCount;
  final double progress; // 0.0 to 1.0

  const PackingStats({
    required this.totalCount,
    required this.packedCount,
    required this.progress,
  });
}

class PackingService {
  static final Map<String, List<PackingItem>> _tripItemsCache = {};

  static const List<String> categories = [
    'All',
    'Documents',
    'Clothing',
    'Electronics',
    'Medical',
    'Gear',
    'Vehicle',
  ];

  /// Returns packing items for a given trip, populating defaults if completely empty
  static List<PackingItem> getItemsForTrip(String tripId) {
    if (!_tripItemsCache.containsKey(tripId) || _tripItemsCache[tripId]!.isEmpty) {
      _tripItemsCache[tripId] = _generateDefaultItems(tripId);
    }
    return List.unmodifiable(_tripItemsCache[tripId]!);
  }

  /// Sets or updates the entire packing list for a trip
  static void setItemsForTrip(String tripId, List<PackingItem> items) {
    _tripItemsCache[tripId] = List.from(items);
  }

  /// Adds a new packing item
  static PackingItem addItem(String tripId, {
    required String title,
    required String category,
    String? assignedToMemberId,
    String? assignedToMemberName,
    int quantity = 1,
  }) {
    final newItem = PackingItem(
      id: 'pack_${DateTime.now().millisecondsSinceEpoch}_${title.hashCode.abs()}',
      tripId: tripId,
      title: title.trim(),
      category: category,
      assignedToMemberId: assignedToMemberId,
      assignedToMemberName: assignedToMemberName,
      quantity: quantity,
    );

    final list = _tripItemsCache.putIfAbsent(tripId, () => []);
    list.add(newItem);
    return newItem;
  }

  /// Toggles the packed state of an item
  static PackingItem? togglePacked(String tripId, String itemId) {
    final list = _tripItemsCache[tripId];
    if (list == null) return null;

    final index = list.indexWhere((i) => i.id == itemId);
    if (index == -1) return null;

    final updated = list[index].copyWith(isPacked: !list[index].isPacked);
    list[index] = updated;
    return updated;
  }

  /// Deletes an item from the packing list
  static bool deleteItem(String tripId, String itemId) {
    final list = _tripItemsCache[tripId];
    if (list == null) return false;
    final initialLen = list.length;
    list.removeWhere((i) => i.id == itemId);
    return list.length < initialLen;
  }

  /// Computes packing progress statistics for a trip
  static PackingStats getStats(String tripId) {
    final items = _tripItemsCache[tripId] ?? [];
    if (items.isEmpty) {
      return const PackingStats(totalCount: 0, packedCount: 0, progress: 0.0);
    }
    final packed = items.where((i) => i.isPacked).length;
    final progress = packed / items.length;
    return PackingStats(
      totalCount: items.length,
      packedCount: packed,
      progress: progress.clamp(0.0, 1.0),
    );
  }

  /// Pre-seeded expedition packing checklist template
  static List<PackingItem> _generateDefaultItems(String tripId) {
    return [
      PackingItem(id: '${tripId}_p1', tripId: tripId, title: 'Government ID & Driver License', category: 'Documents', quantity: 1),
      PackingItem(id: '${tripId}_p2', tripId: tripId, title: 'Vehicle Registration & Insurance', category: 'Documents', quantity: 1),
      PackingItem(id: '${tripId}_p3', tripId: tripId, title: 'Thermal Jacket & Rainwear', category: 'Clothing', quantity: 2),
      PackingItem(id: '${tripId}_p4', tripId: tripId, title: 'Power Bank & Charging Cables', category: 'Electronics', quantity: 2),
      PackingItem(id: '${tripId}_p5', tripId: tripId, title: 'Offline GPS / Map Device', category: 'Electronics', quantity: 1),
      PackingItem(id: '${tripId}_p6', tripId: tripId, title: 'First Aid Kit & Motion Sickness Meds', category: 'Medical', quantity: 1),
      PackingItem(id: '${tripId}_p7', tripId: tripId, title: 'Tire Pressure Gauge & Puncture Kit', category: 'Vehicle', quantity: 1),
      PackingItem(id: '${tripId}_p8', tripId: tripId, title: 'Headlamp & Flashlight', category: 'Gear', quantity: 1),
    ];
  }
}
