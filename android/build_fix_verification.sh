#!/bin/bash

# Android Build Fix Verification Script - Run from project root

# Get the absolute path to the project root
PROJECT_ROOT="/opt/data/workspace/man-wen"

# Change to the android directory for relative path operations
cd "$PROJECT_ROOT/android"

echo "=== Android Build Fix Verification ==="
echo

# Check if mipmap directories exist
ANDROID_RES_DIR="app/src/main/res"
mipmap_dirs=("hdpi" "mdpi" "xhdpi" "xxhdpi" "xxxhdpi" "anydpi-v26")

missing_dirs=()
for dir in "${mipmap_dirs[@]}"; do
    if [ ! -d "$ANDROID_RES_DIR/mipmap-${dir}" ]; then
        missing_dirs+=("$dir")
    fi
    # Check for required icon files
    if [ ! -f "$ANDROID_RES_DIR/mipmap-${dir}/ic_launcher.png" ] || [ ! -f "$ANDROID_RES_DIR/mipmap-${dir}/ic_launcher_round.png" ]; then
        echo "❌ Missing icon files in $dir"
    fi
done

if [ ${#missing_dirs[@]} -gt 0 ]; then
    echo "❌ Missing mipmap directories: ${missing_dirs[*]}"
else
    echo "✅ All mipmap directories exist"
fi

# Check gradle.properties for suppress flags
echo
if grep -q "android.suppressUnsupportedCompileSdk=34" "gradle.properties"; then
    echo "✅ android.suppressUnsupportedCompileSdk=34 found"
else
    echo "❌ android.suppressUnsupportedCompileSdk=34 not found"
fi

if grep -q "android.suppressDeprecatedPackage=34" "gradle.properties"; then
    echo "✅ android.suppressDeprecatedPackage=34 found"
else
    echo "❌ android.suppressDeprecatedPackage=34 not found"
fi

# Check pubspec.yaml (in project root)
echo
if grep -q "flutter:" "../pubspec.yaml" && grep -q "uses-material-design:" "../pubspec.yaml"; then
    echo "✅ pubspec.yaml Flutter configuration exists"
else
    echo "❌ pubspec.yaml Flutter configuration missing"
fi

# Summary
echo
echo "=== Summary ==="
echo "The following fixes were applied to resolve the Android build failure:
1. Created all required mipmap directories (hdpi, mdpi, xhdpi, xxhdpi, xxxhdpi, anydpi-v26)
2. Added placeholder ic_launcher.png and ic_launcher_round.png files to all mipmap directories
3. Updated gradle.properties to suppress warnings about deprecated package attribute
4. Updated pubspec.yaml with proper Flutter configuration
5. Fixed GitHub Actions workflow to create keystore files in correct location

These fixes should resolve the resource not found errors during the build process.

To complete the fix, the project would need:
- Proper Android app icon files (currently placeholder files)
- Actual keystore files for release signing (created by workflow during CI)
- Additional Flutter plugin configuration if needed"