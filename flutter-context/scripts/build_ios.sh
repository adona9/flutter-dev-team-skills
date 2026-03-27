#!/bin/bash
# build_ios.sh — Trigger iOS build on Mac Mini from Ubuntu, install to iPhone
# Usage: bash scripts/build_ios.sh [--release] [--no-install] [--ip <mac-ip>]
#
# One-time setup: run scripts/mac_setup.sh first, then:
#   echo "MAC_MINI_IP=192.168.x.x" >> ~/.flutter_build_config
#   echo "MAC_MINI_USER=yourusername" >> ~/.flutter_build_config

set -e

# ── Config ────────────────────────────────────────────────────────────────────
CONFIG_FILE="$HOME/.flutter_build_config"
BUILD_MODE="debug"
INSTALL=true
OVERRIDE_IP=""

# Load config
if [ -f "$CONFIG_FILE" ]; then
  source "$CONFIG_FILE"
else
  echo "❌ Config not found: $CONFIG_FILE"
  echo "   Run: bash scripts/mac_setup.sh <mac-ip> <mac-username>"
  exit 1
fi

MAC_IP="${MAC_MINI_IP}"
MAC_USER="${MAC_MINI_USER}"
REMOTE_PROJECT_DIR="${MAC_PROJECT_DIR:-~/flutter_builds/$(basename $(pwd))}"

# ── Parse args ────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case $1 in
    --release)    BUILD_MODE="release"; shift ;;
    --no-install) INSTALL=false; shift ;;
    --ip)         OVERRIDE_IP="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

[ -n "$OVERRIDE_IP" ] && MAC_IP="$OVERRIDE_IP"

if [ -z "$MAC_IP" ] || [ -z "$MAC_USER" ]; then
  echo "❌ MAC_MINI_IP and MAC_MINI_USER must be set in $CONFIG_FILE"
  exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Flutter iOS Build"
echo "  Mode:    $BUILD_MODE"
echo "  Mac:     $MAC_USER@$MAC_IP"
echo "  Install: $INSTALL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── Step 1: Sync project to Mac Mini ─────────────────────────────────────────
echo "[ 1/4 ] Syncing project to Mac Mini..."
ssh "$MAC_USER@$MAC_IP" "mkdir -p $REMOTE_PROJECT_DIR"
rsync -az --exclude='.git' --exclude='build/' --exclude='.dart_tool/' \
  --progress \
  ./ "$MAC_USER@$MAC_IP:$REMOTE_PROJECT_DIR/"
echo "  ✅ Sync complete"

# ── Step 2: Flutter pub get on Mac Mini ──────────────────────────────────────
echo ""
echo "[ 2/4 ] Installing dependencies on Mac Mini..."
ssh "$MAC_USER@$MAC_IP" "
  cd $REMOTE_PROJECT_DIR
  export PATH=\"\$PATH:\$HOME/flutter/bin\"
  flutter pub get
"
echo "  ✅ Dependencies ready"

# ── Step 3: Build IPA ────────────────────────────────────────────────────────
echo ""
echo "[ 3/4 ] Building iOS ($BUILD_MODE)..."

if [ "$BUILD_MODE" = "release" ]; then
  BUILD_CMD="flutter build ipa --release"
  IPA_PATH="build/ios/ipa/*.ipa"
else
  BUILD_CMD="flutter build ios --debug --no-codesign && cd ios && xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=YES 2>&1 | tail -5"
  IPA_PATH="build/ios/Debug-iphoneos/Runner.app"
fi

ssh "$MAC_USER@$MAC_IP" "
  cd $REMOTE_PROJECT_DIR
  export PATH=\"\$PATH:\$HOME/flutter/bin\"
  $BUILD_CMD
"
echo "  ✅ Build complete"

# ── Step 4: Install to iPhone ─────────────────────────────────────────────────
if [ "$INSTALL" = true ]; then
  echo ""
  echo "[ 4/4 ] Installing to iPhone..."
  echo "  ⚠️  Make sure iPhone is connected to the Mac Mini via USB"

  if [ "$BUILD_MODE" = "release" ]; then
    ssh "$MAC_USER@$MAC_IP" "
      cd $REMOTE_PROJECT_DIR
      export PATH=\"\$PATH:\$HOME/flutter/bin:/usr/local/bin\"
      IPA=\$(ls $IPA_PATH | head -1)
      ios-deploy --bundle \"\$IPA\" --no-wifi
    "
  else
    ssh "$MAC_USER@$MAC_IP" "
      cd $REMOTE_PROJECT_DIR
      export PATH=\"\$PATH:\$HOME/flutter/bin:/usr/local/bin\"
      ios-deploy --bundle $IPA_PATH --no-wifi --debug
    "
  fi
  echo "  ✅ Installed to iPhone"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ "$BUILD_MODE" = "release" ]; then
  echo "  ✅ Release build complete"
  echo "  Next: upload IPA to TestFlight via Transporter on Mac Mini"
  echo "  Run:  ssh $MAC_USER@$MAC_IP 'open -a Transporter'"
else
  echo "  ✅ Debug build installed to iPhone"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
