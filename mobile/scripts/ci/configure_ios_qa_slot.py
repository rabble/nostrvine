#!/usr/bin/env python3
# ABOUTME: Patches the iOS Runner project for one QA slot identity.
# ABOUTME: Used by Codemagic before code signing to target a non-production
# ABOUTME: bundle id, app group, display name, and Firebase iOS app id while
# ABOUTME: leaving the production project untouched on disk via --dry-run.

"""Patch iOS project for a QA slot."""

from __future__ import annotations

import argparse
import difflib
import json
import re
import sys
from pathlib import Path

PRODUCTION_BUNDLE_ID = "co.openvine.app"
PRODUCTION_EXTENSION_BUNDLE_ID = "co.openvine.app.NotificationServiceExtension"
PRODUCTION_APP_GROUP = "group.co.openvine.app"
PRODUCTION_DISPLAY_NAME_PATTERN = "INFOPLIST_KEY_CFBundleDisplayName = divine;"
PRODUCTION_FIREBASE_APP_ID = "1:972941478875:ios:f61272b3cf485df244b5fe"


class PatchError(RuntimeError):
    """Raised when an expected production marker is missing from a file."""


def patch_pbxproj(
    text: str,
    *,
    bundle_id: str,
    extension_bundle_id: str,
    display_name: str,
) -> str:
    """Return pbxproj text with QA slot identity applied.

    Replacement order matters: extension first, then main bundle. The main
    bundle pattern is anchored on a trailing semicolon so it never matches
    ``co.openvine.app.NotificationServiceExtension;`` or
    ``co.openvine.app.RunnerTests;``.
    """
    ext_search = f"= {PRODUCTION_EXTENSION_BUNDLE_ID};"
    if ext_search not in text:
        raise PatchError(
            "Expected extension bundle marker not found in pbxproj: "
            f"{ext_search!r}",
        )
    text = text.replace(ext_search, f"= {extension_bundle_id};")

    main_search = f"= {PRODUCTION_BUNDLE_ID};"
    if main_search not in text:
        raise PatchError(
            "Expected main bundle marker not found in pbxproj: "
            f"{main_search!r}",
        )
    text = text.replace(main_search, f"= {bundle_id};")

    if PRODUCTION_DISPLAY_NAME_PATTERN not in text:
        raise PatchError(
            "Expected display-name marker not found in pbxproj: "
            f"{PRODUCTION_DISPLAY_NAME_PATTERN!r}",
        )
    text = text.replace(
        PRODUCTION_DISPLAY_NAME_PATTERN,
        f'INFOPLIST_KEY_CFBundleDisplayName = "{display_name}";',
    )
    return text


def patch_entitlements(text: str, *, app_group: str) -> str:
    """Return entitlements XML with the production app group replaced."""
    needle = f"<string>{PRODUCTION_APP_GROUP}</string>"
    occurrences = text.count(needle)
    if occurrences != 1:
        raise PatchError(
            f"Expected exactly 1 occurrence of {needle!r} in entitlements, "
            f"found {occurrences}",
        )
    return text.replace(needle, f"<string>{app_group}</string>")


def _patch_plist_string(
    text: str,
    *,
    key: str,
    expected: str,
    new_value: str,
) -> str:
    pattern = re.compile(
        r"(<key>" + re.escape(key) + r"</key>\s*<string>)"
        + re.escape(expected)
        + r"(</string>)",
    )
    new_text, count = pattern.subn(
        lambda m: m.group(1) + new_value + m.group(2),
        text,
    )
    if count != 1:
        raise PatchError(
            f"Expected exactly 1 plist value for {key}={expected!r}, "
            f"found {count}",
        )
    return new_text


def patch_google_service_info(
    text: str,
    *,
    bundle_id: str,
    firebase_app_id: str,
) -> str:
    """Return GoogleService-Info.plist text with slot identity applied."""
    text = _patch_plist_string(
        text,
        key="BUNDLE_ID",
        expected=PRODUCTION_BUNDLE_ID,
        new_value=bundle_id,
    )
    text = _patch_plist_string(
        text,
        key="GOOGLE_APP_ID",
        expected=PRODUCTION_FIREBASE_APP_ID,
        new_value=firebase_app_id,
    )
    return text


