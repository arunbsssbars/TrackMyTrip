import '../../models/proximity_alert.dart';

/// Utility to dynamically format notification titles and messages
/// from the perspective of the current user in their workspace (e.g. "You" instead of user name/email).
class NotificationFormatter {
  /// Formats the notification message to show "You" / "your" instead of user name or email
  static String formatMessage(
    ProximityAlert alert, {
    required String currentUserId,
    required String currentUserName,
    String? currentUserEmail,
    String? currentUsername,
  }) {
    final isSender = alert.senderMemberId == currentUserId || alert.isOutgoing;

    // Concise reassuring message for SOS sender
    if (alert.type == AlertType.sosEmergency && isSender) {
      return 'SOS broadcast sent • Location shared with companions';
    }

    final cleanName = currentUserName.trim();
    final cleanEmail = currentUserEmail?.trim();
    final cleanUsername = currentUsername?.trim();

    // Check if message references current user's name, email, or username
    final namesToReplace = <String>[];
    if (cleanName.isNotEmpty && cleanName.toLowerCase() != 'you') {
      namesToReplace.add(cleanName);
    }
    if (cleanEmail != null && cleanEmail.isNotEmpty) {
      namesToReplace.add(cleanEmail);
    }
    if (cleanUsername != null && cleanUsername.isNotEmpty && cleanUsername != 'traveler') {
      namesToReplace.add(cleanUsername);
      namesToReplace.add('@$cleanUsername');
    }

    String msg = alert.message;

    // Direct verb conjugation replacements when current user is the actor
    for (final name in namesToReplace) {
      final escapedName = RegExp.escape(name);

      // Sent invitation patterns (Requirement 11)
      msg = msg.replaceAll(RegExp('$escapedName sent an invitation to', caseSensitive: false), 'You sent an invitation to');
      msg = msg.replaceAll(RegExp('$escapedName sent invitation to', caseSensitive: false), 'You sent an invitation to');
      msg = msg.replaceAll(RegExp('$escapedName sent an invitation', caseSensitive: false), 'You sent an invitation');
      msg = msg.replaceAll(RegExp('$escapedName sent invitation', caseSensitive: false), 'You sent an invitation');
      msg = msg.replaceAll(RegExp('$escapedName sent an invite to', caseSensitive: false), 'You sent an invite to');
      msg = msg.replaceAll(RegExp('$escapedName sent invite to', caseSensitive: false), 'You sent an invite to');
      msg = msg.replaceAll(RegExp('$escapedName has invited', caseSensitive: false), 'You invited');
      msg = msg.replaceAll(RegExp('$escapedName invited', caseSensitive: false), 'You invited');

      // Activity action replacements
      msg = msg.replaceAll(RegExp('$escapedName has arrived', caseSensitive: false), 'You have arrived');
      msg = msg.replaceAll(RegExp('$escapedName is arrived', caseSensitive: false), 'You have arrived');
      msg = msg.replaceAll(RegExp('$escapedName is', caseSensitive: false), 'You are');
      msg = msg.replaceAll(RegExp('$escapedName joined', caseSensitive: false), 'You joined');
      msg = msg.replaceAll(RegExp('$escapedName left', caseSensitive: false), 'You left');
      msg = msg.replaceAll(RegExp('$escapedName added', caseSensitive: false), 'You added');
      msg = msg.replaceAll(RegExp('$escapedName recorded', caseSensitive: false), 'You recorded');
      msg = msg.replaceAll(RegExp('$escapedName triggered', caseSensitive: false), 'You triggered');
      msg = msg.replaceAll(RegExp('$escapedName accepted', caseSensitive: false), 'You accepted');
      msg = msg.replaceAll(RegExp('$escapedName declined', caseSensitive: false), 'You declined');
      msg = msg.replaceAll(RegExp('$escapedName departed', caseSensitive: false), 'You departed');
      msg = msg.replaceAll(RegExp('$escapedName updated', caseSensitive: false), 'You updated');
      msg = msg.replaceAll(RegExp('$escapedName created', caseSensitive: false), 'You created');
      msg = msg.replaceAll(RegExp('$escapedName shared', caseSensitive: false), 'You shared');
      msg = msg.replaceAll(RegExp('$escapedName reopened', caseSensitive: false), 'You reopened');

      // General fallback replace when this user is the sender
      if (isSender) {
        msg = msg.replaceAll(RegExp(r'\b' + escapedName + r'\b', caseSensitive: false), 'You');
      }
    }

    // Clean SOS phrasing: "SOS added" -> "SOS sent"
    msg = msg.replaceAll(RegExp(r'SOS added', caseSensitive: false), 'SOS sent');
    msg = msg.replaceAll(RegExp(r'added SOS', caseSensitive: false), 'sent SOS');
    msg = msg.replaceAll(RegExp(r'added stop "🚨 Emergency SOS[^"]*"', caseSensitive: false), 'sent SOS broadcast');
    msg = msg.replaceAll(RegExp(r'added stop "Emergency SOS[^"]*"', caseSensitive: false), 'sent SOS broadcast');

    return msg;
  }

  /// Formats the notification sender display name for the current workspace
  static String formatSenderName(
    ProximityAlert alert, {
    required String currentUserId,
    required String currentUserName,
  }) {
    if (alert.senderMemberId == currentUserId || alert.isOutgoing) {
      return 'You';
    }
    if (alert.senderName.trim().toLowerCase() == currentUserName.trim().toLowerCase()) {
      return 'You';
    }
    return alert.senderName;
  }

  /// Formats the notification title (e.g. customized for SOS sender and clean concise labels)
  static String formatTitle(
    ProximityAlert alert, {
    required String currentUserId,
  }) {
    String title = alert.title.trim();
    // Strip redundant leading "New " / "new "
    if (title.startsWith(RegExp(r'^New\s+', caseSensitive: false))) {
      title = title.replaceFirst(RegExp(r'^New\s+', caseSensitive: false), '').trim();
    }

    final lower = title.toLowerCase();
    if (lower == 'sos added' ||
        lower == 'emergency sos added' ||
        lower == 'sos sent' ||
        lower.contains('sos added')) {
      return 'SOS Sent';
    }

    final isSender = alert.senderMemberId == currentUserId || alert.isOutgoing;
    if (alert.type == AlertType.sosEmergency && isSender) {
      return '🚨 SOS Distress Active';
    }
    if (lower == 'waypoint added' ||
        lower == 'stoppage added' ||
        lower == 'stoppages added' ||
        lower == 'stopages added' ||
        lower == 'stop added') {
      return 'Stop Added';
    }
    if (lower == 'photo added' ||
        lower == 'memory added') {
      return 'Memory Added';
    }
    if (lower == 'expense added' ||
        lower == 'bill added') {
      return 'Bill Added';
    }

    return title;
  }
}
