#!/usr/bin/env bash
# Injects the GitHub Actions build SHA into
# android/gradle.properties as a `dart-defines` entry.
#
# The Flutter Gradle plugin reads `dart-defines` from
# gradle.properties and forwards them to `flutter build` as
# `--dart-define` flags. The Dart code can then read the value at
# compile time via:
#
#   static const String buildSha = String.fromEnvironment('BUILD_SHA');
#
# This is surfaced on the Stats screen so the user can tell a fresh
# APK from a stale install.
#
# Format: dart-defines=B64("BUILD_SHA=<sha>")
# Each entry is base64-encoded "KEY=VALUE" (see the Flutter tool's
# decodeDartDefines in build_info.dart).
#
# Idempotent: any prior `dart-defines=` line is stripped before
# writing.
set -euo pipefail

GRADLE_PROPS="${1:-android/gradle.properties}"

if [[ ! -f "$GRADLE_PROPS" ]]; then
  echo "::error::gradle.properties not found at $GRADLE_PROPS" >&2
  exit 1
fi

if [[ -z "${BUILD_SHA:-}" ]]; then
  echo "::warning::BUILD_SHA is empty - build-hash diagnostic will be blank in the APK"
fi

# Base64-encode "BUILD_SHA=<value>" — each dart-defines entry is a
# base64-encoded "KEY=VALUE" string. Bytez's Flutter tool
# (decodeDartDefines) splits on comma, then base64-decodes each.
DART_DEFINES="dart-defines=$(printf 'BUILD_SHA=%s' "$BUILD_SHA" | base64 -w0)"

# Strip any prior dart-defines= line, then append the new one.
# Use Python so we get exact \n separators (avoids Windows CRLF
# creeping in via the build env's text mode).
python3 - "$GRADLE_PROPS" "$DART_DEFINES" <<'PYEOF'
import sys, pathlib
path = pathlib.Path(sys.argv[1])
new_line = sys.argv[2]
text = path.read_text()
lines = [l for l in text.splitlines() if not l.startswith("dart-defines=")]
lines.append(new_line)
path.write_bytes(("\n".join(lines) + "\n").encode("utf-8"))
PYEOF

echo "::notice::Wrote BUILD_SHA to $GRADLE_PROPS (value length=${#BUILD_SHA})"
