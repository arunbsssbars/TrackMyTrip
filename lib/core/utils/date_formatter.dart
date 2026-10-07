import 'package:intl/intl.dart';

class DateFormatter {
  static String formatShortDate(DateTime date) {
    final local = date.isUtc ? date.toLocal() : date;
    return DateFormat('MMM d, y').format(local);
  }

  static String formatMonthYear(DateTime date) {
    final local = date.isUtc ? date.toLocal() : date;
    return DateFormat('MMMM yyyy').format(local);
  }

  static String formatDateTime(DateTime dateTime) {
    final local = dateTime.isUtc ? dateTime.toLocal() : dateTime;
    return DateFormat('MMM d, y • h:mm a').format(local);
  }

  static String formatDateTimeWithSeconds(DateTime dateTime) {
    final local = dateTime.isUtc ? dateTime.toLocal() : dateTime;
    return DateFormat('MMM d, y • h:mm:ss a').format(local);
  }

  static String formatTimeOnly(DateTime dateTime) {
    final local = dateTime.isUtc ? dateTime.toLocal() : dateTime;
    return DateFormat('h:mm a').format(local);
  }

  static String formatTimeWithSeconds(DateTime dateTime) {
    final local = dateTime.isUtc ? dateTime.toLocal() : dateTime;
    return DateFormat('h:mm:ss a').format(local);
  }

  static String formatDateAndTime(DateTime dateTime, {bool showYear = false}) {
    final local = dateTime.isUtc ? dateTime.toLocal() : dateTime;
    final now = DateTime.now();
    if (showYear || local.year != now.year) {
      return DateFormat('MMM d, y • h:mm a').format(local);
    }
    return DateFormat('MMM d • h:mm a').format(local);
  }

  /// Whole calendar-day difference (`now` minus `date`), immune to DST/hour drift.
  static int _calendarDayDiff(DateTime now, DateTime date) {
    final a = DateTime.utc(now.year, now.month, now.day);
    final b = DateTime.utc(date.year, date.month, date.day);
    return a.difference(b).inDays;
  }

  static String formatRelativeOrTime(DateTime dateTime, {DateTime? now}) {
    final ref = now ?? DateTime.now();
    final refLocal = ref.isUtc ? ref.toLocal() : ref;
    final local = dateTime.isUtc ? dateTime.toLocal() : dateTime;
    final dayDiff = _calendarDayDiff(refLocal, local);
    final time = DateFormat('h:mm a').format(local);

    if (dayDiff == 0) return 'Today at $time';
    if (dayDiff == 1) return 'Yesterday at $time';
    if (dayDiff == -1) return 'Tomorrow at $time';
    if (refLocal.year == local.year) return DateFormat('MMM d • h:mm a').format(local);
    return DateFormat('MMM d, y • h:mm a').format(local);
  }

  static String timeAgo(DateTime dateTime, {DateTime? now}) {
    final ref = now ?? DateTime.now();
    final refLocal = ref.isUtc ? ref.toLocal() : ref;
    final local = dateTime.isUtc ? dateTime.toLocal() : dateTime;
    final difference = refLocal.difference(local);

    // Future timestamps (clock skew): tolerate small drift, otherwise show the date.
    if (difference.isNegative) {
      return difference.inMinutes.abs() < 2 ? 'Just now' : DateFormat('MMM d').format(local);
    }
    if (difference.inSeconds < 45) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (refLocal.year == local.year) {
      return DateFormat('MMM d').format(local);
    }
    return DateFormat('MMM d, y').format(local);
  }

  static String formatDuration(Duration duration) {
    if (duration.isNegative || duration.inSeconds <= 0) return 'Just stopped';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m';
    }
    return '${seconds}s';
  }

  static String formatTripDateRange(DateTime start, DateTime end) {
    // Guard against swapped inputs from corrupted/legacy records.
    final s = start.isAfter(end) ? end : start;
    final e = start.isAfter(end) ? start : end;
    final startFmt = s.year == e.year
        ? DateFormat('MMM d').format(s)
        : DateFormat('MMM d, y').format(s);
    final endFmt = DateFormat('MMM d, y').format(e);
    return '$startFmt - $endFmt';
  }
}
