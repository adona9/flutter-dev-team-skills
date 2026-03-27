#!/bin/bash
# check_compliance.sh — App Store + Play Store pre-release compliance check
# Usage: bash check_compliance.sh
# Run before every release build (TestFlight or Play Store submission).
# Returns exit 0 if all checks pass, exit 1 with report if any fail.

set -e

PASS=0; FAIL=0; WARNINGS=()
RESULTS=()

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  App Store + Play Store Compliance Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── iOS Checks ────────────────────────────────────────────────────────────────
echo "[ iOS ]"

# PrivacyInfo.xcprivacy must exist
if [ -f "ios/Runner/PrivacyInfo.xcprivacy" ]; then
  echo "  ✅ PrivacyInfo.xcprivacy present"
  PASS=$((PASS+1))
else
  echo "  ❌ PrivacyInfo.xcprivacy missing — required for iOS 17+ App Store"
  RESULTS+=("FAIL: ios/Runner/PrivacyInfo.xcprivacy not found")
  FAIL=$((FAIL+1))
fi

# Info.plist must exist
if [ -f "ios/Runner/Info.plist" ]; then
  echo "  ✅ Info.plist present"
  PASS=$((PASS+1))

  # Common NSUsageDescription keys — warn if API-related code exists but key is missing
  declare -A USAGE_KEYS=(
    ["NSCameraUsageDescription"]="camera"
    ["NSPhotoLibraryUsageDescription"]="photo_library\|image_picker"
    ["NSMicrophoneUsageDescription"]="microphone\|audio"
    ["NSLocationWhenInUseUsageDescription"]="location\|geolocator"
    ["NSContactsUsageDescription"]="contacts"
  )

  for key in "${!USAGE_KEYS[@]}"; do
    pattern="${USAGE_KEYS[$key]}"
    uses_api=$(grep -rq "$pattern" lib/ 2>/dev/null && echo "yes" || echo "no")
    has_key=$(grep -q "$key" ios/Runner/Info.plist && echo "yes" || echo "no")

    if [ "$uses_api" = "yes" ] && [ "$has_key" = "no" ]; then
      echo "  ❌ $key missing from Info.plist (API usage detected in lib/)"
      RESULTS+=("FAIL: $key required in Info.plist")
      FAIL=$((FAIL+1))
    elif [ "$has_key" = "yes" ]; then
      echo "  ✅ $key present"
      PASS=$((PASS+1))
    fi
  done
else
  echo "  ❌ ios/Runner/Info.plist not found"
  RESULTS+=("FAIL: ios/Runner/Info.plist not found")
  FAIL=$((FAIL+1))
fi

# Version + build number check in pubspec.yaml
if [ -f "pubspec.yaml" ]; then
  VERSION=$(grep "^version:" pubspec.yaml | head -1)
  echo "  ℹ️  $VERSION"
  echo "  ⚠️  Confirm version + build number are bumped before this TestFlight build"
  WARNINGS+=("Manually verify version/build bump: $VERSION")
fi

# No hardcoded secrets in Dart code
SECRET_HITS=$(grep -rn --include="*.dart" -iE \
  "api_key\s*=\s*['\"]|apiKey\s*=\s*['\"]|secret\s*=\s*['\"]|password\s*=\s*['\"]" \
  lib/ 2>/dev/null | grep -v "_test.dart" || true)
if [ -n "$SECRET_HITS" ]; then
  echo "  ❌ Hardcoded secret detected in Dart code:"
  echo "$SECRET_HITS" | head -5
  RESULTS+=("FAIL: hardcoded secrets in lib/")
  FAIL=$((FAIL+1))
else
  echo "  ✅ No hardcoded secrets in Dart code"
  PASS=$((PASS+1))
fi

echo ""

# ── Android Checks ────────────────────────────────────────────────────────────
echo "[ Android ]"

# build.gradle version check
BUILD_GRADLE="android/app/build.gradle"
if [ -f "$BUILD_GRADLE" ]; then
  VERSION_CODE=$(grep "versionCode" "$BUILD_GRADLE" | head -1 | tr -d ' ')
  VERSION_NAME=$(grep "versionName" "$BUILD_GRADLE" | head -1 | tr -d ' ')
  echo "  ℹ️  $VERSION_CODE"
  echo "  ℹ️  $VERSION_NAME"
  echo "  ⚠️  Confirm versionCode and versionName are bumped for this submission"
  WARNINGS+=("Manually verify Android version bump in $BUILD_GRADLE")
  PASS=$((PASS+1))
else
  echo "  ⚠️  $BUILD_GRADLE not found — skipping Android version check"
  WARNINGS+=("$BUILD_GRADLE not found")
fi

# AndroidManifest.xml minSdkVersion guard
MANIFEST="android/app/src/main/AndroidManifest.xml"
GRADLE_PROPS="android/app/build.gradle"
if [ -f "$GRADLE_PROPS" ]; then
  MIN_SDK=$(grep "minSdkVersion" "$GRADLE_PROPS" | grep -oE "[0-9]+" | head -1)
  if [ -n "$MIN_SDK" ] && [ "$MIN_SDK" -lt 23 ]; then
    echo "  ❌ minSdkVersion $MIN_SDK is below required minimum of 23"
    RESULTS+=("FAIL: minSdkVersion must be >= 23 (found $MIN_SDK)")
    FAIL=$((FAIL+1))
  elif [ -n "$MIN_SDK" ]; then
    echo "  ✅ minSdkVersion $MIN_SDK (>= 23)"
    PASS=$((PASS+1))
  fi
fi

echo ""

# ── Summary ───────────────────────────────────────────────────────────────────
TOTAL=$((PASS + FAIL))
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Result: $PASS/$TOTAL checks passed · $FAIL failed"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ ${#WARNINGS[@]} -gt 0 ]; then
  echo ""
  echo "  Manual checks required before submitting:"
  for w in "${WARNINGS[@]}"; do echo "    ⚠️  $w"; done
fi

if [ ${#RESULTS[@]} -gt 0 ]; then
  echo ""
  echo "  Failures to fix:"
  for r in "${RESULTS[@]}"; do echo "    ❌ $r"; done
  echo ""
  exit 1
fi

echo ""
echo "  ✅ Compliance checks passed — ready for release build"
echo ""
exit 0
