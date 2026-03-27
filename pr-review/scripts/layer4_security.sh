#!/bin/bash
# layer4_security.sh — Security scan: secrets, non-HTTPS URLs, unsafe permissions
# Usage: bash layer4_security.sh
# Returns exit 0 if clean, exit 1 if any hard failures.

FAIL=0; ERRORS=(); WARNINGS=()

echo "[ Layer 4: Security Scan ]"

# Hardcoded secrets
SECRET_PATTERNS=(
  "api_key\s*=\s*['\"]"
  "apiKey\s*=\s*['\"]"
  "API_KEY\s*=\s*['\"]"
  "secret\s*=\s*['\"]"
  "password\s*=\s*['\"]"
  "bearer\s+[A-Za-z0-9\-_]{20}"
  "sk-[A-Za-z0-9]{20}"
)

for pattern in "${SECRET_PATTERNS[@]}"; do
  HITS=$(grep -rn --include="*.dart" -iE "$pattern" lib/ 2>/dev/null | grep -v "_test.dart" || true)
  if [ -n "$HITS" ]; then
    echo "  ❌ Possible hardcoded secret:"
    echo "$HITS" | head -5
    ERRORS+=("Hardcoded secret pattern: $pattern")
    FAIL=$((FAIL+1))
  fi
done

# http:// URLs (should be https://)
HTTP_HITS=$(grep -rn --include="*.dart" "http://" lib/ 2>/dev/null | \
  grep -v "localhost\|127.0.0.1\|//localhost" || true)
if [ -n "$HTTP_HITS" ]; then
  echo "  ⚠️  Non-HTTPS URLs found (use https://):"
  echo "$HTTP_HITS" | head -5
  WARNINGS+=("Non-HTTPS URLs detected")
fi

# Dangerous permissions check (iOS Info.plist)
if [ -f "ios/Runner/Info.plist" ]; then
  for key in NSLocationAlwaysUsageDescription NSLocationAlwaysAndWhenInUseUsageDescription; do
    if grep -q "$key" ios/Runner/Info.plist; then
      echo "  ⚠️  $key in Info.plist — 'always' location requires strong justification"
      WARNINGS+=("Always-on location permission detected")
    fi
  done
fi

# Auth tokens in SharedPreferences (should use flutter_secure_storage)
if grep -rq "SharedPreferences" lib/ 2>/dev/null; then
  if grep -rq "token\|auth\|session\|password" lib/ 2>/dev/null | \
     grep -q "SharedPreferences"; then
    echo "  ❌ Auth token stored in SharedPreferences (use flutter_secure_storage)"
    ERRORS+=("Sensitive data in SharedPreferences")
    FAIL=$((FAIL+1))
  fi
fi

if [ ${#WARNINGS[@]} -gt 0 ]; then
  echo ""
  echo "  ${#WARNINGS[@]} warning(s) — review before shipping:"
  for w in "${WARNINGS[@]}"; do echo "    ⚠️  $w"; done
fi

[ $FAIL -gt 0 ] && exit 1 || exit 0
