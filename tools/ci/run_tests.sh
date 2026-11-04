#!/usr/bin/env bash
# Runs the automated tests with the official Godot build ($GODOT), headless:
#   1. the full test suite (tests/test_scene.tscn): must exit 0 and print
#      "All tests passed", with no script errors
#   2. the game-flow QA run with real scene changes (tools/qa_flow.gd)
#   3. the map-selection run: every catalog map selected, restarted and left, three
#      times over, with real scene changes (tools/map_flow.gd); no errors or
#      warnings allowed in its output
#   4. the Expanded Library drift check: the saved level scene and navmesh must
#      equal a rebuild from source (maps/library/tools/rebuild_level.py --check;
#      the saved files are put back afterwards)
# Run tools/ci/validate.sh first (it imports the project). Logs go to ci-logs/.
set -euo pipefail
: "${GODOT:?Set GODOT to the Godot executable}"
mkdir -p ci-logs

echo "Running the test suite (about 17 minutes)"
set +e
timeout 2400 "$GODOT" --headless --path . res://tests/test_scene.tscn > ci-logs/tests.log 2>&1
status=$?
set -e
grep -E "^All tests passed|^Tests FAILED|^  \[" ci-logs/tests.log || true
if [ "$status" -ne 0 ] || ! grep -q "^All tests passed" ci-logs/tests.log; then
  echo "::error::Test suite failed (exit $status)"; grep -E "FAIL|SCRIPT ERROR" ci-logs/tests.log || tail -n 60 ci-logs/tests.log; exit 1
fi
if grep -qE "SCRIPT ERROR|^ERROR" ci-logs/tests.log; then
  echo "::error::Engine or script errors during the test run"; grep -E -A3 "SCRIPT ERROR|^ERROR" ci-logs/tests.log; exit 1
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

echo "Running the map-selection run"
set +e
timeout 600 "$GODOT" --headless --path . --script res://tools/map_flow.gd > ci-logs/map_flow.log 2>&1
status=$?
set -e
grep -E "^\s+\[(ok|FAIL)\]|MAP FLOW" ci-logs/map_flow.log || true
if [ "$status" -ne 0 ] || ! grep -q "MAP FLOW PASSED" ci-logs/map_flow.log; then
  echo "::error::Map-selection run failed (exit $status)"; exit 1
fi
if grep -qE "SCRIPT ERROR|^ERROR|^WARNING" ci-logs/map_flow.log; then
  echo "::error::Errors or warnings during the map-selection run"; grep -E -A2 "SCRIPT ERROR|^ERROR|^WARNING" ci-logs/map_flow.log; exit 1
fi
echo "Running the Expanded Library drift check (about 5 minutes)"
set +e
timeout 1500 python3 maps/library/tools/rebuild_level.py --check > ci-logs/rebuild_level.log 2>&1
status=$?
set -e
grep -E "^rebuild_level:" ci-logs/rebuild_level.log || true
if [ "$status" -ne 0 ] || ! grep -q "CHECK PASSED" ci-logs/rebuild_level.log; then
  echo "::error::The saved Expanded Library differs from a rebuild from source (exit $status)"; tail -n 60 ci-logs/rebuild_level.log; exit 1
fi
echo "TESTS PASSED"
