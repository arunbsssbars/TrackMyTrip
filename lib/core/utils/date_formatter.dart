import 'package:intl/intl.dart';

class DateFormatter {
  static String formatShortDate(DateTime date) {
    return DateFormat('MMM d, y').format(date);
  }

  static String formatMonthYear(DateTime date) {
    return DateFormat('MMMM yyyy').format(date);
  }

  static String formatDateTime(DateTime dateTime) {
    return DateFormat('MMM d, y • h:mm a').format(dateTime);
  }

  static String formatDateTimeWithSeconds(DateTime dateTime) {
    return DateFormat('MMM d, y • h:mm:ss a').format(dateTime);
  }

  static String formatTimeOnly(DateTime dateTime) {
    return DateFormat('h:mm a').format(dateTime);
  }

  static String formatTimeWithSeconds(DateTime dateTime) {
    return DateFormat('h:mm:ss a').format(dateTime);
  }

  static String formatRelativeOrTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0 && now.day == dateTime.day) {
      return 'Today at ${DateFormat('h:mm a').format(dateTime)}';
    } else if (difference.inDays == 1 || (difference.inDays == 0 && now.day != dateTime.day)) {
      return 'Yesterday at ${DateFormat('h:mm a').format(dateTime)}';
    } else if (now.year == dateTime.year) {
      return DateFormat('MMM d • h:mm a').format(dateTime);
    } else {
      return DateFormat('MMM d, y • h:mm a').format(dateTime);
    }
  }

  static String timeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 45) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(dateTime);
    }
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
    final startFmt = DateFormat('MMM d').format(start);
    final endFmt = DateFormat('MMM d, y').format(end);
    return '$startFmt - $endFmt';
  }
}
