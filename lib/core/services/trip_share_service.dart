import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/expense.dart';
import '../../models/memory.dart';
import '../../models/settlement.dart';
import '../../models/stoppage.dart';
import '../../models/trip.dart';
import '../../models/trip_audit_log.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_formatter.dart';
import 'cloud_trip_sync_service.dart';

class TripPackage {
  final Trip trip;
  final List<Stoppage> stoppages;
  final List<Expense> expenses;
  final List<Memory> memories;
  final List<Settlement> settlements;
  final List<TripAuditLog> auditLogs;
  final DateTime exportedAt;

  TripPackage({
    required this.trip,
    required this.stoppages,
    required this.expenses,
    required this.memories,
    required this.settlements,
    List<TripAuditLog>? auditLogs,
    DateTime? exportedAt,
  })  : auditLogs = auditLogs ?? [],
        exportedAt = exportedAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'v': 1,
      'exportedAt': exportedAt.toIso8601String(),
      'trip': trip.toJson(),
      'stoppages': stoppages.map((s) => s.toJson()).toList(),
      'expenses': expenses.map((e) => e.toJson()).toList(),
      'memories': memories.map((m) => m.toJson()).toList(),
      'settlements': settlements.map((s) => s.toJson()).toList(),
      'auditLogs': auditLogs.map((a) => a.toJson()).toList(),
    };
  }

  factory TripPackage.fromJson(Map<String, dynamic> json) {
    final tripMap = json['trip'] as Map<String, dynamic>;
    final trip = Trip.fromJson(tripMap);

    final stoppagesList = (json['stoppages'] as List<dynamic>?)
            ?.map((e) => Stoppage.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final expensesList = (json['expenses'] as List<dynamic>?)
            ?.map((e) => Expense.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final memoriesList = (json['memories'] as List<dynamic>?)
            ?.map((e) => Memory.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final settlementsList = (json['settlements'] as List<dynamic>?)
            ?.map((e) => Settlement.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final auditLogsList = (json['auditLogs'] as List<dynamic>?)
            ?.map((e) => TripAuditLog.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final exportedAtStr = json['exportedAt'] as String?;
    final exportedAt = exportedAtStr != null
        ? DateTime.tryParse(exportedAtStr) ?? DateTime.now()
        : DateTime.now();

    return TripPackage(
      trip: trip,
      stoppages: stoppagesList,
      expenses: expensesList,
      memories: memoriesList,
      settlements: settlementsList,
      auditLogs: auditLogsList,
      exportedAt: exportedAt,
    );
  }
}

class TripShareService {
  static const String prefixZ1 = 'TRIPTRACKER_Z1:';
  static const String prefixV1 = 'TRIPTRACKER_V1:';

  /// Encodes package into a lightweight, high-speed compressed QR payload.
  static String encodePackage(TripPackage package) {
    try {
      final jsonStr = jsonEncode(package.toJson());
      final utf8Bytes = utf8.encode(jsonStr);
      final compressed = const GZipEncoder().encode(utf8Bytes);
      final base64Str = base64Url.encode(compressed);
      return '$prefixZ1$base64Str';
    } catch (_) {}

    // Fallback to uncompressed Base64
    final jsonStr = jsonEncode(package.toJson());
    final bytes = utf8.encode(jsonStr);
    return '$prefixV1${base64Url.encode(bytes)}';
  }

  /// Decodes and validates any raw input string (QR code, text, base64, GZIP, JSON).
  static TripPackage? decodePackage(String rawInput) {
    try {
      String cleanInput = rawInput.trim();

      // Check if GZIP compressed format (Z1)
      if (cleanInput.contains(prefixZ1)) {
        final startIndex = cleanInput.indexOf(prefixZ1) + prefixZ1.length;
        final remaining = cleanInput.substring(startIndex).trim();
        final codePart = remaining.split(RegExp(r'\s+')).first;

        final bytes = base64Url.decode(codePart);
        final decompressed = const GZipDecoder().decodeBytes(bytes);
        final jsonStr = utf8.decode(decompressed);
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        return TripPackage.fromJson(map);
      }

      // Check if legacy uncompressed format (V1)
      if (cleanInput.contains(prefixV1)) {
        final startIndex = cleanInput.indexOf(prefixV1) + prefixV1.length;
        final remaining = cleanInput.substring(startIndex).trim();
        final codePart = remaining.split(RegExp(r'\s+')).first;

        List<int> bytes;
        try {
          bytes = base64Url.decode(codePart);
        } catch (_) {
          bytes = base64.decode(codePart);
        }

        final jsonStr = utf8.decode(bytes);
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        return TripPackage.fromJson(map);
      }

      // Direct JSON format
      if (cleanInput.startsWith('{') && cleanInput.endsWith('}')) {
        final map = jsonDecode(cleanInput) as Map<String, dynamic>;
        return TripPackage.fromJson(map);
      }

      // Try raw GZIP base64
      try {
        final bytes = base64Url.decode(cleanInput);
        final decompressed = const GZipDecoder().decodeBytes(bytes);
        final jsonStr = utf8.decode(decompressed);
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        return TripPackage.fromJson(map);
      } catch (_) {}

      // Try raw base64 JSON
      try {
        final bytes = base64Url.decode(cleanInput);
        final jsonStr = utf8.decode(bytes);
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        return TripPackage.fromJson(map);
      } catch (_) {}

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Generates friendly invitation text for messaging apps with Live Cloud Code.
  static String generateShareMessage(TripPackage package, {String? senderName}) {
    final trip = package.trip;
    final totalSpent = package.expenses.fold<double>(0, (s, e) => s + e.totalAmount);
    final membersList = trip.members.map((m) => m.name).join(', ');
    final dates = DateFormatter.formatTripDateRange(trip.startDate, trip.endDate);
    final roomCode = CloudTripSyncService.getRoomCode(trip.id, trip: trip);

    return '''
🚗 You're invited to join "${trip.title}"!
${senderName != null ? 'Shared by: $senderName\n' : ''}
📅 Dates: $dates
👥 Travelers: $membersList
📍 Stops: ${package.stoppages.length} stops recorded
💰 Total Bills: ${CurrencyFormatter.format(totalSpent, currency: trip.defaultCurrency)}

🔑 Live Join Code: $roomCode

📲 How to join:
1. Open Track My Trip App
2. Tap "Join Trip" and enter code: $roomCode (or scan QR in the app)
''';
  }

  static Future<void> shareTrip(TripPackage package, {String? senderName}) async {
    final text = generateShareMessage(package, senderName: senderName);
    await Share.share(
      text,
      subject: 'Trip Invite: ${package.trip.title}',
    );
  }

  static Future<void> copyCodeToClipboard(TripPackage package) async {
    final roomCode = CloudTripSyncService.getRoomCode(package.trip.id, trip: package.trip);
    await Clipboard.setData(ClipboardData(text: roomCode));
  }
}
