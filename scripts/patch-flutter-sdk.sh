#!/bin/bash
# Patch Flutter 3.22 SDK for AGP 8.x compat
# OutputFile was removed in AGP 8.0 but Flutter 3.22 still references it.
# This script MUST run before any gradle command.
#
# Patches two things in flutter.groovy:
#   1. import com.android.build.OutputFile  ->  import java.lang.Object
#   2. OutputFile.ABI  ->  "ABI"  (string literal, same value as the AGP 7.x constant)

set -e

# --- Find Flutter SDK ---
FLUTTER_BIN=""
if [ -n "$FLUTTER_ROOT" ] && [ -x "$FLUTTER_ROOT/bin/flutter" ]; then
    FLUTTER_BIN="$FLUTTER_ROOT/bin/flutter"
elif command -v flutter >/dev/null 2>&1; then
    FLUTTER_BIN=$(command -v flutter)
fi

if [ -z "$FLUTTER_BIN" ] || [ ! -f "$FLUTTER_BIN" ]; then
    echo "WARNING: flutter binary not found, skipping AGP 8.x patch"
    exit 0
fi

# Resolve SDK path (handles symlinks)
FLUTTER_SDK=$(cd "$(dirname "$FLUTTER_BIN")/.." && pwd -P)
FLUTTER_GROOVY="$FLUTTER_SDK/packages/flutter_tools/gradle/src/main/groovy/flutter.groovy"

if [ ! -f "$FLUTTER_GROOVY" ]; then
    echo "WARNING: flutter.groovy not found at $FLUTTER_GROOVY, skipping patch"
    exit 0
fi

# --- Skip if already patched ---
if ! grep -q "OutputFile\.ABI" "$FLUTTER_GROOVY"; then
    echo "flutter.groovy already patched (no OutputFile.ABI references)"
    exit 0
fi

# --- Apply patch ---
echo ">>> Patching flutter.groovy for AGP 8.x OutputFile compat"

# 1. Replace the import (full package path)
sed -i 's|com\.android\.build\.OutputFile|java.lang.Object|g' "$FLUTTER_GROOVY"

# 2. Replace the usage (just the class name + dot)
#    OutputFile.ABI was a static final String constant with value "ABI" in AGP 7.x
sed -i 's|OutputFile\.ABI|"ABI"|g' "$FLUTTER_GROOVY"

# --- Verify patch ---
if grep -q "OutputFile\.ABI" "$FLUTTER_GROOVY"; then
    echo "ERROR: patch failed, OutputFile.ABI still present in $FLUTTER_GROOVY"
    exit 1
fi

REMAINING=$(grep -c "com\.android\.build\.OutputFile" "$FLUTTER_GROOVY" || true)
if [ "$REMAINING" -gt 0 ]; then
    echo "ERROR: patch incomplete, $REMAINING com.android.build.OutputFile refs remain"
    exit 1
fi

echo ">>> Patch applied successfully (import + usage both replaced)"

# --- Clear gradle caches to force recompile of Flutter plugin ---
# The includeBuild cache may serve a stale compiled version that still
# references the old OutputFile class.
echo ">>> Clearing gradle compile caches"
rm -rf ~/.gradle/caches/jars-*      2>/dev/null || true
rm -rf ~/.gradle/caches/transforms-* 2>/dev/null || true
rm -rf ~/.gradle/caches/8.*          2>/dev/null || true
rm -rf ~/.gradle/caches/build-cache-* 2>/dev/null || true

echo ">>> Done"
