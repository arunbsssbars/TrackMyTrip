#!/usr/bin/env bash
# =================================================================
# TrackMyTrip - Release Binary & Bundle Size Budget Guard for Linux/macOS
# =================================================================
set -e

FILE_PATH=${1:-"build/app/outputs/flutter-apk/app-release.apk"}
MAX_MB=${2:-50.0}

echo "=========================================="
echo " TrackMyTrip CI/CD Bundle Size Analyzer   "
echo "=========================================="

if [ ! -f "$FILE_PATH" ]; then
    echo "NOTICE: Binary file not found at $FILE_PATH (skipped in non-build context)."
    exit 0
fi

BYTES=$(wc -c < "$FILE_PATH" | tr -d ' ')
SIZE_MB=$(awk "BEGIN {printf \"%.2f\", $BYTES / 1048576}")

echo "Binary File   : $(basename "$FILE_PATH")"
echo "Size (MB)     : $SIZE_MB MB"
echo "Budget Limit  : $MAX_MB MB"

IS_VALID=$(awk "BEGIN {print ($SIZE_MB <= $MAX_MB) ? 1 : 0}")

if [ "$IS_VALID" -eq 1 ]; then
    echo "SUCCESS: Binary size is within budget ($SIZE_MB MB <= $MAX_MB MB)."
    exit 0
else
    echo "ERROR: Binary size exceeds budget limit ($SIZE_MB MB > $MAX_MB MB)!"
    exit 1
fi
