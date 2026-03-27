#!/bin/bash
# layer1_static.sh — Static analysis: dart analyze + dart format
# Usage: bash layer1_static.sh
# Returns exit 0 if clean, exit 1 if any errors or warnings.

set -e
PASS=0; FAIL=0; ERRORS=()

echo "[ Layer 1: Static Analysis ]"

# dart analyze
echo "  Running dart analyze..."
if dart analyze --fatal-warnings 2>&1 | grep -q "No issues found"; then
  echo "  ✅ dart analyze — clean"
  PASS=$((PASS+1))
else
  OUTPUT=$(dart analyze --fatal-warnings 2>&1)
  echo "  ❌ dart analyze — issues found"
  echo "$OUTPUT" | grep -E "error|warning" | head -20
  ERRORS+=("dart analyze failed")
  FAIL=$((FAIL+1))
fi

# dart format
echo "  Checking dart format..."
if dart format --set-exit-if-changed . 2>&1 | grep -q "Formatted"; then
  echo "  ❌ dart format — unformatted files detected"
  echo "  Run: dart format ."
  ERRORS+=("Unformatted files — run dart format .")
  FAIL=$((FAIL+1))
else
  echo "  ✅ dart format — all files formatted"
  PASS=$((PASS+1))
fi

[ $FAIL -gt 0 ] && exit 1 || exit 0
