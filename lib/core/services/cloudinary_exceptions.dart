/// Structured exception taxonomy for Cloudinary cloud media operations.
abstract class CloudinaryException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic originalError;

  const CloudinaryException(this.message, {this.statusCode, this.originalError});

  @override
  String toString() => '$runtimeType: $message${statusCode != null ? " (Status $statusCode)" : ""}';
}

/// Loop 1: Network connectivity or timeout failures during transfer.
class CloudinaryNetworkException extends CloudinaryException {
  const CloudinaryNetworkException(super.message, {super.statusCode, super.originalError});
}

/// Loop 2: Authentication, authorization, or invalid credentials (401/403).
class CloudinaryAuthException extends CloudinaryException {
  const CloudinaryAuthException(super.message, {super.statusCode, super.originalError});
}

/// Loop 2: Bad request or unsupported parameters (400).
class CloudinaryBadRequestException extends CloudinaryException {
  const CloudinaryBadRequestException(super.message, {super.statusCode, super.originalError});
}

/// Loop 2: Resource not found (404). Note: On deletion, this is often treated as success.
class CloudinaryNotFoundException extends CloudinaryException {
  const CloudinaryNotFoundException(super.message, {super.statusCode, super.originalError});
}

/// Loop 3: Free-tier 25 GB quota reached or billing bounds exceeded.
class CloudinaryQuotaException extends CloudinaryException {
  const CloudinaryQuotaException(super.message, {super.statusCode, super.originalError});
}

/// Loop 3: Cloudinary API rate limit exceeded (420 / 429).
class CloudinaryRateLimitException extends CloudinaryException {
  final Duration? retryAfter;

  const CloudinaryRateLimitException(
    super.message, {
    this.retryAfter,
    super.statusCode,
    super.originalError,
  });
}

/// Loop 4: Malformed, corrupt, oversized, or unreadable media bytes.
class CloudinaryInvalidMediaException extends CloudinaryException {
  const CloudinaryInvalidMediaException(super.message, {super.statusCode, super.originalError});
}

/// Loop 5: Asset deletion failed or delete_token expired.
class CloudinaryDeletionException extends CloudinaryException {
  const CloudinaryDeletionException(super.message, {super.statusCode, super.originalError});
}
