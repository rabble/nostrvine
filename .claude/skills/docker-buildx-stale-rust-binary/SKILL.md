---
name: docker-buildx-stale-rust-binary
description: |
  Fix deployed Rust binaries not reflecting code changes when using docker buildx.
  Use when: (1) Code changes are verified locally (tests pass) but production behavior
  doesn't change after deploy, (2) Docker image has a new tag but contains old compiled
  binary, (3) Dockerfile uses multi-stage build with dependency pre-compilation layer
  and source copy layer. Docker buildx layer caching can serve stale compilation output
  even when source files change, especially with cross-compilation (--platform linux/amd64).
author: Claude Code
version: 1.0.0
date: 2026-03-31
---

# Docker Buildx Stale Rust Binary Cache

## Problem
Docker buildx may serve stale compiled Rust binaries from layer cache even when source
files have changed. The image gets a new tag and pushes successfully, but contains the
old compiled binary. This is especially common with cross-platform builds
(`--platform linux/amd64` on ARM Macs).

## Context / Trigger Conditions
- Dockerfile uses multi-stage pattern: copy Cargo.toml → build deps → copy source → build
- Using `docker buildx build --push` with `--platform linux/amd64`
- Code changes verified locally (tests pass) but production shows old behavior
- Image digest from cached build differs from `--no-cache` build
- Adding a simple response header in code and it doesn't appear in production

## Solution
Always use `--no-cache` when deploying code changes:

```bash
# WRONG — may use cached compilation layer with old code
docker buildx build --platform linux/amd64 --target api \
  -t registry/image:tag --push .

# CORRECT — forces full recompilation
docker buildx build --platform linux/amd64 --target api \
  --no-cache -t registry/image:tag --push .
```

## Verification
Compare image digests between cached and no-cache builds:

```bash
# Build with cache
docker buildx build --platform linux/amd64 --target api \
  -t registry/image:cached --push . 2>&1 | grep "pushing manifest"
# Note the sha256 digest

# Build without cache  
docker buildx build --platform linux/amd64 --target api \
  --no-cache -t registry/image:nocache --push . 2>&1 | grep "pushing manifest"
# Note the sha256 digest

# If digests differ, the cached build had stale code
```

## Example
Typical Dockerfile pattern vulnerable to this:

```dockerfile
# Layer 1: Copy manifests (cached if Cargo.toml unchanged)
COPY Cargo.toml Cargo.lock ./
COPY crates/*/Cargo.toml crates/

# Layer 2: Build dependencies (cached — this is the good cache)
RUN cargo build --release && rm -rf src crates

# Layer 3: Copy actual source (SHOULD invalidate on source change)
COPY crates crates
COPY bin bin

# Layer 4: Rebuild with actual source
RUN touch crates/*/src/lib.rs && cargo build --release
```

The issue: buildx's content-addressable cache may match Layer 4's output from a previous
build if the intermediate representations happen to collide, especially during cross-compilation
where the build environment state is more complex.

## Notes
- This primarily affects `--platform` cross-compilation builds (ARM → x86)
- Native-platform builds are less likely to hit this issue
- The `--no-cache` flag adds ~5-10 minutes to Rust builds but guarantees fresh compilation
- Alternative: use `--cache-from` with explicit cache scoping to avoid stale layers
- Consider adding a build-time env var (like commit hash) that forces layer invalidation:
  ```dockerfile
  ARG BUILD_HASH
  RUN echo $BUILD_HASH && cargo build --release
  ```
