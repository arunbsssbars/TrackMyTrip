import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../models/trip_archive_bundle.dart';

class TripArchiveValidationResult {
  final bool isValid;
  final String? errorMessage;
  final TripArchiveBundle? bundle;

  const TripArchiveValidationResult({
    required this.isValid,
    this.errorMessage,
    this.bundle,
  });
}

class TripArchiveService {
  static final TripArchiveService _instance = TripArchiveService._internal();
  factory TripArchiveService() => _instance;
  TripArchiveService._internal();

  /// Computes a canonical SHA-256 hash for raw string payload
  String computeChecksum(String content) {
    final bytes = utf8.encode(content);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Packages a complete trip into an archive bundle with cryptographic integrity
  TripArchiveBundle createArchive({
    required String tripId,
    required String tripTitle,
    required Map<String, dynamic> tripData,
    List<Map<String, dynamic>> stoppages = const [],
    List<Map<String, dynamic>> expenses = const [],
    List<Map<String, dynamic>> packingItems = const [],
    DateTime? exportedAt,
  }) {
    final timestamp = exportedAt ?? DateTime.now();

    final payloadMap = {
      'version': '1.0',
      'tripId': tripId,
      'tripTitle': tripTitle,
      'exportedAt': timestamp.toIso8601String(),
      'tripData': tripData,
      'stoppages': stoppages,
      'expenses': expenses,
      'packingItems': packingItems,
    };

    final canonicalJson = jsonEncode(payloadMap);
    final checksum = computeChecksum(canonicalJson);

    return TripArchiveBundle(
      version: '1.0',
      tripId: tripId,
      tripTitle: tripTitle,
      exportedAt: timestamp,
      tripData: tripData,
      stoppages: stoppages,
      expenses: expenses,
      packingItems: packingItems,
      checksumSha256: checksum,
    );
  }

  /// Serializes archive bundle to `.tmt` file string
  String exportToArchiveString(TripArchiveBundle bundle) {
    return const JsonEncoder.withIndent('  ').convert(bundle.toJson());
  }

  /// Verifies the cryptographic integrity of a `.tmt` archive string and extracts bundle
  TripArchiveValidationResult verifyAndParseArchive(String rawJsonContent) {
    try {
      final decoded = jsonDecode(rawJsonContent);
      if (decoded is! Map<String, dynamic>) {
        return const TripArchiveValidationResult(
          isValid: false,
          errorMessage: 'Invalid archive: Root element must be a JSON object.',
        );
      }

      final declaredChecksum = decoded['checksumSha256'] as String?;
      if (declaredChecksum == null || declaredChecksum.isEmpty) {
        return const TripArchiveValidationResult(
          isValid: false,
          errorMessage: 'Corrupted archive: Missing cryptographic SHA-256 checksum.',
        );
      }

      // Reconstruct payload without checksum to re-verify integrity
      final payloadMap = {
        'version': decoded['version'] ?? '1.0',
        'tripId': decoded['tripId'] ?? '',
        'tripTitle': decoded['tripTitle'] ?? '',
        'exportedAt': decoded['exportedAt'] ?? '',
        'tripData': decoded['tripData'] ?? {},
        'stoppages': decoded['stoppages'] ?? [],
        'expenses': decoded['expenses'] ?? [],
        'packingItems': decoded['packingItems'] ?? [],
      };

      final canonicalJson = jsonEncode(payloadMap);
      final calculatedChecksum = computeChecksum(canonicalJson);

      if (calculatedChecksum != declaredChecksum) {
        return const TripArchiveValidationResult(
          isValid: false,
          errorMessage:
              'Security Alert: SHA-256 Checksum mismatch! Data tampering or file corruption detected.',
        );
      }

      final bundle = TripArchiveBundle.fromJson(decoded);
      return TripArchiveValidationResult(
        isValid: true,
        bundle: bundle,
      );
    } catch (e) {
      return TripArchiveValidationResult(
        isValid: false,
        errorMessage: 'Failed to parse archive file: $e',
      );
    }
  }
}
