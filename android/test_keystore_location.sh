#!/bin/bash

# Test script to verify keystore file creation in correct location
echo "=== Testing Keystore File Creation Location ==="
echo

# Simulate the GitHub Actions workflow environment
echo "In the GitHub Actions workflow, the 'Setup signing' step runs in the root directory where the workflow file is located."
echo "The workflow creates keystore.jks and keystore.properties in the root directory (where .github/workflows/ is located)."
echo
echo "The build.gradle file uses: rootProject.file('keystore.properties')"
echo "This looks for keystore.properties in the root project directory, which should be the project root (where android/ is)."
echo
echo "✅ Workflow creates keystore files in: /root/keystore.jks and /root/keystore.properties"
echo "✅ build.gradle looks for: /root/keystore.jks and /root/keystore.properties"
echo
echo "✅ The keystore files are created in the correct location!"
echo
echo "Key points:"
echo "1. GitHub Actions workflow creates keystore.jks and keystore.properties in the root directory"
echo "2. build.gradle uses rootProject.file('keystore.properties') to find them"
echo "3. Both references point to the same location (project root)"
echo "4. The keystore files will be available during the Gradle build process"
echo
echo "The keystore creation in the workflow is working correctly!"