---
name: fastly-compute-publish-ignores-draft-versions
description: |
  Fix "backend exists on a draft version but isn't reachable from the new Compute deploy"
  bugs after `fastly compute publish`. Use when: (1) You ran `fastly service backend create
  --autoclone` (or any dashboard/CLI change that creates a draft version) but did not
  activate that draft, (2) You then ran `fastly compute publish` which appeared successful
  but your backend / ACL / header / dictionary change is missing from the active version,
  (3) Compute code returns backend-not-found errors or misroutes requests, (4) You're
  surprised to see your draft version number "skipped over" in the version chain.
  Root cause: `fastly compute publish` clones from the currently-active version, not from
  the latest draft, so dashboard changes made in an un-activated draft get stranded.
author: Claude Code
version: 1.0.0
date: 2026-04-05
---

# `fastly compute publish` ignores non-active draft versions

## Problem

Fastly service versions are immutable. To change a service you clone the active version,
edit the clone (a draft), then activate the clone. Multiple tools create drafts:

- `fastly service backend create --autoclone` — creates a draft off the active version and
  adds the backend
- `fastly service domain create --autoclone` — same, for domains
- Dashboard UI "Clone" button
- `fastly compute publish` — also creates a draft, uploads WASM, activates

If you mix these tools on the same service you get a surprising footgun: **each tool clones
from the currently-active version, independently, and each activates its own clone.** Draft
versions that were never activated are abandoned. Their edits are invisible to whatever the
next tool clones from.

Example sequence that bites:

```
t0  Active = v250
t1  $ fastly service backend create --version latest --autoclone \
       --name cloud_run_transcoder --address ...
    → creates v251 (clone of v250) + adds backend
    → v251 is DRAFT, not active
    → "latest" in this context means "highest version number" (v251), not "active version"

t2  $ fastly compute publish --comment "ship fix"
    → creates v252 (clone of v250, NOT v251) + new WASM
    → stages and activates v253 (clone of v252) + activates
    → v251's backend change was never carried forward
    → active = v253, which does NOT contain cloud_run_transcoder

t3  Compute code at v253 calls send_async("cloud_run_transcoder")
    → backend name does not exist on v253
    → silent failure, fire-and-forget hides it
```

The naming is misleading: `--version latest` does not mean "the latest active version," it
means "the highest-numbered version," which can be a draft nobody activated. And `fastly
compute publish` never looks at your draft — it clones from whatever is currently active.
So your backend change is orphaned in an unreachable draft version, and the active version
has the new code but the old backend list.

## Context / Trigger Conditions

- Compute logs show `Backend X does not exist` or similar after a deploy that "worked"
- `send_async(BACKEND)` calls return errors that the code silently swallows (see skill
  `fastly-compute-async-request-reliability`)
- `fastly service version list --service-id ID` shows a gap or out-of-order creation
  timestamps — e.g. v251 created at 23:17, v252/v253 created at 23:27, v253 active, but
  v252 was cloned from v250 not v251
- `fastly service backend list --version N` where N is active shows a DIFFERENT backend
  set from `fastly service backend list --version (N-2)` where N-2 is the draft you
  thought you were building on
- You added a dashboard resource "just before" running `fastly compute publish` and the
  publish succeeded but the resource seems to be ignored

## Solution

### Detection

```bash
# Find all versions and which is active
fastly service version list --service-id YOUR_SERVICE_ID

# For each recent version, list backends (or whatever resource you added)
for v in 250 251 252 253 254; do
  echo "=== v$v ==="
  fastly service backend list --service-id YOUR_SERVICE_ID --version $v | grep MY_BACKEND_NAME
done
```

If the backend appears on a non-active draft (e.g. v251) but is absent from active (e.g.
v253), you have this bug.

### Fix: add the resource to the currently-active version via `--autoclone`

