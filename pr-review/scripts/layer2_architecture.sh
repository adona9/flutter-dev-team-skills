#!/bin/bash
# layer2_architecture.sh — Architecture guard: layer boundaries, naming, forbidden patterns
# Usage: bash layer2_architecture.sh [changed_files...]
# Pass changed Dart file paths as arguments, or runs against git diff HEAD by default.

FILES=("$@")
[ ${#FILES[@]} -eq 0 ] && FILES=($(git diff --name-only HEAD | grep "\.dart$"))

FAIL=0; ERRORS=()

echo "[ Layer 2: Architecture Guard ]"
echo "  Checking ${#FILES[@]} file(s)..."

for file in "${FILES[@]}"; do
  [ ! -f "$file" ] && continue

  # Layer boundary: no Flutter imports in domain
  if echo "$file" | grep -q "domain/" && grep -q "package:flutter" "$file"; then
    echo "  ❌ $file — Flutter import in domain layer"
    ERRORS+=("$file: domain layer must be pure Dart")
    FAIL=$((FAIL+1))
  fi

  # No direct API calls in presentation
  if echo "$file" | grep -q "presentation/" && grep -qE "Dio\(\)|http\.get\(" "$file"; then
    echo "  ❌ $file — direct API call in presentation layer"
    ERRORS+=("$file: use repository, not direct API calls")
    FAIL=$((FAIL+1))
  fi

  # No print statements outside tests
  if ! echo "$file" | grep -q "test/" && grep -qE "^\s+print\(" "$file"; then
    echo "  ❌ $file — print() found (use logger or remove)"
    ERRORS+=("$file: remove print() statements")
    FAIL=$((FAIL+1))
  fi

  # No hardcoded route strings
  if grep -qE "context\.go\(['\"]/" "$file" || grep -qE "GoRouter.*path:\s*['\"]/" "$file"; then
    if ! echo "$file" | grep -q "routes.dart"; then
      echo "  ⚠️  $file — possible hardcoded route string (use Routes.*)"
    fi
  fi

  # No hardcoded colors in widgets
  if echo "$file" | grep -qE "presentation/|design_system/" && \
     grep -qE "Color\(0x[Ff][Ff]" "$file"; then
    echo "  ❌ $file — hardcoded Color() value (use AppColors.*)"
    ERRORS+=("$file: use AppColors tokens, not hardcoded hex")
    FAIL=$((FAIL+1))
  fi

  # Unsafe AsyncValue unwrap
  if grep -qE "\.value\b" "$file" && ! echo "$file" | grep -q "test/"; then
    if ! grep -q "valueOrNull" "$file"; then
      echo "  ⚠️  $file — .value on AsyncValue may throw; prefer .valueOrNull or .when()"
    fi
  fi

  # setState in ConsumerWidget
  if grep -q "ConsumerWidget\|ConsumerStatefulWidget" "$file" && \
     grep -q "setState(" "$file"; then
    echo "  ❌ $file — setState() in ConsumerWidget (use Riverpod state)"
    ERRORS+=("$file: remove setState, use Riverpod")
    FAIL=$((FAIL+1))
  fi

  [ $FAIL -eq 0 ] && echo "  ✅ $file"
done

if [ $FAIL -gt 0 ]; then
  echo ""
  echo "  ${#ERRORS[@]} architecture violation(s):"
  for e in "${ERRORS[@]}"; do echo "    • $e"; done
  exit 1
fi

echo "  ✅ Architecture guard passed"
exit 0
