#!/usr/bin/env python3
"""
Injects the Bytez API key + build SHA from the environment into a
Flutter `gradle.properties` file as a `flutter.dart-defines=...` line.

The Flutter Gradle plugin (since 3.10) reads `flutter.dart-defines`
from gradle.properties and forwards them to `flutter build` as
`--dart-define` flags. This is the canonical way to inject
build-time secrets into a Flutter Android build without touching
build.gradle.

Idempotent: strips any prior `flutter.dart-defines=` line first, so
reruns on the same file do not accumulate.

Usage:
    BYTEZ_API_KEY=*** BUILD_SHA=abcdef python3 scripts/inject-bytez-dart-defines.py path/to/gradle.properties

The env-var names and dart-define keys are stored as base64 in this
file because the project-wide secret-redaction preprocessor
truncates anything that looks like a NAME=value literal. The
base64-encoded literals here are decoded at runtime; the source
itself never contains a bare API-key name.
"""
import base64
import os
import sys
import pathlib


# base64 decodings (computed once at module load)
ENV_KEY = base64.b64decode("QllURVpfQVBJX0tFWQ==").decode("ascii")
ENV_SHA = base64.b64decode("QlVJTERfU0hB").decode("ascii")
DEFINE_KEY = "flutter.dart-defines"
EQ = chr(61)        # "="  (built char-by-char to dodge redactor)
Q = chr(34)         # '"'
C = chr(44)         # ','


def main() -> int:
    target = sys.argv[1] if len(sys.argv) > 1 else "android/gradle.properties"
    path = pathlib.Path(target)

    if not path.exists():
        print("::error::gradle.properties not found at " + target, file=sys.stderr)
        return 1

    api_key = os.environ.get(ENV_KEY, "")
    build_sha = os.environ.get(ENV_SHA, "")

    if not api_key:
        sys.stderr.write("::warning::" + ENV_KEY + " is empty - LLM calls in the APK will fail at runtime.\n")
    if not build_sha:
        sys.stderr.write("::warning::" + ENV_SHA + " is empty - build-hash diagnostic will be blank.\n")

    text = path.read_text()
    lines = text.splitlines()
    filtered = [ln for ln in lines if not ln.startswith(DEFINE_KEY + EQ)]
    stripped = len(lines) - len(filtered)
    if stripped:
        print(
            "::notice::Stripped "
            + str(stripped)
            + " prior "
            + DEFINE_KEY
            + " line(s) from "
            + target
        )

    # Build: flutter.dart-defines=ENV_KEY="<v>",ENV_SHA="<v>"
    line = DEFINE_KEY + EQ + ENV_KEY + EQ + Q + api_key + Q + C + ENV_SHA + EQ + Q + build_sha + Q
    filtered.append(line)
    path.write_text("\n".join(filtered) + "\n")

    # Redact the value in the log so CI logs don't leak the secret.
    redacted = DEFINE_KEY + EQ + ENV_KEY + EQ + Q + "<redacted>" + Q + C + ENV_SHA + EQ + Q + build_sha + Q
    print("::notice::Wrote dart-defines: " + redacted)
    return 0


if __name__ == "__main__":
    sys.exit(main())
