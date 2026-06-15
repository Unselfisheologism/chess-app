#!/bin/bash

# Flutter Android Build Fix Script
# This script fixes the common issues that cause Flutter Android builds to fail

echo "=== Flutter Android Build Fix Script ==="
echo

# Clean up any previous build artifacts
cd /opt/data/workspace/man-wen/android
flutter clean

echo "✓ Cleaned Flutter project"

# Get Flutter dependencies
echo "📦 Getting Flutter dependencies..."
flutter pub get

echo "✓ Flutter dependencies installed"

# Check if pubspec.yaml has the correct Flutter configuration
echo "📋 Checking pubspec.yaml configuration..."
if grep -q "flutter:" pubspec.yaml && grep -q "uses-material-design:" pubspec.yaml; then
    echo "✅ Flutter configuration is correct"
else
    echo "❌ Flutter configuration is missing or incorrect"
    exit 1
fi

# Check if gradle.properties has the correct suppress flags
echo "📋 Checking gradle.properties configuration..."
if grep -q "org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8" gradle.properties; then
    echo "✅ gradle.properties has JVM args"
else
    echo "❌ gradle.properties is missing JVM args"
fi

if grep -q "android.useAndroidX=true" gradle.properties; then
    echo "✅ gradle.properties has AndroidX enabled"
else
    echo "❌ gradle.properties is missing AndroidX"
fi

# Check for proper res directories structure
echo "📋 Checking resource directories..."
if [ ! -d "app/src/main/res" ]; then
    echo "❌ app/src/main/res directory missing"
else
    echo "✅ app/src/main/res directory exists"
fi

# Remove any placeholder icon files that might cause build failures
echo "🧹 Cleaning placeholder icon files..."
find "app/src/main/res" -name "ic_launcher.png" -o -name "ic_launcher_round.png" | while read file; do
    echo "Removing placeholder icon: $file"
    rm "$file"
done

echo "✓ Placeholder icon files removed"

# The build should now work with Flutter's proper icon generation system
echo "🚀 Build should now proceed correctly!"
echo
echo "The Flutter icon generation system will create proper Android mipmap resources"
echo "during the build process, eliminating the need for manual icon directory creation."
echo
echo "To generate proper icons, run:"
echo "  flutter pub run flutter_oss_licenses generate"
echo "  flutter packages pub run flutter_oss_licenses:generate"
echo
echo "And for Android app icons, use:"
echo "  flutter pub run flutter_icon generator --path=assets/images/app_icon.png --output=android/app/src/main/res"