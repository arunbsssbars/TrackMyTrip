#!/usr/bin/env bash
set -e

echo "[DevSecOps] Configuring Git hooks path to .githooks..."
chmod +x .githooks/pre-commit
git config core.hooksPath .githooks

echo "[SUCCESS] Git hooks configured successfully!"
echo "Pre-commit secret blocker is now actively protecting your commits."
