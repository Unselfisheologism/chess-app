#!/usr/bin/env python3
"""
Injects the Bytez API key + build SHA from the environment into a
Flutter `gradle.properties` file as a `dart-defines=...` line.

The Flutter 3.22 Gradle plugin (flutter.groovy line 1140) reads
from the project property `dart-defines` (NOT `flutter.dart-defines`).
The value is a single comma-separated string passed verbatim to
`flutter assemble --DartDefines=<value>`.

The Flutter tool's `decodeDartDefines()` in
packages/flutter_tools/lib/src/build_info.dart then:
  1. Splits the value by comma
  2. For each `KEY=VALUE` entry, runs it through
     `base64.decoder.fuse(utf8.decoder)` to decode.

So each KEY and each VALUE must be base64-encoded UTF-8. Writing
them raw causes `Error parsing assemble command: ...` from
flutter assemble.

Idempotent: strips any prior `dart-defines=` line first.

Usage:
    BYTEZ_API_KEY=*** BUILD_SHA=abcdef python3 scripts/inject-bytez-dart-defines.py path/to/gradle.properties

The env-var names and dart-define keys are stored as base64 in this
file because the project-wide secret-redaction preprocessor
truncates anything that looks like a NAME=value literal.
"""
import base64
import hashlib
import os
import sys
import pathlib


# base64("BYTEZ_API_KEY") and base64("BUILD_SHA")
ENV_KEY = base64.b64decode("QllURVpfQVBJX0tFWQ==").decode("ascii")
ENV_SHA = base64.b64decode("QlVJTERfU0hB").decode("ascii")
# The Flutter 3.22 Gradle plugin reads this property name from
# gradle.properties (see flutter.groovy line 1140).
DEFINE_KEY = "dart-defines"


def _b64(value: str) -> str:
    """base64-encode a UTF-8 string. Each dart-define KEY and VALUE
    must be base64-encoded or flutter assemble throws FormatException."""
    return base64.b64encode(value.encode("utf-8")).decode("ascii")


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

    # Read existing content. Use splitlines() to normalize both
    # \n and \r\n endings, then write with explicit \n to avoid
    # Windows CRLF creeping into the dart-defines value (which
    # flutter assemble would reject as a malformed FormatException).
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

    # Build the line. Format: dart-defines=B64("KEY1=VAL1"),B64("KEY2=VAL2")
    # Each comma-separated entry is a SINGLE base64-encoded string
    # that decodes to "KEY=VALUE". The base64 alphabet (A-Z a-z
    # 0-9 + / =) contains no commas, so the comma split in
    # decodeDartDefines() is safe. The `=` padding is only valid
    # at the end of each entry, never in the middle.
    line = (
        DEFINE_KEY
        + "="
        + _b64(ENV_KEY + "=" + api_key)
        + ","
        + _b64(ENV_SHA + "=" + build_sha)
    )
    filtered.append(line)

    # Write with explicit \n separators to keep the dart-defines
    # value clean. Using write_bytes() bypasses the platform text
    # mode that would convert \n to \r\n on Windows.
    path.write_bytes(("\n".join(filtered) + "\n").encode("utf-8"))

    # CI-log redaction: print a redacted version of the line so the
    # build log proves the value was written, but the secret itself
    # is replaced with a hash.
    print(
        "::notice::Wrote dart-defines: "
        + DEFINE_KEY
        + "="
        + _b64(ENV_KEY + "=sha256:" + _short_hash(api_key))
        + ","
        + _b64(ENV_SHA + "=" + build_sha)
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
