#!/bin/bash
# pr_review.sh — Full PR review orchestrator (Layers 1-4 + adversarial agent)
# Usage: bash pr_review.sh [--quick] [--file <path>]
#   --quick    Run layers 1-2 only (~5s, good for pre-commit)
#   --file     Review a single file instead of all changed files

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

QUICK=false
TARGET_FILE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --quick) QUICK=true; shift ;;
    --file) TARGET_FILE="$2"; shift 2 ;;
    *) shift ;;
  esac
done

CHANGED_FILES=$(git diff --name-only HEAD | grep "\.dart$" || true)
[ -n "$TARGET_FILE" ] && CHANGED_FILES="$TARGET_FILE"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  PR Review"
echo "  Files: $(echo "$CHANGED_FILES" | wc -l | tr -d ' ') changed Dart files"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

LAYER_RESULTS=()
OVERALL=0

run_layer() {
  local name="$1"; local script="$2"
  echo ""
  if bash "$script" $CHANGED_FILES; then
    LAYER_RESULTS+=("✅ $name")
  else
    LAYER_RESULTS+=("❌ $name — BLOCKED")
    OVERALL=1
  fi
}

run_layer "Layer 1: Static Analysis"  "${SCRIPT_DIR}/layer1_static.sh"
run_layer "Layer 2: Architecture"     "${SCRIPT_DIR}/layer2_architecture.sh"

if [ "$QUICK" = false ]; then
  run_layer "Layer 3: Coverage"       "${SCRIPT_DIR}/layer3_coverage.sh"
  run_layer "Layer 4: Security"       "${SCRIPT_DIR}/layer4_security.sh"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
for result in "${LAYER_RESULTS[@]}"; do echo "  $result"; done
echo ""

if [ $OVERALL -eq 0 ] && [ "$QUICK" = false ]; then
  echo "  ⚡ Scripts passed. Running adversarial review..."
  echo "  (agent reviews diff for edge cases scripts can't catch)"
  echo ""
  # Agent layer is triggered here — the Claude Code agent reads the diff
  # and applies the adversarial reviewer prompt from the skill
  echo "  [Agent adversarial review follows]"
  git diff HEAD -- "*.dart"
fi

[ $OVERALL -eq 0 ] && echo "  ✅ PASS — ready to commit" || echo "  ❌ BLOCK — fix issues above"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
exit $OVERALL
