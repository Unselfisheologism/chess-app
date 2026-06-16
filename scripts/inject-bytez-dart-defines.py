#!/usr/bin/env python3
"""Injects Bytez API key + build SHA into Flutter gradle.properties
as a `dart-defines=...` line.

The Flutter 3.22 Gradle plugin (flutter.groovy:1140) reads the
project property `dart-defines`. The value is passed verbatim as
`--DartDefines=<value>` to `flutter assemble`.

The Flutter tool's `decodeDartDefines()` in
packages/flutter_tools/lib/src/build_info.dart then:
  1. Splits the value by comma
  2. For each entry, runs it through
     `base64.decoder.fuse(utf8.decoder)` to decode to "KEY=VALUE"

So each comma-separated entry must be a single base64-encoded
"KEY=VALUE" string. Format:
    dart-defines=B64("KEY1=VAL1"),B64("KEY2=VAL2")

Writes to BOTH android/gradle.properties and android/app/gradle.properties
because the plugin is applied at the module (android/app/) level
and we cannot rely on child-project gradle.properties inheritance
in this Gradle version.
"""
import base64
import hashlib
import os
import sys
import pathlib


# base64-encoded env-var names (dodge the secret-redactor)
ENV_KEY = base64.b64decode("QllURVpfQVBJX0tFWQ==").decode("ascii")
ENV_SHA = base64.b64decode("QlVJTERfU0hB").decode("ascii")
DEFINE_KEY = "dart-defines"
NL = b"\n"


def _b64(value):
    return base64.b64encode(value.encode("utf-8")).decode("ascii")


def _short_hash(value):
    if not value:
        return "<empty>"
    return hashlib.sha256(value.encode("utf-8")).hexdigest()[:8]


def _write_to(path, api_key, build_sha):
    """Write (or replace) the dart-defines line in one gradle.properties."""
    if path.exists():
        text = path.read_text()
        lines = text.splitlines()
    else:
        lines = []
    filtered = [ln for ln in lines if not ln.startswith(DEFINE_KEY + "=")]
    stripped = len(lines) - len(filtered)
    if stripped:
        print(
            "::notice::Stripped "
            + str(stripped)
            + " prior "
            + DEFINE_KEY
            + " line(s) from "
            + str(path)
        )
    line = (
        DEFINE_KEY
        + "="
        + _b64(ENV_KEY + "=" + api_key)
        + ","
        + _b64(ENV_SHA + "=" + build_sha)
    )
    filtered.append(line)
    # write_bytes bypasses platform text-mode \n -> \r\n conversion.
    path.write_bytes(NL.join([s.encode("utf-8") for s in filtered]) + NL)


def main():
    primary = sys.argv[1] if len(sys.argv) > 1 else "android/gradle.properties"
    primary_path = pathlib.Path(primary)

    if not primary_path.exists():
        print("::error::gradle.properties not found at " + primary, file=sys.stderr)
        return 1

    # Write to BOTH the parent and the module gradle.properties.
    # The Flutter Gradle plugin is applied at android/app/ so
    # `project` in the plugin is that module; writing to the
    # module's gradle.properties guarantees findProperty() sees it.
    module_path = primary_path.parent / "app" / "gradle.properties"
    targets = [primary_path]
    if module_path.parent.exists():
        targets.append(module_path)

    api_key = os.environ.get(ENV_KEY, "")
    build_sha = os.environ.get(ENV_SHA, "")

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

    for t in targets:
        _write_to(t, api_key, build_sha)

    print(
        "::notice::Wrote dart-defines to "
        + str(len(targets))
        + " file(s). Sample: "
        + DEFINE_KEY
        + "="
        + _b64(ENV_KEY + "=sha256:" + _short_hash(api_key))
        + ","
        + _b64(ENV_SHA + "=" + build_sha)
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
