import '../../models/waypoint_activity_item.dart';

class WaypointActivityService {
  static final WaypointActivityService _instance = WaypointActivityService._internal();
  factory WaypointActivityService() => _instance;
  WaypointActivityService._internal();

  /// Calculates completed activities ratio
  double calculateProgressRatio(List<WaypointActivityItem> items) {
    if (items.isEmpty) return 0.0;
    final completed = items.where((i) => i.isCompleted).length;
    return completed / items.length;
  }

  /// Toggles completion status and stamps time
  WaypointActivityItem toggleItemCompletion(WaypointActivityItem item) {
    final nextState = !item.isCompleted;
    return item.copyWith(
      isCompleted: nextState,
      completedAt: nextState ? DateTime.now() : null,
      clearCompletedAt: !nextState,
    );
  }

  /// Generates default suggested activities for a stoppage based on its title or tag
  List<WaypointActivityItem> generateSuggestedActivities({
    required String stoppageId,
    required String tagOrCategory,
  }) {
    final lower = tagOrCategory.toLowerCase();
    final List<String> titles;

    if (lower.contains('fuel') || lower.contains('petrol')) {
      titles = ['Check tyre pressure', 'Clean windshield', 'Record odometer & fuel slip'];
    } else if (lower.contains('food') || lower.contains('lunch') || lower.contains('dinner')) {
      titles = ['Order meals for group', 'Collect paper receipt/bill', 'Refill drinking water bottles'];
    } else if (lower.contains('view') || lower.contains('scenic') || lower.contains('pass')) {
      titles = ['Take group expedition photo', 'Check vehicle brake temperature', 'Record summit altitude'];
    } else {
      titles = ['Verify group headcount', 'Stretch & quick rest break'];
    }

    final now = DateTime.now();
    return titles
        .asMap()
        .entries
        .map(
          (e) => WaypointActivityItem(
            id: 'act_${stoppageId}_${e.key}',
            stoppageId: stoppageId,
            title: e.value,
            createdAt: now,
          ),
        )
        .toList();
  }
}
