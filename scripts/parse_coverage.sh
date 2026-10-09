#!/usr/bin/env bash
# =================================================================
# TrackMyTrip - LCOV Code Coverage Parser for Linux/macOS CI Runners
# =================================================================
set -e

MIN_PERCENT=${1:-50.0}
LCOV_PATH=${2:-"coverage/lcov.info"}

echo "=========================================="
echo " TrackMyTrip CI/CD Code Coverage Analyzer "
echo "=========================================="

if [ ! -f "$LCOV_PATH" ]; then
    echo "NOTICE: Coverage file not found at $LCOV_PATH."
    exit 0
fi

TOTAL_LINES=0
COVERED_LINES=0

while IFS= read -r line; do
    if [[ $line =~ ^LF:([0-9]+) ]]; then
        TOTAL_LINES=$((TOTAL_LINES + BASH_REMATCH[1]))
    elif [[ $line =~ ^LH:([0-9]+) ]]; then
        COVERED_LINES=$((COVERED_LINES + BASH_REMATCH[1]))
    fi
done < "$LCOV_PATH"

if [ "$TOTAL_LINES" -eq 0 ]; then
    echo "NOTICE: No instrumented lines found."
    exit 0
fi

PERCENT=$(awk "BEGIN {printf \"%.2f\", ($COVERED_LINES / $TOTAL_LINES) * 100}")
echo "Instrumented Lines : $TOTAL_LINES"
echo "Covered Lines      : $COVERED_LINES"
echo "Total Coverage     : $PERCENT%"

echo "Code coverage parsed successfully."
