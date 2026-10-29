#!/usr/bin/env bash
# Runs only the LevelSearch tests (seconds) with the official Godot build ($GODOT), headless.
# Passes only when ALL of these hold, the same triple rule tools/ci/run_tests.sh uses:
#   - exit code 0
#   - the line "LEVEL SEARCH TESTS PASSED" is printed
#   - no "SCRIPT ERROR" in the output
# (A script that fails to compile can still exit 0 in headless mode, so the exit code alone proves nothing.)
# Run tools/ci/validate.sh (or `godot --headless --path . --editor --quit`) once first so the project is imported.
set -euo pipefail
: "${GODOT:?Set GODOT to the Godot executable}"
mkdir -p ci-logs

set +e
timeout 300 "$GODOT" --headless --path . --script res://tests/level_search_runner.gd > ci-logs/level_search.log 2>&1
status=$?
set -e
grep -E "^LEVEL SEARCH TESTS|^  FAIL" ci-logs/level_search.log || true
if [ "$status" -ne 0 ] || ! grep -q "^LEVEL SEARCH TESTS PASSED" ci-logs/level_search.log; then
  echo "::error::LevelSearch tests failed (exit $status)"; tail -n 40 ci-logs/level_search.log; exit 1
fi
if grep -q "SCRIPT ERROR" ci-logs/level_search.log; then
  echo "::error::Script errors during the LevelSearch tests"; grep -A3 "SCRIPT ERROR" ci-logs/level_search.log; exit 1
fi
echo "LEVEL SEARCH TESTS OK"
