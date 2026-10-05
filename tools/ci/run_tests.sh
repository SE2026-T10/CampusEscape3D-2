#!/usr/bin/env bash
# Runs the automated tests with the official Godot build ($GODOT), headless:
#   1. the full test suite (tests/test_scene.tscn): must exit 0 and print
#      "All tests passed", with no script errors
#   2. the game-flow QA run with real scene changes (tools/qa_flow.gd)
# Run tools/ci/validate.sh first (it imports the project). Logs go to ci-logs/.
set -euo pipefail
: "${GODOT:?Set GODOT to the Godot executable}"
mkdir -p ci-logs

echo "Running the test suite (about 4 minutes)"
set +e
timeout 1200 "$GODOT" --headless --path . res://tests/test_scene.tscn > ci-logs/tests.log 2>&1
status=$?
set -e
grep -E "^All tests passed|^Tests FAILED|^  \[" ci-logs/tests.log || true
if [ "$status" -ne 0 ] || ! grep -q "^All tests passed" ci-logs/tests.log; then
  echo "::error::Test suite failed (exit $status)"; grep -E "FAIL|SCRIPT ERROR" ci-logs/tests.log || tail -n 60 ci-logs/tests.log; exit 1
fi
if grep -q "SCRIPT ERROR" ci-logs/tests.log; then
  echo "::error::Script errors during the test run"; grep -A3 "SCRIPT ERROR" ci-logs/tests.log; exit 1
fi

echo "Running the game-flow QA run"
set +e
timeout 600 "$GODOT" --headless --path . --script res://tools/qa_flow.gd > ci-logs/qa_flow.log 2>&1
status=$?
set -e
grep -E "^\s+\[(ok|FAIL)\]|QA FLOW" ci-logs/qa_flow.log || true
if [ "$status" -ne 0 ] || ! grep -q "QA FLOW PASSED" ci-logs/qa_flow.log; then
  echo "::error::Game-flow QA run failed (exit $status)"; exit 1
fi
echo "TESTS PASSED"
