#!/bin/bash
# validate_spec.sh — Flutter feature spec completeness checker
# Usage: bash scripts/validate_spec.sh
# Interactive — prompts for each required field and validates responses.
# Returns exit 0 if all fields pass, exit 1 with report if any fail.

set -e

PASS=0
FAIL=0
VAGUE=0
RESULTS=()

VAGUE_WORDS=("tbd" "figure it out" "and stuff" "etc" "various" "some kind of" "maybe" "possibly" "or something" "not sure")

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Flutter Feature Spec Validator"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Answer each field. Type 'skip' to mark as missing."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

check_field() {
  local label="$1"
  local value="$2"
  local lower_value
  lower_value=$(echo "$value" | tr '[:upper:]' '[:lower:]')

  if [ -z "$value" ] || [ "$lower_value" = "skip" ]; then
    echo "  ❌ $label — MISSING"
    RESULTS+=("MISSING: $label")
    FAIL=$((FAIL+1))
    return
  fi

  # Check for vague language
  local found_vague=""
  for word in "${VAGUE_WORDS[@]}"; do
    if echo "$lower_value" | grep -q "$word"; then
      found_vague="$word"
      break
    fi
  done

  if [ -n "$found_vague" ]; then
    echo "  ⚠️  $label — vague term detected: '$found_vague'"
    RESULTS+=("VAGUE: $label — contains '$found_vague'")
    VAGUE=$((VAGUE+1))
  else
    echo "  ✅ $label — \"$value\""
    PASS=$((PASS+1))
  fi
}

prompt_field() {
  local label="$1"
  local hint="$2"
  echo "  $label"
  [ -n "$hint" ] && echo "  Hint: $hint"
  printf "  → "
  read -r value
  echo ""
  check_field "$label" "$value"
}

# ── Base fields ───────────────────────────────────────────────────────────────
echo "[ Base Fields ]"
echo ""

prompt_field "Feature name" "e.g. 'User Profile', 'Post Creation', 'Search'"
prompt_field "Entry point" "e.g. 'Profile tab in bottom nav', 'FAB on feed screen', 'deep link /user/:id'"
prompt_field "Primary user action" "ONE thing. e.g. 'View another user\\'s posts and bio'"
prompt_field "Data source" "e.g. 'GET /users/:id → UserDTO', or 'local SwiftData only', or 'mock for now'"
prompt_field "Empty state" "e.g. 'Show \\'No posts yet\\' with a Create button'"
prompt_field "Error state" "e.g. 'Show error card with Retry button'"
prompt_field "Loading state" "skeleton / shimmer / spinner — must specify which"
prompt_field "Auth required" "yes or no — if yes, what happens on session expiry?"

# ── Social-specific fields ────────────────────────────────────────────────────
echo ""
echo "[ Social-Specific Fields ]"
echo ""

prompt_field "Content ownership" "self / others / both — who creates this content?"
prompt_field "Interaction model" "read-only / create / edit / delete / react — which apply?"
prompt_field "Real-time updates" "yes or no — if yes, polling or websocket?"
prompt_field "Media involved" "yes or no — if yes, upload or display or both?"

# ── Summary ───────────────────────────────────────────────────────────────────
TOTAL=$((PASS + FAIL + VAGUE))
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Result: $PASS/$TOTAL fields passed · $VAGUE vague · $FAIL missing"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ ${#RESULTS[@]} -gt 0 ]; then
  echo ""
  echo "  Issues to resolve before scaffolding:"
  for r in "${RESULTS[@]}"; do
    echo "    • $r"
  done
  echo ""
  echo "  ⛔ Cannot scaffold until all fields are present and specific."
  exit 1
fi

echo ""
echo "  ✅ Spec is complete. Ready to decompose into layers."
echo ""
exit 0
