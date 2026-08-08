#!/bin/bash
# Generate or verify the Codex skill mirror from the canonical Claude skills.

set -e

MODE="${1:---check}"
case "$MODE" in
  --check|--write)
    ;;
  *)
    echo "Usage: $0 [--check|--write]" >&2
    exit 2
    ;;
esac

REPO_ROOT=$(git rev-parse --show-toplevel)
SOURCE_DIR="$REPO_ROOT/.claude/skills"
DEST_DIR="$REPO_ROOT/.agents/skills"
TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/divine-agent-skills.XXXXXX")
trap 'rm -rf "$TEMP_DIR"' EXIT

cp -R "$SOURCE_DIR/." "$TEMP_DIR/"

replace_literal() {
  local file="$1"
  local old="$2"
  local new="$3"
  OLD_TEXT="$old" NEW_TEXT="$new" perl -0pi -e '
    BEGIN { $old = $ENV{"OLD_TEXT"}; $new = $ENV{"NEW_TEXT"}; }
    s/\Q$old\E/$new/g;
  ' "$TEMP_DIR/$file"
}

# Codex-specific locations and terminology.
replace_literal "art-direct/SKILL.md" \
  "~/.claude/skills/art-direct/styles/" \
  "~/.agents/skills/art-direct/styles/"
replace_literal "art-direct/docs/2026-01-28-art-direct-design.md" \
  "~/.claude/skills/art-direct/styles/" \
  "~/.agents/skills/art-direct/styles/"
replace_literal "check-l10n/SKILL.md" \
  ".claude/skills/check-l10n/scan_strings.py" \
  ".agents/skills/check-l10n/scan_strings.py"
replace_literal "claudeception/SKILL.md" \
  "~/.claude/journal" \
  "~/.codex/journal"

replace_literal "divine-context/SKILL.md" \
  "Every divine-* repo's \`CLAUDE.md\`" \
  "Every divine-* repo's \`AGENTS.md\`"
replace_literal "divine-context/SKILL.md" \
  "this repo's \`CLAUDE.md\` or" \
  "this repo's \`AGENTS.md\` or"
replace_literal "divine-context/SKILL.md" \
  "\`README.md\`, \`CLAUDE.md\`, \`AGENTS.md\`," \
  "\`README.md\`, \`AGENTS.md\`,"
replace_literal "divine-context/SKILL.md" \
  "belongs in \`CLAUDE.md\`." \
  "belongs in \`AGENTS.md\`."

replace_literal "review-before-commit/SKILL.md" \
  "CLAUDE.md rule violations" \
  "AGENTS.md rule violations"
replace_literal "review-before-commit/SKILL.md" \
  "#### CLAUDE.md Rule Violations" \
  "#### AGENTS.md Rule Violations"
replace_literal "review-before-commit/SKILL.md" \
  ".claude/CLAUDE.md" \
  "AGENTS.md"
replace_literal "review-before-commit/SKILL.md" "Claude's benefit" "Codex's benefit"
replace_literal "review-before-commit/SKILL.md" \
  "/review-before-commit" \
  "\$review-before-commit"

# Preserve the citation layout without trailing whitespace, which diff --check
# rejects in newly generated files.
perl -pi -e 's/ {2}$/<br>/' \
  "$TEMP_DIR/claudeception/resources/research-references.md"

# These source files contain inert whitespace inside examples. Keep the mirror
# diff-clean while leaving the canonical Claude files untouched.
perl -pi -e 's/[ \t]+$//' \
  "$TEMP_DIR/curl-head-vs-get-header-debugging/SKILL.md" \
  "$TEMP_DIR/docker-buildx-stale-rust-binary/SKILL.md"

if [ "$MODE" = "--write" ]; then
  mkdir -p "$DEST_DIR"
  rsync -a --delete "$TEMP_DIR/" "$DEST_DIR/"
  echo "Updated .agents/skills from .claude/skills."
  exit 0
fi

if ! diff -ru "$DEST_DIR" "$TEMP_DIR" >/dev/null; then
  echo ".agents/skills is out of sync with its canonical source." >&2
  echo "Run: .codex/scripts/sync-agent-skills.sh --write" >&2
  diff -ru "$DEST_DIR" "$TEMP_DIR" || true
  exit 1
fi

echo ".agents/skills is in sync."
