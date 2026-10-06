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
  static const String prefixZ1 = 'TRACKMYTRIP_Z1:';
  static const String prefixV1 = 'TRACKMYTRIP_V1:';
  static const String legacyPrefixZ1 = 'TRIPTRACKER_Z1:';
  static const String legacyPrefixV1 = 'TRIPTRACKER_V1:';

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

      // Check if GZIP compressed format (Z1 or legacy)
      final activeZ1Prefix = cleanInput.contains(prefixZ1)
          ? prefixZ1
          : (cleanInput.contains(legacyPrefixZ1) ? legacyPrefixZ1 : null);

      if (activeZ1Prefix != null) {
        final startIndex = cleanInput.indexOf(activeZ1Prefix) + activeZ1Prefix.length;
        final remaining = cleanInput.substring(startIndex).trim();
        final codePart = remaining.split(RegExp(r'\s+')).first;

        final bytes = base64Url.decode(codePart);
        final decompressed = const GZipDecoder().decodeBytes(bytes);
        final jsonStr = utf8.decode(decompressed);
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        return TripPackage.fromJson(map);
      }

      // Check if uncompressed format (V1 or legacy)
      final activeV1Prefix = cleanInput.contains(prefixV1)
          ? prefixV1
          : (cleanInput.contains(legacyPrefixV1) ? legacyPrefixV1 : null);

      if (activeV1Prefix != null) {
        final startIndex = cleanInput.indexOf(activeV1Prefix) + activeV1Prefix.length;
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

  /// Generates a comprehensive plain-text itinerary & expense report suitable for sharing or saving
  static String generateFullTripSummaryReport(TripPackage package) {
    final trip = package.trip;
    final totalSpent = package.expenses.fold<double>(0, (s, e) => s + e.totalAmount);
    final dates = DateFormatter.formatTripDateRange(trip.startDate, trip.endDate);
    final buf = StringBuffer();

    buf.writeln('========================================');
    buf.writeln('🌍 TRIP SUMMARY: ${trip.title.toUpperCase()}');
    buf.writeln('========================================');
    buf.writeln('📅 Dates: $dates');
    if (trip.description != null && trip.description!.isNotEmpty) {
      buf.writeln('📝 Overview: ${trip.description}');
    }
    buf.writeln('👥 Travelers (${trip.members.length}): ${trip.members.map((m) => m.name).join(', ')}');
    buf.writeln('💰 Total Expenditure: ${CurrencyFormatter.format(totalSpent, currency: trip.defaultCurrency)}');
    if (trip.budget != null) {
      buf.writeln('🎯 Budget: ${CurrencyFormatter.format(trip.budget!, currency: trip.defaultCurrency)} (${totalSpent <= trip.budget! ? "Within Budget" : "Over Budget"})');
    }
    buf.writeln('');

    // Itinerary & Stoppages
    buf.writeln('📍 ITINERARY & STOPPAGES (${package.stoppages.length})');
    buf.writeln('----------------------------------------');
    if (package.stoppages.isEmpty) {
      buf.writeln('No waypoints logged.');
    } else {
      for (int i = 0; i < package.stoppages.length; i++) {
        final s = package.stoppages[i];
        final timeStr = DateFormatter.formatDateTime(s.arrivedAt);
        buf.writeln('${i + 1}. ${s.name} [${s.category}]');
        buf.writeln('   🕒 Arrived: $timeStr');
        if (s.departedAt != null) {
          buf.writeln('   ⏱️ Duration: ${DateFormatter.formatDuration(s.duration ?? Duration.zero)}');
        }
        if (s.address != null && s.address!.isNotEmpty) {
          buf.writeln('   📌 Location: ${s.address}');
        }
        if (s.notes != null && s.notes!.isNotEmpty) {
          buf.writeln('   💡 Note: ${s.notes}');
        }
        buf.writeln('');
      }
    }

    // Expense Breakdown
    buf.writeln('💳 EXPENSES & BILLS (${package.expenses.length})');
    buf.writeln('----------------------------------------');
    if (package.expenses.isEmpty) {
      buf.writeln('No expenses recorded.');
    } else {
      final Map<String, double> catTotals = {};
      for (final e in package.expenses) {
        catTotals[e.category] = (catTotals[e.category] ?? 0.0) + e.totalAmount;
      }
      buf.writeln('Category Totals:');
      catTotals.forEach((cat, amt) {
        buf.writeln(' • $cat: ${CurrencyFormatter.format(amt, currency: trip.defaultCurrency)}');
      });
      buf.writeln('');
      buf.writeln('Recent Bills:');
      for (final e in package.expenses.take(15)) {
        final payer = trip.getMemberName(e.paidByMemberId);
        buf.writeln(' • ${e.title}: ${CurrencyFormatter.format(e.totalAmount, currency: e.currency)} (Paid by $payer)');
      }
      if (package.expenses.length > 15) {
        buf.writeln(' ... and ${package.expenses.length - 15} more bills');
      }
    }
    buf.writeln('');
    buf.writeln('----------------------------------------');
    buf.writeln('Generated via TrackMyTrip');
    return buf.toString();
  }

  static Future<void> shareFullTripSummary(TripPackage package) async {
    final text = generateFullTripSummaryReport(package);
    await Share.share(
      text,
      subject: 'Trip Summary: ${package.trip.title}',
    );
  }

  /// Copies the complete plain-text itinerary & expense report to the system clipboard.
  static Future<void> copyFullTripSummaryToClipboard(TripPackage package) async {
    final text = generateFullTripSummaryReport(package);
    await Clipboard.setData(ClipboardData(text: text));
  }

  /// Exports all trip expenses to standard RFC 4180 compliant CSV format
  static String generateExpensesCsv(Trip trip, List<Expense> expenses) {
    final buf = StringBuffer();
    buf.writeln('Date,Time,Title,Category,Amount,Currency,Paid By,Split Mode,Attendees,Notes');
    for (final e in expenses) {
      final dateStr = '${e.createdAt.year}-${e.createdAt.month.toString().padLeft(2, '0')}-${e.createdAt.day.toString().padLeft(2, '0')}';
      final timeStr = '${e.createdAt.hour.toString().padLeft(2, '0')}:${e.createdAt.minute.toString().padLeft(2, '0')}';
      final title = '"${e.title.replaceAll('"', '""')}"';
      final category = '"${e.category.replaceAll('"', '""')}"';
      final amount = e.totalAmount.toStringAsFixed(2);
      final currency = e.currency;
      final payerName = trip.getMemberName(e.paidByMemberId);
      final paidBy = '"${payerName.replaceAll('"', '""')}"';
      final splitMode = e.splitType.name;
      final attendeeNames = e.splits.map((s) => trip.getMemberName(s.memberId)).join('; ');
      final attendees = '"${attendeeNames.replaceAll('"', '""')}"';
      final notes = '"${(e.notes ?? '').replaceAll('"', '""')}"';
      buf.writeln('$dateStr,$timeStr,$title,$category,$amount,$currency,$paidBy,$splitMode,$attendees,$notes');
    }
    return buf.toString();
  }

  /// Shares the generated expenses CSV
  static Future<void> shareExpensesCsv(Trip trip, List<Expense> expenses) async {
    final csv = generateExpensesCsv(trip, expenses);
    await Share.share(
      csv,
      subject: 'Expenses CSV - ${trip.title}',
    );
  }

  // Loop 119: Markdown formatted travel itinerary & log exporter
  static String generateMarkdownItinerary(TripPackage package) {
    final trip = package.trip;
    final totalSpent = package.expenses.fold<double>(0.0, (s, e) => s + e.totalAmount);
    final dates = DateFormatter.formatTripDateRange(trip.startDate, trip.endDate);
    final buf = StringBuffer();

    buf.writeln('# 🗺️ ${trip.title}');
    buf.writeln('**Dates:** $dates  ');
    buf.writeln('**Total Spending:** ${CurrencyFormatter.format(totalSpent, currency: trip.defaultCurrency)}  ');
    if (trip.budget != null) {
      buf.writeln('**Trip Budget:** ${CurrencyFormatter.format(trip.budget!, currency: trip.defaultCurrency)}  ');
    }
    buf.writeln('**Travelers:** ${trip.members.map((m) => m.name).join(", ")}  \n');

    buf.writeln('## 📍 Stoppages & Itinerary');
    if (package.stoppages.isEmpty) {
      buf.writeln('*No waypoints logged.*\n');
    } else {
      for (int i = 0; i < package.stoppages.length; i++) {
        final s = package.stoppages[i];
        final timeStr = DateFormatter.formatDateTime(s.arrivedAt);
        buf.writeln('### ${i + 1}. ${s.name} (${s.category})');
        buf.writeln('- **Arrived:** $timeStr');
        if (s.departedAt != null) {
          buf.writeln('- **Stay Duration:** ${DateFormatter.formatDuration(s.duration ?? Duration.zero)}');
        }
        if (s.address != null && s.address!.isNotEmpty) {
          buf.writeln('- **Location:** ${s.address}');
        }
        if (s.notes != null && s.notes!.isNotEmpty) {
          buf.writeln('- **Notes:** ${s.notes}');
        }
        buf.writeln('');
      }
    }

    buf.writeln('## 💰 Financial Breakdown');
    if (package.expenses.isEmpty) {
      buf.writeln('*No expenses recorded.*\n');
    } else {
      buf.writeln('| Date | Title | Category | Paid By | Amount |');
      buf.writeln('| :--- | :--- | :--- | :--- | :--- |');
      for (final e in package.expenses) {
        final dStr = DateFormatter.formatShortDate(e.createdAt);
        final payer = trip.getMemberName(e.paidByMemberId);
        final amt = CurrencyFormatter.format(e.totalAmount, currency: e.currency);
        buf.writeln('| $dStr | ${e.title} | ${e.category} | $payer | $amt |');
      }
      buf.writeln('');
    }

    buf.writeln('---\n*Generated by TrackMyTrip*');
    return buf.toString();
  }

  static Future<void> shareMarkdownItinerary(TripPackage package) async {
    final md = generateMarkdownItinerary(package);
    await Share.share(
      md,
      subject: '${package.trip.title} - Travel Itinerary.md',
    );
  }

  /// Shares arbitrary text with an optional subject
  static Future<void> shareText(String text, {String? subject}) async {
    await Share.share(text, subject: subject);
  }
}
