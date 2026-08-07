---
name: fastly-compute-rust-edition2024-fix
description: |
  Fix Fastly Compute Rust build failures caused by edition2024 dependencies. Use when:
  (1) cargo build fails with "feature `edition2024` is required", (2) wit-bindgen or
  wasip2 crates fail to download/parse, (3) Fastly SDK pulls in incompatible transitive
  dependencies, (4) Build worked before but fails after dependency update. Solves by
  pinning wit-bindgen, wasip2, and related crates to pre-edition2024 versions.
author: Claude Code
version: 1.0.0
date: 2026-01-20
---

# Fastly Compute Rust Edition2024 Dependency Fix

## Problem

Fastly Compute Rust projects fail to build with errors about `edition2024` being required,
even when using stable Rust. The error appears when transitive dependencies (especially
`wit-bindgen` 0.51+ and `wasip2` 1.0.2+) require Rust 1.87+ which isn't stable yet.

## Context / Trigger Conditions

- Error: `feature 'edition2024' is required`
- Error: `failed to parse manifest at .../wit-bindgen-0.51.0/Cargo.toml`
- Error mentions "requires Rust 1.87.0" for wit-bindgen or wasip2
- Build previously worked but fails after running `cargo update`
- Using Fastly SDK (`fastly` crate) version 0.11.x

## Solution

Pin the problematic transitive dependencies in your `Cargo.toml`:

```toml
[dependencies]
# Fastly Compute SDK - pin to specific version
fastly = "=0.11.12"

# Pin these to avoid edition2024 requirement
wit-bindgen = "=0.46.0"
wasip2 = "=1.0.1"

# Also pin these if you use k256 or crypto
k256 = { version = "=0.13.3", features = ["schnorr"] }
base64ct = "=1.6.0"
```

Also update `rust-toolchain.toml` to include both WASM targets:

```toml
[toolchain]
channel = "1.83.0"
targets = ["wasm32-wasi", "wasm32-wasip1"]
```

Then:
```bash
rm Cargo.lock
rustup target add wasm32-wasip1
cargo build --target wasm32-wasi
```

## Verification

Build should complete without edition2024 errors:
```bash
cargo build --target wasm32-wasi 2>&1 | grep -i "edition2024"
# Should return nothing (no matches)
```

## Example

Before fix (Cargo.toml):
```toml
[dependencies]
fastly = "0.11"  # Allows 0.11.x which pulls wit-bindgen 0.51+
```

After fix (Cargo.toml):
```toml
[dependencies]
fastly = "=0.11.12"
wit-bindgen = "=0.46.0"
wasip2 = "=1.0.1"
```

## Notes

- The `=` prefix in version strings means "exactly this version"
- Fastly CLI 13.x switched from `wasm32-wasi` to `wasm32-wasip1` target
- This is a temporary fix until Rust 1.87 becomes stable
- The warning about `wasm32-wasi` being renamed to `wasm32-wasip1` is expected
- When Rust 1.87 is stable, these pins can be removed

## References

- Fastly Compute Rust SDK: https://docs.fastly.com/products/compute
- Rust Edition 2024: https://doc.rust-lang.org/edition-guide/rust-2024/
