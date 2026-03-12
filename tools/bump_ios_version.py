#!/usr/bin/env python3

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


TARGET_BUNDLE_IDS = {
    "ru.hippo.Sonora",
    "ru.hippo.Sonora.LovelyWidget",
}

CONFIG_BLOCK_RE = re.compile(
    r"(?P<header>^\s*[A-F0-9]{24} /\* .*? \*/ = \{\n"
    r"\s*isa = XCBuildConfiguration;\n"
    r"\s*buildSettings = \{\n)"
    r"(?P<body>.*?)"
    r"(?P<footer>\s*\};\n\s*name = [^;]+;\n\s*\};)",
    re.MULTILINE | re.DOTALL,
)
BUNDLE_ID_RE = re.compile(r"^\s*PRODUCT_BUNDLE_IDENTIFIER = (?P<value>[^;]+);$", re.MULTILINE)
MARKETING_RE = re.compile(r"^(?P<indent>\s*)MARKETING_VERSION = (?P<value>[^;]+);$", re.MULTILINE)
BUILD_RE = re.compile(r"^(?P<indent>\s*)CURRENT_PROJECT_VERSION = (?P<value>[^;]+);$", re.MULTILINE)


def bump_marketing_version(version: str) -> str:
    parts = version.split(".")
    for index in range(len(parts) - 1, -1, -1):
        if parts[index].isdigit():
            parts[index] = str(int(parts[index]) + 1)
            return ".".join(parts)
    raise ValueError(f"Cannot auto-increment MARKETING_VERSION '{version}'")


def bump_build_number(build_number: str) -> str:
    if not build_number.isdigit():
        raise ValueError(f"Cannot auto-increment CURRENT_PROJECT_VERSION '{build_number}'")
    return str(int(build_number) + 1)


def update_block(body: str, marketing_version: str, build_number: str) -> str:
    updated = MARKETING_RE.sub(rf"\g<indent>MARKETING_VERSION = {marketing_version};", body, count=1)
    updated = BUILD_RE.sub(rf"\g<indent>CURRENT_PROJECT_VERSION = {build_number};", updated, count=1)
    return updated


def main() -> int:
    default_project_path = Path(__file__).resolve().parents[1] / "Sonora.xcodeproj" / "project.pbxproj"
    parser = argparse.ArgumentParser(description="Increment iOS app/widget MARKETING_VERSION and CURRENT_PROJECT_VERSION.")
    parser.add_argument(
        "--project",
        default=str(default_project_path),
        help="Path to the Xcode project.pbxproj file.",
    )
    args = parser.parse_args()

    project_path = Path(args.project)
    if not project_path.is_file():
        print(f"Project file not found: {project_path}", file=sys.stderr)
        return 1

    original_text = project_path.read_text(encoding="utf-8")
    current_marketing_version = None
    current_build_number = None
    updated_text = original_text
    updated_bundle_ids: list[str] = []

    def replace_block(match: re.Match[str]) -> str:
        nonlocal current_marketing_version
        nonlocal current_build_number

        body = match.group("body")
        bundle_id_match = BUNDLE_ID_RE.search(body)
        if bundle_id_match is None:
            return match.group(0)

        bundle_id = bundle_id_match.group("value")
        if bundle_id not in TARGET_BUNDLE_IDS:
            return match.group(0)

        marketing_match = MARKETING_RE.search(body)
        build_match = BUILD_RE.search(body)
        if marketing_match is None or build_match is None:
            raise ValueError(f"Missing version settings in configuration for {bundle_id}")

        block_marketing_version = marketing_match.group("value")
        block_build_number = build_match.group("value")

        if current_marketing_version is None:
            current_marketing_version = block_marketing_version
        elif block_marketing_version != current_marketing_version:
            raise ValueError(
                f"Inconsistent MARKETING_VERSION values: {current_marketing_version} vs {block_marketing_version}"
            )

        if current_build_number is None:
            current_build_number = block_build_number
        elif block_build_number != current_build_number:
            raise ValueError(
                f"Inconsistent CURRENT_PROJECT_VERSION values: {current_build_number} vs {block_build_number}"
            )

        updated_bundle_ids.append(bundle_id)
        next_marketing_version = bump_marketing_version(current_marketing_version)
        next_build_number = bump_build_number(current_build_number)
        updated_body = update_block(body, next_marketing_version, next_build_number)
        return f"{match.group('header')}{updated_body}{match.group('footer')}"

    try:
        updated_text = CONFIG_BLOCK_RE.sub(replace_block, original_text)
    except ValueError as error:
        print(str(error), file=sys.stderr)
        return 1

    if current_marketing_version is None or current_build_number is None:
        print("No matching app/widget build configurations were found.", file=sys.stderr)
        return 1

    next_marketing_version = bump_marketing_version(current_marketing_version)
    next_build_number = bump_build_number(current_build_number)
    project_path.write_text(updated_text, encoding="utf-8")

    touched_targets = ", ".join(sorted(set(updated_bundle_ids)))
    print(
        f"Updated {project_path}: "
        f"MARKETING_VERSION {current_marketing_version} -> {next_marketing_version}, "
        f"CURRENT_PROJECT_VERSION {current_build_number} -> {next_build_number} "
        f"for {touched_targets}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
