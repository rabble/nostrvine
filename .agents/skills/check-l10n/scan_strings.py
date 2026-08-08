#!/usr/bin/env python3
"""
Scan changed Dart files for likely user-visible English strings that
bypass localization (l10n).

Usage:
    scan_strings.py [FILES...]

If no files are given, scans the union of staged + unstaged changes
relative to the working tree.

Exit code:
    0 → no findings
    1 → one or more candidate leaks; details printed to stdout

The scanner is intentionally noisy in the "you might have missed this"
direction; final judgment is human. False positives are easier to
dismiss than false negatives are to debug in production.
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

REPO_ROOT_MARKER = "mobile/pubspec.yaml"


def find_repo_root(start: Path) -> Path:
    cur = start.resolve()
    while cur != cur.parent:
        if (cur / REPO_ROOT_MARKER).exists():
            return cur
        cur = cur.parent
    raise SystemExit(f"Could not find {REPO_ROOT_MARKER} above {start}")


# Paths we never scan. Patterns are matched against the path relative
# to the repo root.
EXCLUDED_PREFIXES = (
    "mobile/test/",
    "mobile/integration_test/",
    "mobile/lib/l10n/",
    "mobile/build/",
    "mobile/.dart_tool/",
)
EXCLUDED_SUFFIXES = (
    ".g.dart",
    ".freezed.dart",
    ".gr.dart",
    ".mocks.dart",
)


# Lines to skip wholesale because the literal string is going to logs,
# analytics, or developer-only surfaces — not the user.
SKIP_LINE_PATTERNS = [
    re.compile(r"\bLog\.(?:debug|info|warning|error|fatal|trace)\("),
    re.compile(r"\bdeveloper\.log\("),
    re.compile(r"\bdebugPrint\("),
    re.compile(r"\bprint\("),
    re.compile(r"\bassert\("),
    re.compile(r"\bthrow\s+\w*Exception\("),
    re.compile(r"\bthrow\s+ArgumentError\("),
    re.compile(r"\bthrow\s+StateError\("),
    re.compile(r"\bSemantics\(\s*identifier:"),
    re.compile(r"\bidentifier:\s*['\"]"),
    re.compile(r"\bRouteNames?\."),
    # Common pure-debug / diagnostic strings
    re.compile(r"category:\s*LogCategory"),
    re.compile(r"name:\s*['\"][A-Z][A-Za-z]+['\"]"),  # name: 'ProfileFeedProvider'
]


@dataclass
class Finding:
    path: str
    line_no: int
    col: int
    text: str
    rule: str

    def format(self) -> str:
        return f"{self.path}:{self.line_no}:{self.col}  [{self.rule}]  {self.text}"


# Each rule is (name, regex). The capture group `s` holds the literal.
RULES = [
    (
        "Text-literal",
        re.compile(
            r"""\b(?:const\s+)?Text\(\s*(?P<q>['"])(?P<s>(?:(?!(?P=q)).)+)(?P=q)"""
        ),
    ),
    (
        "AppBar-title-Text",
        re.compile(
            r"""\btitle:\s*(?:const\s+)?Text\(\s*(?P<q>['"])(?P<s>(?:(?!(?P=q)).)+)(?P=q)"""
        ),
    ),
    (
        "label-arg",
        re.compile(
            r"""\blabel:\s*(?P<q>['"])(?P<s>(?:(?!(?P=q)).)+)(?P=q)"""
        ),
    ),
    (
        "title-arg",
        re.compile(
            r"""\btitle:\s*(?P<q>['"])(?P<s>(?:(?!(?P=q)).)+)(?P=q)"""
        ),
    ),
    (
        "hintText-arg",
        re.compile(
            r"""\bhintText:\s*(?P<q>['"])(?P<s>(?:(?!(?P=q)).)+)(?P=q)"""
        ),
    ),
    (
        "helperText-arg",
        re.compile(
            r"""\bhelperText:\s*(?P<q>['"])(?P<s>(?:(?!(?P=q)).)+)(?P=q)"""
        ),
    ),
    (
        "tooltip-arg",
        re.compile(
            r"""\btooltip:\s*(?P<q>['"])(?P<s>(?:(?!(?P=q)).)+)(?P=q)"""
        ),
    ),
    (
        "Tooltip-message",
        re.compile(
            r"""\bTooltip\([^)]*\bmessage:\s*(?P<q>['"])(?P<s>(?:(?!(?P=q)).)+)(?P=q)"""
        ),
    ),
    (
        "semanticLabel-arg",
        re.compile(
            r"""\bsemanticLabel:\s*(?P<q>['"])(?P<s>(?:(?!(?P=q)).)+)(?P=q)"""
        ),
    ),
    (
        "semanticsLabel-arg",
        re.compile(
            r"""\bsemanticsLabel:\s*(?P<q>['"])(?P<s>(?:(?!(?P=q)).)+)(?P=q)"""
        ),
    ),
    # Positional string passed to a clearly user-visible setter/show call.
    # Catches things like _setGeneralError('...'), showSnackBar('...'),
    # showErrorDialog('...'), _setMessage("..."), etc.
    # The (?:^|\W) anchor makes this work whether the method is at line
    # start, after a `.`, after `_`, or after whitespace.
    (
        "user-message-call",
        re.compile(
            r"""(?:^|[^A-Za-z0-9])"""
            r"""[_A-Za-z]*"""
            r"""(?:[sS]how|[sS]et|[dD]isplay|[eE]mit)"""
            r"""[A-Za-z_]*"""
            r"""(?:Error|Message|Snackbar|SnackBar|Toast|Dialog|Banner|Notification)"""
            r"""\(\s*(?P<q>['"])(?P<s>(?:(?!(?P=q)).)+)(?P=q)"""
        ),
    ),
]


