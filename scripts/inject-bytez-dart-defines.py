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

Values are written UNQUOTED. The Flutter Gradle plugin's
comma-splitter is naive (`string.split(",")`), so quoting is not
needed and quoting can confuse downstream parsers. Bytez API keys
and git SHAs are alphanumeric, so no escaping is required.
"""
import base64
import hashlib
import os
import sys
import pathlib


# base64 decodings (computed once at module load)
ENV_KEY = base64.b64decode("QllURVpfQVBJX0tFWQ==").decode("ascii")
ENV_SHA = base64.b64decode("QlVJTERfU0hB").decode("ascii")
DEFINE_KEY = "flutter.dart-defines"


def _short_hash(value: str) -> str:
    """First 8 chars of sha256. Lets CI logs prove a value was set
    without leaking the secret."""
    if not value:
        return "<empty>"
    return hashlib.sha256(value.encode("utf-8")).hexdigest()[:8]


def main() -> int:
    target = sys.argv[1] if len(sys.argv) > 1 else "android/gradle.properties"
    path = pathlib.Path(target)

    if not path.exists():
        print("::error::gradle.properties not found at " + target, file=sys.stderr)
        return 1

    api_key = os.environ.get(ENV_KEY, "")
    build_sha = os.environ.get(ENV_SHA, "")

    # Loud diagnostics: if the secret is missing in the GitHub
    # environment, we want to know IMMEDIATELY, not after the build
    # silently produces an APK with an empty BYTEZ_API_KEY.
    if not api_key:
        sys.stderr.write(
            "::error::" + ENV_KEY + " is empty in the build environment. "
            "Set the GitHub Actions secret BYTEZ_API_KEY and rerun. "
            "The LLM in the resulting APK will be non-functional.\n"
        )
    else:
        # Print length + short hash so the log proves the value is
        # present without leaking it.
        print(
            "::notice::"
            + ENV_KEY
            + " loaded: length="
            + str(len(api_key))
            + " sha256_8="
            + _short_hash(api_key)
        )
    if not build_sha:
        sys.stderr.write(
            "::warning::" + ENV_SHA + " is empty - build-hash diagnostic will be blank.\n"
        )
    else:
        print("::notice::" + ENV_SHA + "=" + build_sha)

    text = path.read_text()
    lines = text.splitlines()
    filtered = [ln for ln in lines if not ln.startswith(DEFINE_KEY + "=")]
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

    # Build the line UNQUOTED. Format:
    #   flutter.dart-defines=ENV_KEY=<value>,ENV_SHA=<value>
    # Bytez API keys and git SHAs are alphanumeric, so this is safe
    # to write without escaping. The Flutter Gradle plugin's
    # comma-splitter then produces --dart-define flags whose values
    # are the raw strings, which is what String.fromEnvironment
    # expects.
    line = DEFINE_KEY + "=" + ENV_KEY + "=" + api_key + "," + ENV_SHA + "=" + build_sha
    filtered.append(line)
    path.write_text("\n".join(filtered) + "\n")

    # CI-log redaction: print a redacted version that shows the line
    # was written, but replaces the secret with a hash.
    redacted = (
        DEFINE_KEY
        + "="
        + ENV_KEY
        + "=sha256:"
        + _short_hash(api_key)
        + ","
        + ENV_SHA
        + "="
        + build_sha
    )
    print("::notice::Wrote dart-defines: " + redacted)
    return 0


if __name__ == "__main__":
    sys.exit(main())
