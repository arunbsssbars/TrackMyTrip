import 'dart:io';

/// CI Execution Summary produced by [AqilCiGuardian].
class CiAuditSummary {
  final String projectName;
  final bool passed;
  final int totalTests;
  final int failedTests;
  final Duration executionTime;

  const CiAuditSummary({
    required this.projectName,
    required this.passed,
    required this.totalTests,
    required this.failedTests,
    required this.executionTime,
  });

  Map<String, dynamic> toJson() => {
        'projectName': projectName,
        'passed': passed,
        'totalTests': totalTests,
        'failedTests': failedTests,
        'durationMs': executionTime.inMilliseconds,
      };
}

/// Pre-Commit & Continuous Integration Pipeline Guardian (AQIL Frontier 4).
///
/// Configures automated Git pre-commit hooks and GitHub Actions workflows
/// to block commits or PRs that introduce layout overflows or accessibility failures.
class AqilCiGuardian {
  /// Installs Git pre-commit hook into target repository.
  static bool installGitHook(String repoPath) {
    final hookDir = Directory('$repoPath/.git/hooks');
    if (!hookDir.existsSync()) {
      return false; // Not a git root or hooks disabled
    }

    final hookFile = File('${hookDir.path}/pre-commit');
    const hookContent = '''#!/bin/sh
# AQIL Universal Git Pre-Commit Hook
# Single Source of Truth: D:/Program/Antigravity/aqil_core_v10

echo "⚡ [AQIL] Running pre-commit UI anti-overflow and static quality gate..."
dart run aqil_core:aqil audit --target .
EXIT_CODE=\$?

if [ \$EXIT_CODE -ne 0 ]; then
  echo "❌ [AQIL Gate] Commits blocked due to unresolved UI debt or layout violations."
  exit \$EXIT_CODE
fi

echo "✓ [AQIL Gate] All pre-commit quality checks passed cleanly."
exit 0
''';

    hookFile.writeAsStringSync(hookContent);
    return true;
  }

  /// Synthesizes GitHub Actions CI workflow file.
  static File generateGitHubWorkflow(String repoPath) {
    final workflowDir = Directory('$repoPath/.github/workflows');
    if (!workflowDir.existsSync()) {
      workflowDir.createSync(recursive: true);
    }

    final workflowFile = File('${workflowDir.path}/aqil_guardian.yml');
    const workflowContent = '''name: AQIL Quality Guardian

on:
  push:
    branches: [ main, master, develop ]
  pull_request:
    branches: [ main, master ]

jobs:
  aqil-ui-gate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Flutter SDK
        uses: subosito/flutter-action@v2
        with:
          channel: 'stable'
          cache: true

      - name: Install Dependencies
        run: flutter pub get

      - name: Run AQIL Multi-Viewport Quality Gate
        run: flutter test test/aqil_ui_pipeline_test.dart
''';

    workflowFile.writeAsStringSync(workflowContent);
    return workflowFile;
  }
}
