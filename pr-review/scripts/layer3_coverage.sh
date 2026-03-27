#!/bin/bash
# layer3_coverage.sh — Coverage gate: delegates to test-writer's check_coverage.sh
# Usage: bash layer3_coverage.sh [--threshold N]
# Default threshold: 80%

PLUGIN_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
exec bash "$PLUGIN_ROOT/test-writer/scripts/check_coverage.sh" "$@"
