#!/usr/bin/env bash
# =================================================================
# TrackMyTrip - Post-Deployment CI/CD Canary Health Check for Linux
# =================================================================
set -e

echo "=========================================="
echo " TrackMyTrip CI/CD Canary Health Probe    "
echo "=========================================="

PASSED=0
TOTAL=2

echo -n "Probing OSM Tile CDN... "
if curl -s -f -m 5 "https://tile.openstreetmap.org/0/0/0.png" -o /dev/null -A "TrackMyTrip-CI-Canary"; then
    echo "[ONLINE]"
    PASSED=$((PASSED + 1))
else
    echo "[DEGRADED / TIMEOUT]"
fi

echo -n "Probing Live FX Endpoint... "
if curl -s -f -m 5 "https://open.er-api.com/v6/latest/INR" -o /dev/null; then
    echo "[ONLINE]"
    PASSED=$((PASSED + 1))
else
    echo "[DEGRADED / TIMEOUT]"
fi

SCORE=$(( (PASSED * 100) / TOTAL ))
echo "Canary Health Score: $SCORE/100"

if [ "$SCORE" -ge 50 ]; then
    echo "SUCCESS: Canary probe confirmed production services availability."
    exit 0
else
    echo "CRITICAL: Canary probe failed - Automated Rollback Recommended!"
    exit 1
fi
