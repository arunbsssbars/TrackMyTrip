import 'dart:convert';
import 'ui_test_helper.dart';

/// Severity level for CI/CD annotations.
enum CiAnnotationLevel {
  notice,
  warning,
  failure,
}

/// An inline code annotation for GitHub / GitLab / Bitbucket pull requests.
class CiCodeAnnotation {
  final String path;
  final int startLine;
  final int endLine;
  final CiAnnotationLevel level;
  final String title;
  final String message;
  final String? rawDetails;

  const CiCodeAnnotation({
    required this.path,
    required this.startLine,
    required this.endLine,
    required this.level,
    required this.title,
    required this.message,
    this.rawDetails,
  });

  /// Formats into GitHub Actions workflow command syntax: `::error file={name},line={line}::{message}`
  String toGithubWorkflowCommand() {
    final cmd = level == CiAnnotationLevel.failure
        ? 'error'
        : (level == CiAnnotationLevel.warning ? 'warning' : 'notice');
    return '::$cmd file=$path,line=$startLine,endLine=$endLine,title=$title::$message';
  }

  /// Formats into GitHub REST API Check Run Annotation JSON schema.
  Map<String, dynamic> toGithubCheckRunJson() {
    return {
      'path': path,
      'start_line': startLine,
      'end_line': endLine,
      'annotation_level': level == CiAnnotationLevel.failure
          ? 'failure'
          : (level == CiAnnotationLevel.warning ? 'warning' : 'notice'),
      'title': title,
      'message': message,
      if (rawDetails != null) 'raw_details': rawDetails,
    };
  }

  /// Formats into GitLab Code Quality Issue schema.
  Map<String, dynamic> toGitlabCodeQualityJson() {
    return {
      'description': '$title: $message',
      'check_name': 'aqil_ui_quality',
      'fingerprint': '${path}_${startLine}_${title.hashCode}',
      'severity': level == CiAnnotationLevel.failure
          ? 'critical'
          : (level == CiAnnotationLevel.warning ? 'major' : 'minor'),
      'location': {
        'path': path,
        'lines': {
          'begin': startLine,
          'end': endLine,
        },
      },
    };
  }
}

/// Headless CI/CD Bot with Automated Pull-Request Annotations (AQIL Frontier 4).
///
/// Converts AQIL audit results, quality scorecards, and self-healing recommendations
/// into rich GitHub/GitLab PR comments, inline check-run annotations, and CI status checks.
class AqilCiCdBot {
  /// Evaluates whether the CI pipeline should pass or fail based on score threshold and critical bugs.
  static bool evaluateCiExitCode({
    required AqilQualityScorecard scorecard,
    double minPassingScore = 80.0,
    bool failOnAnyOverflow = true,
  }) {
    if (scorecard.complianceScore < minPassingScore) {
      return false;
    }
    if (failOnAnyOverflow &&
        scorecard.violations.any((v) => v.toLowerCase().contains('overflow'))) {
      return false;
    }
    return true;
  }

  /// Generates a GitHub/GitLab pull request Markdown summary comment.
  static String formatPullRequestComment({
    required AqilQualityScorecard scorecard,
    required String commitSha,
    required String branchName,
    List<RemediationPatch> recommendedPatches = const [],
  }) {
    final buffer = StringBuffer();
    final badgeColor = scorecard.grade == 'A+' || scorecard.grade == 'A'
        ? 'brightgreen'
        : (scorecard.grade == 'B' ? 'yellow' : 'red');

    buffer.writeln('## 🤖 AQIL Autonomous UI Quality Bot');
    buffer.writeln(
        '[![AQIL Score](https://img.shields.io/badge/AQIL%20Quality-${scorecard.grade}%20(${scorecard.complianceScore.toInt()}pts)-$badgeColor)](#)');
    buffer.writeln();
    buffer.writeln('| Metric | Result |');
    buffer.writeln('| :--- | :--- |');
    buffer.writeln('| **Target** | `${scorecard.targetName}` |');
    buffer.writeln('| **Branch / Commit** | `$branchName` (`${commitSha.take(7)}`) |');
    buffer.writeln('| **Overall Grade** | **${scorecard.grade}** (${scorecard.complianceScore.toStringAsFixed(1)} / 100) |');
    buffer.writeln('| **Pillars Verified** | ${scorecard.passedPillars.length} Passed |');
    buffer.writeln('| **Violations Detected** | ${scorecard.violations.length} |');
    buffer.writeln();

    if (scorecard.passedPillars.isNotEmpty) {
      buffer.writeln('<details><summary><b>✅ Passed Verification Pillars (${scorecard.passedPillars.length})</b></summary>');
      buffer.writeln();
      for (final pillar in scorecard.passedPillars) {
        buffer.writeln('- :white_check_mark: $pillar');
      }
      buffer.writeln('</details>');
      buffer.writeln();
    }

    if (scorecard.violations.isNotEmpty) {
      buffer.writeln('### ⚠️ UI Quality Warnings & Violations');
      for (final v in scorecard.violations) {
        buffer.writeln('- :x: `$v`');
      }
      buffer.writeln();
    }

    if (recommendedPatches.isNotEmpty) {
      buffer.writeln('### 🩹 Suggested Autonomous AST Fixes (${recommendedPatches.length})');
      buffer.writeln('The following surgical AST patches can be applied automatically:');
      buffer.writeln();
      for (int i = 0; i < recommendedPatches.length; i++) {
        final patch = recommendedPatches[i];
        buffer.writeln('<details><summary><b>Patch ${i + 1}: ${patch.description}</b> (Confidence: ${(patch.confidence * 100).toInt()}%)</summary>');
        buffer.writeln();
        buffer.writeln('```diff');
        buffer.writeln('- ${patch.originalSnippet}');
        buffer.writeln('+ ${patch.replacementSnippet}');
        buffer.writeln('```');
        buffer.writeln('</details>');
        buffer.writeln();
      }
    }

    buffer.writeln('---');
    buffer.writeln('*Report generated autonomously by AQIL v5 Universal Engine.*');

    return buffer.toString();
  }

  /// Converts scorecard violations into GitHub Check Run / Workflow annotations.
  static List<CiCodeAnnotation> generateAnnotations({
    required AqilQualityScorecard scorecard,
    required String filePath,
  }) {
    final annotations = <CiCodeAnnotation>[];

    for (int i = 0; i < scorecard.violations.length; i++) {
      final violation = scorecard.violations[i];
      final isOverflow = violation.toLowerCase().contains('overflow');
      final isContrast = violation.toLowerCase().contains('contrast');

      annotations.add(CiCodeAnnotation(
        path: filePath,
        startLine: 1, // Default or anchor line
        endLine: 1,
        level: isOverflow ? CiAnnotationLevel.failure : CiAnnotationLevel.warning,
        title: isOverflow
            ? 'RenderFlex Layout Overflow'
            : (isContrast ? 'WCAG 2.2 Contrast Ratio Violation' : 'AQIL Quality Warning'),
        message: violation,
      ));
    }

    return annotations;
  }

  /// Exports an array of annotations to GitLab Code Quality JSON report string.
  static String exportGitlabCodeQualityReport(List<CiCodeAnnotation> annotations) {
    final issues = annotations.map((a) => a.toGitlabCodeQualityJson()).toList();
    return const JsonEncoder.withIndent('  ').convert(issues);
  }
}

extension on String {
  String take(int n) => length <= n ? this : substring(0, n);
}