def patch_firebase_app_id_json(text: str, *, firebase_app_id: str) -> str:
    """Return firebase_app_id_file.json text with slot Firebase app id."""
    pattern = re.compile(
        r'("GOOGLE_APP_ID"\s*:\s*")'
        + re.escape(PRODUCTION_FIREBASE_APP_ID)
        + r'(")',
    )
    new_text, count = pattern.subn(
        lambda m: m.group(1) + firebase_app_id + m.group(2),
        text,
    )
    if count != 1:
        raise PatchError(
            "Expected exactly 1 GOOGLE_APP_ID value in firebase_app_id_file.json, "
            f"found {count}",
        )
    return new_text


def _emit_diff(path: Path, old: str, new: str) -> None:
    if old == new:
        return
    diff = difflib.unified_diff(
        old.splitlines(keepends=True),
        new.splitlines(keepends=True),
        fromfile=str(path),
        tofile=f"{path} (patched)",
    )
    sys.stdout.writelines(diff)


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Patch iOS project for a QA slot identity.",
    )
    parser.add_argument("--project-root", required=True, type=Path)
    parser.add_argument("--bundle-id", required=True)
    parser.add_argument("--extension-bundle-id", required=True)
    parser.add_argument("--app-group", required=True)
    parser.add_argument("--display-name", required=True)
    parser.add_argument("--firebase-ios-app-id", required=True)
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print unified diff to stdout without writing files.",
    )
    return parser.parse_args(argv)


def run(args: argparse.Namespace) -> int:
    root: Path = args.project_root
    pbxproj_path = root / "ios/Runner.xcodeproj/project.pbxproj"
    runner_ent_path = root / "ios/Runner/Runner.entitlements"
    ext_ent_path = (
        root
        / "ios/NotificationServiceExtension/NotificationServiceExtension.entitlements"
    )
    google_plist_path = root / "ios/Runner/GoogleService-Info.plist"
    firebase_json_path = root / "ios/firebase_app_id_file.json"

    plans: list[tuple[Path, str, str]] = []

    pbx_old = pbxproj_path.read_text(encoding="utf-8")
    pbx_new = patch_pbxproj(
        pbx_old,
        bundle_id=args.bundle_id,
        extension_bundle_id=args.extension_bundle_id,
        display_name=args.display_name,
    )
    plans.append((pbxproj_path, pbx_old, pbx_new))

    runner_ent_old = runner_ent_path.read_text(encoding="utf-8")
    runner_ent_new = patch_entitlements(runner_ent_old, app_group=args.app_group)
    plans.append((runner_ent_path, runner_ent_old, runner_ent_new))

    ext_ent_old = ext_ent_path.read_text(encoding="utf-8")
    ext_ent_new = patch_entitlements(ext_ent_old, app_group=args.app_group)
    plans.append((ext_ent_path, ext_ent_old, ext_ent_new))

    google_old = google_plist_path.read_text(encoding="utf-8")
    google_new = patch_google_service_info(
        google_old,
        bundle_id=args.bundle_id,
        firebase_app_id=args.firebase_ios_app_id,
    )
    plans.append((google_plist_path, google_old, google_new))

    firebase_old = firebase_json_path.read_text(encoding="utf-8")
    firebase_new = patch_firebase_app_id_json(
        firebase_old,
        firebase_app_id=args.firebase_ios_app_id,
    )
    plans.append((firebase_json_path, firebase_old, firebase_new))

    # Cosmetic — make sure Firebase JSON stays valid JSON.
    json.loads(firebase_new)

    if args.dry_run:
        for path, old, new in plans:
            _emit_diff(path, old, new)
        return 0

    for path, _old, new in plans:
        path.write_text(new, encoding="utf-8")
    return 0


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        return run(args)
    except PatchError as exc:
        print(f"configure_ios_qa_slot: {exc}", file=sys.stderr)
        return 1
    except FileNotFoundError as exc:
        print(f"configure_ios_qa_slot: missing file: {exc.filename}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
