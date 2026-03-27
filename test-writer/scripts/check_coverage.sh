#!/bin/bash
# check_coverage.sh — Flutter test coverage enforcement
# Usage: bash scripts/check_coverage.sh [--threshold 80]
# Called automatically by build_ios.sh before building.
# Returns exit 0 if coverage meets threshold, exit 1 if not.

set -e

THRESHOLD=80
FORMAT="lcov"

while [[ $# -gt 0 ]]; do
  case $1 in
    --threshold) THRESHOLD="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Flutter Coverage Check"
echo "  Threshold: ${THRESHOLD}%"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── Run tests with coverage ───────────────────────────────────────────────────
echo "[ 1/3 ] Running tests with coverage..."
flutter test --coverage --coverage-path=coverage/lcov.info 2>&1 | tail -10

if [ ! -f "coverage/lcov.info" ]; then
  echo "  ❌ coverage/lcov.info not generated — check test output above"
  exit 1
fi
echo "  ✅ Tests complete"

# ── Filter out generated files ────────────────────────────────────────────────
echo ""
echo "[ 2/3 ] Filtering generated files from coverage..."

# Files to exclude from coverage (generated code, mocks, templates)
EXCLUDE_PATTERNS=(
  "*.g.dart"           # json_serializable generated
  "*.freezed.dart"     # freezed generated
  "*.mocks.dart"       # mockito/mocktail generated
  "lib/main.dart"      # entry point bootstrap only
  "lib/app.dart"       # theme config, no business logic
)

FILTERED_LCOV="coverage/lcov_filtered.info"
cp coverage/lcov.info "$FILTERED_LCOV"

for pattern in "${EXCLUDE_PATTERNS[@]}"; do
  if command -v lcov &>/dev/null; then
    lcov --remove "$FILTERED_LCOV" "*/$pattern" -o "$FILTERED_LCOV" --quiet 2>/dev/null || true
  fi
done
echo "  ✅ Generated files excluded"

# ── Calculate coverage ────────────────────────────────────────────────────────
echo ""
echo "[ 3/3 ] Calculating coverage..."

# Parse lcov.info to get line coverage
TOTAL_LINES=0
COVERED_LINES=0

while IFS= read -r line; do
  if [[ $line == DA:* ]]; then
    TOTAL_LINES=$((TOTAL_LINES + 1))
    count="${line#DA:*,}"
    count="${count%%,*}"
    if [ "$count" -gt 0 ] 2>/dev/null; then
      COVERED_LINES=$((COVERED_LINES + 1))
    fi
  fi
done < "$FILTERED_LCOV"

if [ "$TOTAL_LINES" -eq 0 ]; then
  echo "  ⚠️  No coverable lines found — ensure tests are running correctly"
  exit 1
fi

# Calculate percentage (integer arithmetic)
COVERAGE=$((COVERED_LINES * 100 / TOTAL_LINES))

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Coverage: ${COVERAGE}% (${COVERED_LINES}/${TOTAL_LINES} lines)"
echo "  Threshold: ${THRESHOLD}%"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$COVERAGE" -lt "$THRESHOLD" ]; then
  echo ""
  echo "  ❌ Coverage ${COVERAGE}% is below threshold ${THRESHOLD}%"
  echo "  Add tests before building. Run:"
  echo "    flutter test --coverage && genhtml coverage/lcov.info -o coverage/html"
  echo "  Then open coverage/html/index.html to see which files need tests."
  echo ""
  exit 1
fi

echo ""
echo "  ✅ Coverage meets threshold — build may proceed"
echo ""
exit 0
