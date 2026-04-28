# CI/CD Issues

Issues related to continuous integration, continuous delivery, and build pipeline configuration.

Note: 33 packages use VGV's reusable CI workflow, the mobile app CI runs tests across 8 shards, and quality gates enforce PR format and issue linking. These 3 issues cover the gaps: 7 packages with no CI workflow, no coverage enforcement for the main app, and inconsistent package coverage thresholds (20%–100%).

## Workflow inventory

```
40 workflow files total
├── 33 package CI workflows (VeryGoodOpenSource/very_good_workflows@v1)
│   ├── 17 with explicit min_coverage thresholds (0–100%)
│   └── 16 with no min_coverage (VGV default: 100%)
├── 1  mobile app CI          (mobile_ci.yaml)
├── 3  quality gates           (semantic_pr, mergeability_check, pr_issue_link)
└── 3  deploy workflows        (pr_preview_build, pr_preview_deploy, web_production_deploy)
```

---

### 1. Seven packages have no CI workflow

**Problem**: These packages lack a GitHub Actions workflow in `.github/workflows/`:

| Package | Test files | Notes |
|---------|-----------|-------|
| `app_update_repository` | 3 | Has tests, no CI |
| `app_version_client` | 2 | Has tests, no CI |
| `hashtag_repository` | 1 | Has tests, no CI |
| `invite_api_client` | 2 | Has tests, no CI |
| `nostr_app_bridge_repository` | 5 | Has tests, no CI |
| `notification_repository` | 1 | Has tests, no CI |
| `nostr_apps` | **0** | **No test directory at all** |

**Correction from prior draft**: The original list included `users_repository` and `whisper_wrapper`; neither exists as a package anymore. It also omitted `models`, which does have a workflow (`models_ci.yaml`).

**Evidence**: 33 other packages follow the per-package CI pattern. Changes to these 7 packages are not gated by any automated checks on PR.

**Impact**: Medium. Regressions in these packages won't be caught until the mobile CI runs (if it even covers them). Violates the project's per-package CI pattern.

**Effort**: Low. Each workflow is a copy of the existing VGV reusable workflow template. ~15 min per package. `nostr_apps` additionally needs tests written before a workflow is useful.

**GitHub ticket**: TBD

---

### 2. Mobile CI has no coverage enforcement

**Problem**: `mobile_ci.yaml` runs tests across 8 shards but does not collect or enforce a coverage threshold for the main app in `mobile/`.

**Evidence**: The workflow runs `flutter test --exclude-tags integration` but never passes `--coverage` and has no `min_coverage` check. Package workflows enforce coverage via VGV's reusable workflow, but the app itself has none.

**Done well**: Per-package CI workflows enforce coverage via VGV's reusable workflow (e.g., `blossom_upload_service` at 100%). The gap is specifically the main app.

**Impact**: High. The main app is the largest codebase in the repo and has no automated coverage gate. Coverage can silently regress on every merge.

**Effort**: Medium. Need to add `--coverage` to the test step, aggregate sharded lcov files, and add a threshold check (e.g. via `very_good_coverage`).

**GitHub ticket**: TBD

---

### Package CI coverage thresholds inconsistent and too low
**Problem**: Coverage thresholds across packages range from 20% to 100% with no coherent policy. Several are far below the VGV 100% target.

**Evidence**: Current thresholds: `blossom_upload_service` (100%), `time_formatter` (100%), `media_cache` (98%), `dm_repository` (93%), down to `funnelcake_api_client` (44%), `db_client` (40%), `models` (25%), `permissions_service` (22%), `nostr_sdk` (20%). The low thresholds were set to match actual coverage at the time of CI creation, but they have not been raised since. They function as accepted-debt markers rather than meaningful quality gates.

**Done well**: `blossom_upload_service` (100%), `time_formatter` (100%), and `media_cache` (98%) demonstrate that high thresholds are achievable and enforced.

**Impact**: Medium. Low thresholds allow coverage to regress within a large margin without CI catching it. A package at 22% coverage could lose half its tests and still pass CI. The inconsistency also makes it unclear what the project's actual standard is.

**Effort**: Low per package. Raise each threshold to match current actual coverage (so no existing PR breaks), then raise incrementally per quarter. Requires measuring actual coverage first for packages where the threshold was set long ago.

**GitHub ticket**: TBD