def looks_user_visible_english(s: str) -> bool:
    """Heuristic — does the string look like English UI copy?

    True when it has at least one space-separated pair of words and
    starts with a letter or punctuation. Excludes obvious identifiers,
    asset paths, URLs, and machine-readable values.
    """
    s = s.strip()
    if len(s) < 3:
        return False
    # URLs / asset paths / package URIs
    if re.match(r"(https?:|wss?:|nostr:|asset|assets/|packages/)", s):
        return False
    # File-like
    if re.fullmatch(r"[\w./-]+\.(png|jpg|svg|webp|json|dart|yaml|md)", s):
        return False
    # snake_case identifier
    if re.fullmatch(r"[a-z][a-z0-9_]*", s):
        return False
    # SCREAMING_SNAKE
    if re.fullmatch(r"[A-Z][A-Z0-9_]+", s):
        return False
    # camelCase identifier (no space)
    if " " not in s and re.fullmatch(r"[a-zA-Z][a-zA-Z0-9]*", s):
        return False
    # Hex / numeric / color
    if re.fullmatch(r"[0-9.,#xA-Fa-f-]+", s):
        return False
    # Format strings consisting only of placeholders
    if re.fullmatch(r"[\s${}\w._-]*", s) and "$" in s and " " not in s:
        return False
    # Must contain a space OR be a clear UI sentence; if no space we
    # probably don't have user copy unless it's a multi-word phrase
    # already excluded above.
    if " " not in s:
        return False
    # Must contain at least two letters
    if len(re.findall(r"[A-Za-z]", s)) < 2:
        return False
    # If the string is already a localized lookup result it would be a
    # variable name on the line, not a literal. Lines coming through
    # context.l10n.* will not match the literal-string regexes above.
    return True


def is_skip_line(line: str) -> bool:
    return any(p.search(line) for p in SKIP_LINE_PATTERNS)


