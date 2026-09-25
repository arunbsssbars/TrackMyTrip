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
    String msg = alert.message;

    final isSender = alert.senderMemberId == currentUserId || alert.isOutgoing;
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

      // General fallback replace when this user is the sender
      if (isSender) {
        msg = msg.replaceAll(RegExp(r'\b' + escapedName + r'\b', caseSensitive: false), 'You');
      }
    }

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
}
