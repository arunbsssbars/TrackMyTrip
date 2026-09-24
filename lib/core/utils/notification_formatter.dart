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
      // e.g. "Arun has arrived at ..." -> "You have arrived at ..."
      msg = msg.replaceAll('$name has arrived', 'You have arrived');
      msg = msg.replaceAll('$name is arrived', 'You have arrived');
      msg = msg.replaceAll('$name is', 'You are');
      msg = msg.replaceAll('$name joined', 'You joined');
      msg = msg.replaceAll('$name left', 'You left');
      msg = msg.replaceAll('$name added', 'You added');
      msg = msg.replaceAll('$name recorded', 'You recorded');
      msg = msg.replaceAll('$name triggered', 'You triggered');
      msg = msg.replaceAll('$name accepted', 'You accepted');
      msg = msg.replaceAll('$name declined', 'You declined');
      msg = msg.replaceAll('$name departed', 'You departed');
      msg = msg.replaceAll('$name updated', 'You updated');
      msg = msg.replaceAll('$name invited', 'You invited');

      // General fallback replace
      if (isSender) {
        msg = msg.replaceAll(name, 'You');
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