# Smaller number = more specific rule. Used when the same literal
# matches multiple rules (e.g. `title: Text('Foo')` matches both
# Text-literal and AppBar-title-Text).
_RULE_RANK = {
    "AppBar-title-Text": 0,
    "Tooltip-message": 1,
    "tooltip-arg": 2,
    "hintText-arg": 3,
    "helperText-arg": 4,
    "semanticLabel-arg": 5,
    "semanticsLabel-arg": 5,
    "title-arg": 6,
    "label-arg": 7,
    "Text-literal": 99,
}


def _rule_specificity(rule: str) -> int:
    return _RULE_RANK.get(rule, 50)


def scan_file(path: Path, repo_root: Path) -> list[Finding]:
    rel = str(path.relative_to(repo_root))
    if any(rel.startswith(p) for p in EXCLUDED_PREFIXES):
        return []
    if any(rel.endswith(s) for s in EXCLUDED_SUFFIXES):
        return []
    if not rel.endswith(".dart"):
        return []
    if not rel.startswith("mobile/lib/"):
        return []

    findings: list[Finding] = []
    try:
        text = path.read_text(encoding="utf-8")
    except (UnicodeDecodeError, FileNotFoundError):
        return []

    for line_no, line in enumerate(text.splitlines(), start=1):
        if is_skip_line(line):
            continue
        for rule_name, regex in RULES:
            for m in regex.finditer(line):
                literal = m.group("s")
                if not looks_user_visible_english(literal):
                    continue
                findings.append(
                    Finding(
                        path=rel,
                        line_no=line_no,
                        col=m.start("s") + 1,
                        text=literal,
                        rule=rule_name,
                    )
                )
    return findings


def changed_files(repo_root: Path) -> list[Path]:
    """Return files modified vs HEAD (staged + unstaged + untracked)."""
    cmd = ["git", "-C", str(repo_root), "status", "--porcelain"]
    out = subprocess.check_output(cmd, text=True)
    files: list[Path] = []
    for raw in out.splitlines():
        if len(raw) < 4:
            continue
        # Format: XY <path> or XY <orig> -> <new>
        rest = raw[3:]
        if " -> " in rest:
            rest = rest.split(" -> ", 1)[1]
        candidate = repo_root / rest
        if candidate.is_file():
            files.append(candidate)
    return files


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "files",
        nargs="*",
        help="Specific files to scan. Default: changed files vs working tree.",
    )
    parser.add_argument(
        "--repo-root",
        default=None,
        help="Override repo-root detection.",
    )
    args = parser.parse_args()

    cwd = Path.cwd()
    repo_root = (
        Path(args.repo_root).resolve() if args.repo_root else find_repo_root(cwd)
    )

    if args.files:
        targets = [Path(f).resolve() for f in args.files]
    else:
        targets = changed_files(repo_root)

    all_findings: list[Finding] = []
    for path in targets:
        if not path.exists():
            continue
        all_findings.extend(scan_file(path, repo_root))

    # Dedupe: a single literal on a line can match multiple rules
    # (e.g. AppBar-title-Text and Text-literal). Keep the most specific
    # rule by collapsing on (path, line, col, text).
    seen: dict[tuple[str, int, int, str], Finding] = {}
    for f in all_findings:
        key = (f.path, f.line_no, f.col, f.text)
        prev = seen.get(key)
        if prev is None or _rule_specificity(f.rule) < _rule_specificity(prev.rule):
            seen[key] = f
    all_findings = list(seen.values())

    # Group findings by file for readable output
    if not all_findings:
        print("No likely hardcoded English strings found.")
        return 0

    # Sort by path then line
    all_findings.sort(key=lambda f: (f.path, f.line_no, f.col))

    last_path = None
    for f in all_findings:
        if f.path != last_path:
            print(f"\n  {f.path}")
            last_path = f.path
        print(f"    L{f.line_no}:{f.col}  [{f.rule}]  {f.text!r}")

    print(
        f"\n{len(all_findings)} candidate(s) found. Each line is a literal that "
        "looks like user-visible English; route it through context.l10n.<key>, "
        "or accept the false positive."
    )
    return 1


if __name__ == "__main__":
    sys.exit(main())
