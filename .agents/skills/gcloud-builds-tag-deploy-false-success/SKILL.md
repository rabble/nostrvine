---
name: gcloud-builds-tag-deploy-false-success
description: |
  Fix false-positive Cloud Run deploys where `gcloud builds submit --tag` silently fails
  but the follow-up `gcloud run services update --image :latest` succeeds against a stale
  image, producing a confident "Deploying... Done" message with pre-fix code still live.
  Use when: (1) gcloud builds submit prints
  "ERROR: (gcloud.builds.submit) Invalid value for [source]: Dockerfile required when specifying --tag"
  but the shell scrolls past it, (2) code changes verified locally aren't visible in production
  after a deploy that printed "revision ... has been deployed and is serving 100 percent of traffic",
  (3) Chaining `gcloud builds submit` and `gcloud run services update` in a single copy-paste
  block, (4) Using the mutable `:latest` tag for Cloud Run deploys.
author: Claude Code
version: 1.0.0
date: 2026-04-05
---

# gcloud builds submit --tag false-success trap

## Problem

A common Cloud Run deploy recipe looks like this:

```bash
gcloud builds submit --tag us-central1-docker.pkg.dev/PROJECT/REPO/IMAGE:latest
gcloud run services update SERVICE \
  --image us-central1-docker.pkg.dev/PROJECT/REPO/IMAGE:latest \
  --region us-central1 --project PROJECT
```

When the first command fails (most commonly because the current working directory doesn't
contain a `Dockerfile`), its single-line error scrolls off-screen above the second command's
verbose progress spinner. The second command then pulls the **existing** `:latest` image
from Artifact Registry — which is the previous build — and deploys it. You get:

```
✓ Deploying... Done.
  ✓ Creating Revision...
  ✓ Routing traffic...
Service [...] revision [...] has been deployed and is serving 100 percent of traffic.
```

A green "SUCCESS" deploy that did not change the running code. The user then spends
hours debugging why the fix isn't live, or worse, concludes the fix doesn't work and
reverts good code.

## Context / Trigger Conditions

- User reports "I deployed the fix but production behavior is unchanged"
- Recent shell output contains both:
  - `ERROR: (gcloud.builds.submit) Invalid value for [source]: Dockerfile required when specifying --tag`
  - `revision [...] has been deployed and is serving 100 percent of traffic`
- The `gcloud builds submit --tag …` was run without a source positional argument AND
  the working directory does not contain the Dockerfile (common in monorepos where the
  Dockerfile lives under a subdirectory like `cloud-run-upload/`, `services/api/`, etc.)
- The deploy targets use the mutable `:latest` tag (or another tag that already exists
  in the registry)

## Root cause

`gcloud builds submit --tag IMAGE_TAG` needs a source directory. When you omit it, it
defaults to the current working directory, and if there's no `Dockerfile` there (or a
`cloudbuild.yaml`), it exits immediately with exit code 1 — without uploading anything,
without creating a build job, without touching Artifact Registry.

Because `gcloud run services update --image :latest` resolves `:latest` at deploy time
from Artifact Registry, it happily redeploys whatever was there from the *previous*
successful build. Cloud Run's response does not compare the resolved digest to what's
already running; it cheerfully creates a new revision pinning the same digest. Output
reads "Done" because, from Cloud Run's perspective, everything worked.

Two mistakes compound here:
1. The build failure is a single red line among otherwise-green output and it's easy to miss.
2. The `:latest` tag hides the fact that "the image didn't actually change" — an immutable
   tag (git SHA, timestamp) would have made the staleness obvious.

## Solution

### Immediate fix

Rerun the build from the directory containing the Dockerfile, or pass the source as a
positional argument:

```bash
# Option A: cd into the directory
cd cloud-run-upload
gcloud builds submit --tag us-central1-docker.pkg.dev/PROJECT/REPO/IMAGE:latest

# Option B: pass source as positional
gcloud builds submit cloud-run-upload \
  --tag us-central1-docker.pkg.dev/PROJECT/REPO/IMAGE:latest
```

**Wait for `STATUS: SUCCESS`** in the output (not just for the prompt to return).
Then rerun the `gcloud run services update` command to pull the new digest.

### Permanent prevention (recommended)

1. **Use immutable tags.** Never deploy `:latest` to Cloud Run for anything that matters.
   Tag with git SHA or timestamp so staleness is visible:
   ```bash
   TAG=$(git rev-parse --short HEAD)
   gcloud builds submit cloud-run-upload \
     --tag us-central1-docker.pkg.dev/PROJECT/REPO/IMAGE:${TAG}
   gcloud run services update SERVICE \
     --image us-central1-docker.pkg.dev/PROJECT/REPO/IMAGE:${TAG} ...
   ```
   If step 1 silently fails, step 2 fails loudly with "image not found" because that
   tag doesn't exist yet. False-positive converted into a real error.

