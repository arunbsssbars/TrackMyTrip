#!/usr/bin/env bash
set -e

echo "=========================================="
echo "   TrackMyTrip DevOps Pre-Push Quality Gate"
echo "=========================================="

echo -e "\n[1/4] Running Static Analysis & Lint..."
flutter analyze lib --fatal-infos
echo "✓ Static analysis passed (0 issues)."

echo -e "\n[2/4] Running Super Admin & Resilience Tests..."
flutter test test/super_admin_test.dart test/twenty_loop_features_resilience_test.dart
echo "✓ Core unit tests passed."

echo -e "\n[3/4] Running DevOps Telemetry & Schema Verification Tests..."
flutter test test/devops_pipeline_and_admin_telemetry_test.dart
echo "✓ DevOps telemetry tests passed."

echo -e "\n[4/4] Auditing Tracked Files for Secrets..."
SUSPICIOUS=$(git ls-files | grep -E '(\.env$|\.env\.production$|key\.properties$|\.jks$|\.keystore$|google-services\.json\.secret)' || true)
if [ -n "$SUSPICIOUS" ]; then
    echo "ERROR: Sensitive secrets found tracked in Git!"
    echo "$SUSPICIOUS"
    exit 1
else
    echo "✓ Zero sensitive files detected in Git."
fi

echo -e "\n=========================================="
echo "✓ All DevOps Pre-Push Gates Passed!"
echo "  Ready to commit and push to GitHub."
echo "=========================================="