```bash
# Creates a new draft cloned from the active version, with the backend added.
# Activate the draft atomically afterward.
fastly service backend create --service-id YOUR_SERVICE_ID --version latest --autoclone \
  --name cloud_run_transcoder \
  --address divine-transcoder-149672065768.us-central1.run.app \
  --port 443 --use-ssl \
  --ssl-sni-hostname divine-transcoder-149672065768.us-central1.run.app \
  --override-host divine-transcoder-149672065768.us-central1.run.app

# Confirm the draft has the backend
fastly service backend list --service-id YOUR_SERVICE_ID --version LATEST_DRAFT \
  | grep cloud_run_transcoder

# Activate
fastly service version activate --service-id YOUR_SERVICE_ID --version LATEST_DRAFT

# Purge cache so any poisoned 404/502 responses drop
fastly purge --all --service-id YOUR_SERVICE_ID
```

Note: `--version latest` in the `backend create` command here is safe because after the
previous drifted `fastly compute publish`, the latest draft's parent IS the currently-active
version. You're cloning off the right base now.

### Prevention (choose one)

1. **Do all non-code changes through `fastly compute publish` first, then WASM changes.**
   If you ran `fastly compute publish` without any dashboard/CLI changes queued, the active
   version gets incremented by 2 (clone → activate) and there are no stranded drafts. Add
   your backend after the publish via `--autoclone`, which then creates a fresh draft off
   the new active version, and activate it.

2. **Always activate your draft before running `fastly compute publish`.** If you ran
   `fastly service backend create --autoclone` and got v251, activate v251 before the
   compute publish. Then compute publish will clone from v251 and carry the backend.

3. **Treat every draft version as an unshipped change.** Before any `fastly compute publish`,
   run `fastly service version list --service-id ID` and verify no drafts exist that you
   intended to ship. If there are drafts you don't want, explicitly abandon them; if there
   are drafts you do want, activate them first.

4. **Use `--verbose` on `fastly compute publish`.** The verbose output shows which version
   number it cloned from. If that number is older than your last draft, you know you've
   drifted.

## Verification

After the fix, confirm:

```bash
# Active version has the backend
fastly service backend list --service-id YOUR_SERVICE_ID --version $(fastly service version list --service-id YOUR_SERVICE_ID | awk '$3=="true"{print $1}') | grep MY_BACKEND_NAME

# End-to-end: hit a Compute endpoint that exercises the backend and check logs
# for successful routing (no "backend does not exist" errors)
fastly log tail --service-id YOUR_SERVICE_ID | grep -iE "backend|MY_BACKEND"
```

For the Divine Blossom example (2026-04-05), the symptom was that PR #59's fix to route
transcoder triggers via a new `TRANSCODER_BACKEND = "cloud_run_transcoder"` constant was
deployed in version 253 but the backend itself was stranded in v251. The compute code was
silently 404-ing on every `send_async` to the transcoder. Fix was `fastly service backend
create --version latest --autoclone` → new v254 with both the WASM and the backend →
activate v254 → purge.

## Notes

- The same issue applies to *any* resource you can add with `--autoclone`: backends,
  domains, ACLs, dictionaries, edge dictionaries, header rules, VCL snippets (on VCL
  services), logging endpoints. Anything that creates a draft version is at risk.
- The `fastly compute publish` command has no `--base-version` flag to explicitly say "clone
  from this version." It always clones from active.
- VCL services that mix `fastly vcl snippet create --autoclone` + `fastly vcl custom update`
  can hit the same trap.
- If you have multiple people making changes concurrently, the risk multiplies: one person's
  draft can be invalidated by another person's publish without either of them noticing.
- The Fastly CLI does not warn about stranded drafts. They don't expire automatically
  (AFAIK); they just become zombie versions.
- Check `fastly service version list --service-id ID` output carefully — the "active"
  column tells you which version is live; everything else is a draft or a previous active.
  Timestamps can be misleading because draft versions carry the timestamp of the `fastly
  service version clone` call, not of the content change.

## References

- `fastly compute publish` source behavior documented in the Fastly CLI repo — see the
  `publish` subcommand implementation for the clone-active-and-activate flow
- Related skill: `fastly-compute-async-request-reliability` — covers how silently-failing
  `send_async` hides this exact bug when the backend goes missing
- Related skill: `fastly-compute-backend-production-setup` — covers the "backend exists
  locally but not in production" sibling bug
