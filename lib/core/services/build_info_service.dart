import 'package:flutter/foundation.dart';
import 'secret_config_service.dart';

/// Provides build-time metadata, Git commit tracking, and CI/CD runner telemetry.
class BuildInfoService {
  // Compile-time environment constants (injected via --dart-define or CI)
  static const String keyBuildNumber = 'BUILD_NUMBER';
  static const String keyCommitHash = 'GIT_COMMIT_HASH';
  static const String keyBuildTimestamp = 'BUILD_TIMESTAMP';
  static const String keyGitBranch = 'GIT_BRANCH';

  static const String defaultVersion = '1.0.0';
  static const String defaultBuildNumber = '1';

  /// Semantic version string (e.g. "1.0.0")
  static String get appVersion => defaultVersion;

  /// CI/CD or local build number
  static String get buildNumber {
    final fromEnv = SecretConfigService.get(keyBuildNumber);
    if (fromEnv.isNotEmpty) return fromEnv;
    const compileTime = String.fromEnvironment(keyBuildNumber, defaultValue: '');
    return compileTime.isNotEmpty ? compileTime : defaultBuildNumber;
  }

  /// Short or full Git commit hash from CI build
  static String get commitHash {
    final fromEnv = SecretConfigService.get(keyCommitHash);
    if (fromEnv.isNotEmpty) return fromEnv;
    const compileTime = String.fromEnvironment(keyCommitHash, defaultValue: '');
    return compileTime.isNotEmpty ? compileTime : (kDebugMode ? 'dev-local' : 'release');
  }

  /// Branch name from CI runner
  static String get gitBranch {
    final fromEnv = SecretConfigService.get(keyGitBranch);
    if (fromEnv.isNotEmpty) return fromEnv;
    const compileTime = String.fromEnvironment(keyGitBranch, defaultValue: '');
    return compileTime.isNotEmpty ? compileTime : 'main';
  }

  /// Timestamp when the binary was compiled in CI
  static String get buildTimestamp {
    final fromEnv = SecretConfigService.get(keyBuildTimestamp);
    if (fromEnv.isNotEmpty) return fromEnv;
    const compileTime = String.fromEnvironment(keyBuildTimestamp, defaultValue: '');
    return compileTime.isNotEmpty ? compileTime : '2026-10-09';
  }

  /// Formatted full version string: e.g. "v1.0.0+1 (commit 784cbed)"
  static String get formattedVersion {
    final shortHash = commitHash.length > 7 ? commitHash.substring(0, 7) : commitHash;
    return 'v$appVersion+$buildNumber ($shortHash)';
  }

  /// Structured diagnostic map for Super Admin & telemetry
  static Map<String, dynamic> getDiagnosticMap() {
    return {
      'appVersion': appVersion,
      'buildNumber': buildNumber,
      'commitHash': commitHash,
      'gitBranch': gitBranch,
      'buildTimestamp': buildTimestamp,
      'formattedVersion': formattedVersion,
      'environment': SecretConfigService.appEnv,
      'ciRunnerId': SecretConfigService.ciRunnerId,
      'isRelease': kReleaseMode,
    };
  }
}