2. **Chain with `&&` or put the commands in a script with `set -e`.** Copy-pasting two
   separate commands lets the second run even if the first errored:
   ```bash
   #!/bin/bash
   set -euo pipefail
   cd "$(dirname "$0")/cloud-run-upload"
   TAG=$(git rev-parse --short HEAD)
   IMAGE=us-central1-docker.pkg.dev/PROJECT/REPO/IMAGE:${TAG}
   gcloud builds submit --tag "${IMAGE}"
   gcloud run services update SERVICE --image "${IMAGE}" --region us-central1
   ```

3. **Verify the build output contains `STATUS: SUCCESS`** before running the deploy. The
   last line of a successful `gcloud builds submit` is `STATUS: SUCCESS`. If the last
   line is anything else (especially `ERROR:`), the build did not happen.

## Verification

After re-running, confirm the deploy actually landed by checking the deployed revision's
image digest matches the newly-built one:

```bash
# Digest of the tag you just built
gcloud artifacts docker images describe \
  us-central1-docker.pkg.dev/PROJECT/REPO/IMAGE:latest \
  --format='value(image_summary.digest)'

# Digest of the image Cloud Run is currently serving
gcloud run services describe SERVICE --region us-central1 \
  --format='value(spec.template.spec.containers[0].image)'
```

The second command shows the resolved digest (if `:latest` was pinned) or the tag. For
an end-to-end behavioral check, hit a version endpoint if the service exposes one, or
tail logs and confirm new log lines that only the fixed code would emit:

```bash
gcloud logging read 'resource.type=cloud_run_revision AND resource.labels.service_name=SERVICE AND textPayload=~"NEW_LOG_LINE_FROM_FIX"' \
  --limit=5 --freshness=5m --format='value(timestamp,textPayload)'
```

## Example

A user runs the following as two separate pasted commands:

```
$ gcloud builds submit --tag us-central1-docker.pkg.dev/PROJECT/REPO/blossom-upload:latest
ERROR: (gcloud.builds.submit) Invalid value for [source]: Dockerfile required when specifying --tag

$ gcloud run services update divine-blossom-upload \
    --image us-central1-docker.pkg.dev/PROJECT/REPO/blossom-upload:latest \
    --region us-central1 --project PROJECT
✓ Deploying... Done.
  ✓ Creating Revision...
  ✓ Routing traffic...
Done.
Service [divine-blossom-upload] revision [divine-blossom-upload-00008-kvg] has been deployed and is serving 100 percent of traffic.
```

Revision `00008-kvg` is live but runs the pre-fix image. The user tests the fix against
production, it still misbehaves, and they escalate: "I deployed and it still doesn't work."

The fix is to rerun `gcloud builds submit` from the directory containing the Dockerfile
(or pass it as a positional), wait for `STATUS: SUCCESS`, then rerun the `gcloud run
services update`. The next revision will carry the new digest.

## Notes

- This is not specific to Cloud Run. The same shape of bug applies to any deploy pipeline
  that separates "build image" from "point service at :latest": Kubernetes with
  `imagePullPolicy: Always`, ECS with a `latest` task definition, Fly.io `fly deploy`
  after a failed `flyctl image push`, etc. Whenever the deploy step resolves a mutable
  tag it inherits the previous image on a build-step failure.
- `gcloud builds submit` also accepts `--gcs-source-staging-dir` and `cloudbuild.yaml`
  workflows — the error message changes with those but the principle is identical:
  verify build success, don't chain commands unconditionally.
- If you see `PERMISSION_DENIED` from `gcloud builds submit`, that's a different
  failure and also leaves the registry untouched — same false-positive pattern applies.
- In shells with `rtk`/tee middleware, a multi-command block can be rerun by index;
  rerunning just the `update` command without the `build` is the exact recipe for
  recreating this bug.

## References

- [gcloud builds submit reference](https://cloud.google.com/sdk/gcloud/reference/builds/submit) — note that `--tag` requires a source positional that contains a Dockerfile
- [Cloud Run deploy from source](https://cloud.google.com/run/docs/deploying-source-code) — the `gcloud run deploy --source .` one-shot avoids this split-command footgun entirely and is worth considering as an alternative workflow
- Related skill: `docker-buildx-stale-rust-binary` — different failure mode (layer cache staleness within a *successful* build) but shares the "deploy looks fine, code is old" symptom
