#!/usr/bin/env bash
# Praxis One-Shot Verification Script
# Executes the full suite of unit tests, simulation passes, artifact syntheses,
# and em-dash zero-tolerance audits.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

echo "[Praxis] Starting comprehensive verification suite..."
python3 tests/test_harness.py
