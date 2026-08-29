# Brainstorm: removing error strings from BLoC state (#3591)

Date: 2026-08-29

## Problem Statement

Four BLoC state classes still store user-facing error strings, which
`.claude/rules/state_management.md` and `.claude/rules/error_handling.md`
forbid ("State must NEVER contain error messages, error strings, or exception
objects"). Three of the four render that string to the user untranslated, and
two of those render raw platform-exception text. Investigation
(`tasks/findings_3591.md`) confirmed every claim in the issue and found the
issue understates the problem.

## Constraints

- Layered flow `UI -> BLoC/Cubit -> Repository -> Client`; state carries codes,
  the UI maps codes to `context.l10n`.
- 22 ARB locales; every key added to `app_en.arb` must be mirrored and must be
  read through `context.l10n` in the same change (orphan ratchet #3630).
- `divine_ui` stays l10n-free — its widgets take string params with English
  defaults, so localization happens at the calling widget.
- Copy-alignment policy: do not silently reword existing English while
  migrating; that is a separate product change.
- All four sites are matrix-NO per the error-handling decision matrix, so
  bare `addError`, no `Reportable` wraps.

## Prior Art (all merged, all read directly)

| Shape | Precedent | Where |
|---|---|---|
| A — delete a dead message field | `DraftsLibraryError` (PR #3029 / #3074) | `blocs/drafts_library/` |
| B1 — nullable reason enum + `clearX` on a flat state | `CrosspostSettingsError` | `blocs/crosspost_settings/crosspost_settings_state.dart:10` |
| B1 — reason enum beside a status enum | `ProfileEditorError`, `AvatarUploadError` | `blocs/profile_editor/profile_editor_state.dart:43` |
| B2 — standalone reason enum below the bloc | `PublishErrorKind`, `InviteActivationFailureReason` | `services/video_publish/publish_error_kind.dart`, `utils/invite_error_utils.dart:12` |
| UI mapping | `extension <Enum>L10n on AppLocalizations`, exhaustive switch, no `default` | 5 files under `lib/l10n/` |
| In-file precedent | `SignInFailureReason` — same class as one of our targets | `blocs/divine_auth/divine_auth_state.dart:6` |

`InviteErrorUtils.activationFailureReason` already classifies the exact
`InviteApiErrorCode` family site 1 needs, and its legacy string twin is
explicitly marked for deletion once callers migrate.

## Approaches Explored

### Approach A — per-site reason enums, matching existing precedent

Give each site the smallest correct shape: delete where the field is dead,
introduce a per-feature reason enum where it is rendered, and map to copy in
the UI via an `AppLocalizations` extension or an inline switch.

**Layers:** BLoC state (all four), one service contract (camera), UI (4 widgets),
l10n (new extension + ARB keys).

**Pros:** Matches five merged precedents exactly. Each site stays independently
reviewable and revertable. Fixes the l10n gap for 21 locales as a direct
consequence. Makes the URL-injection payload unrepresentable rather than
filtered.

**Cons:** Touches four unrelated features in one PR; two of the files are hot
(`clips_library_state.dart`, `video_recorder_state.dart`, both owned by one
author), so rebase risk is real.

**Complexity:** Medium.

### Approach B — one shared cross-feature failure enum

A single `AppFailureReason` plus one l10n extension reused everywhere.

**Rejected.** It contradicts all five precedents, which are deliberately
per-feature; it would force vague copy across unrelated domains (a waveform
decode failure and an invite rejection are not the same "reason"); and it is
YAGNI — nothing needs a shared vocabulary. Naming rule observed in the repo is
`*Error` in the state file, `*Kind`/`*FailureReason` standalone; there is no
global enum anywhere.

### Approach C — ship a shrink-only CI ratchet alongside the fix

Add `check_bloc_state_error_strings.sh` frozen at zero with a Dart AST
detector, mirroring `post_close_emit_detector.dart`.

**Deferred by decision.** Strong long-term fit (the repo runs ~a dozen such
ratchets, and this defect class demonstrably re-accreted between April and
August 2026), but the detector's hard part is distinguishing legitimate content
strings (`outage_notice.operatorMessage`, `clips_library.categoryName`) from
error strings — a naming heuristic needing its own tuning and baseline. It
would dominate this diff. Belongs in its own PR.

### Approach D — sanitize the ingress only

Escape/allowlist the `?error=` query param and stop interpolating raw
exceptions, but leave the fields typed `String?`.

**Rejected as the primary fix.** Treats the symptom: the copy stays English in
21 locales, the rule stays violated, and the next contributor can reintroduce
raw text. Retained only as the *workaround* if the real fix must be deferred.

## Decisions taken

1. **Approach A**, scoped to the four sites named in the issue. The fifth site
   found during investigation (`DivineAuthFormState`) and three
   result-object-shaped sites (`WatermarkDownloadResult`, `PublishResult`,
   `DeleteResult`) go to follow-up issues.
2. **No ratchet in this PR.**
3. **`?error=` stops being rendered verbatim.** Verified at full confidence
   that nothing in the mobile app nor in `divine-invite-darshan`,
   `divine-invite-sync`, `divine-web`, `divine-login` or `divine-router` ever
   *generates* such a link — the only in-app producer
   (`invite_gate_screen.dart:128`) merely re-propagates what arrived. It is a
   pure external ingress with no contract, so the presence of the parameter is
   kept as a signal ("something went wrong upstream" -> a generic localized
   message) while the attacker-controlled payload is discarded.
4. **Copy is carried over verbatim** into new ARB keys rather than reworded, per
   the copy-alignment policy. The one genuinely new string is the generic
   upstream-error case.

## Per-site shape

| Site | Shape | Notes |
|---|---|---|
| `SoundWaveformError.message` | A — delete | No reader binds it; `addError` already covers diagnostics |
| `VideoRecorderBlocState.errorMessage` getter | A — delete | Dead: no caller anywhere |
| `GallerySaveResultError.message` | A — delete + fixed localized copy | Single defensive catch; one case, so no enum earns its keep |
| `VideoRecorderBlocState.initializationErrorMessage` | B1 — `CameraInitializationError?` | Requires changing `CameraBaseService.initializationError` from `String?` to the enum (2 impls, 1 mock, 2 test files) |
| `InviteGateState.inviteCodeError` / `generalError` | B1 — two enums + `clearX` | Ported from `CrosspostSettingsError`; reuses `InviteErrorUtils.activationFailureReason` for the API branch |

## Open Questions for /plan

- [x] Scope — resolved: four sites.
- [x] Ratchet — resolved: not in this PR.
- [x] `?error=` behaviour — resolved: generic localized message.
- [ ] Exact ARB key names and their `@` descriptions.
- [ ] Whether `camera_linux_service_test` assertions move to enum identity.

## Next Step

`/plan 3591`.
