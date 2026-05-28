#!/usr/bin/env bash
# Fails CI if a new `extends ChangeNotifier` appears in mobile/lib/ outside
# the sanctioned allowlist.
#
# Rule enforced:
#   * No `extends ChangeNotifier` in mobile/lib/ outside the file allowlist
#     below. Adding a new sanctioned ChangeNotifier requires editing both
#     this script's ALLOWLIST and the "Sanctioned Riverpod (STAYS)" table
#     in docs/BLOC_UI_MIGRATION_PRD.md in the same PR.
#
# Background:
#   Divine is mid-migration from Riverpod / ChangeNotifier to BLoC/Cubit for
#   UI state. The "Sanctioned Riverpod (STAYS)" section in
#   docs/BLOC_UI_MIGRATION_PRD.md enumerates the files that hold infrastructure
#   (DI / services / caches / router plumbing) and are out of scope for
#   #4744's Riverpod → BLoC lane. This guard prevents the carve-out from
#   silently regrowing — every new UI-state ChangeNotifier in mobile/lib/
#   must be migrated to a Cubit, not added here.
#
# Allowlist policy:
#   * Files in ALLOWLIST below must hold ZERO feature UI state — they own
#     infrastructure, a service, a cache, router plumbing, or preferences.
#   * Adding a file to ALLOWLIST is reviewed against that criterion and must
#     come with a matching docs table entry.
#
# Usage:
#   bash mobile/scripts/check_changenotifier_boundary.sh
#   (run from the repository root or from mobile/)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# ---------------------------------------------------------------------------
# Allowlist — paths are relative to mobile/lib/. Keep in sync with the
# "Sanctioned Riverpod (STAYS)" table in docs/BLOC_UI_MIGRATION_PRD.md.
# ---------------------------------------------------------------------------

ALLOWLIST=(
  "providers/individual_video_providers.dart"
  "features/feature_flags/services/feature_flag_service.dart"
  "router/app_router.dart"
  "services/connection_status_service.dart"
  "services/content_filter_service.dart"
  "services/curated_list_service.dart"
  "services/divine_host_filter_service.dart"
  "services/environment_service.dart"
  "services/feed_aspect_ratio_preference_service.dart"
  "services/nip05_verification_service.dart"
  "services/og_viner_cache_service.dart"
  "services/pending_action_service.dart"
  "services/relay_statistics_service.dart"
  "services/subscribed_list_video_cache.dart"
  "services/video_event_service.dart"
)

# ---------------------------------------------------------------------------
# Find every file under mobile/lib/ that contains `extends ChangeNotifier`,
# excluding generated files and build artifacts. Then filter out allowlisted
# entries. Anything that survives is a violation.
# ---------------------------------------------------------------------------

GLOBAL_EXCLUDES=(
  -not -path "*/.dart_tool/*"
  -not -path "*/build/*"
  -not -name "*.g.dart"
  -not -name "*.freezed.dart"
  -not -name "*.mocks.dart"
)

FOUND=$(
  find "$MOBILE_DIR/lib" \
    "${GLOBAL_EXCLUDES[@]}" \
    -name "*.dart" -print0 \
  | xargs -0 grep -l "extends ChangeNotifier" 2>/dev/null \
  || true
)

VIOLATIONS=""
if [[ -n "$FOUND" ]]; then
  while IFS= read -r abs_path; do
    rel="${abs_path#$MOBILE_DIR/lib/}"
    allowed=0
    for entry in "${ALLOWLIST[@]}"; do
      if [[ "$rel" == "$entry" ]]; then
        allowed=1
        break
      fi
    done
    if [[ "$allowed" -eq 0 ]]; then
      VIOLATIONS+="  mobile/lib/$rel"$'\n'
    fi
  done <<< "$FOUND"
fi

if [[ -n "$VIOLATIONS" ]]; then
  echo "FAIL [changenotifier_boundary]: new \`extends ChangeNotifier\` found outside the sanctioned allowlist:"
  printf '%s' "$VIOLATIONS"
  echo ""
  echo "For UI state, use a BLoC/Cubit instead of \`extends ChangeNotifier\`."
  echo "If the new class is genuinely DI / service / cache / router plumbing"
  echo "(0 feature UI state), add it to the ALLOWLIST in this script AND to"
  echo "the 'Sanctioned Riverpod (STAYS)' table in docs/BLOC_UI_MIGRATION_PRD.md"
  echo "in the same PR."
  exit 1
fi

echo "OK: No new ChangeNotifier classes outside the sanctioned allowlist."
