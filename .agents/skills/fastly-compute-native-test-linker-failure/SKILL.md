---
name: fastly-compute-native-test-linker-failure
description: |
  Fix Fastly Compute Rust crate `cargo test` failures with "ld: symbol(s) not found" errors
  for Fastly SDK symbols like `_version_set`, `_body_new`, `_req_send` on native host builds.
  Use when: (1) `cargo test` on a Fastly Compute crate fails at link time with errors mentioning
  libfastly and symbols with names like `fastly::http::response::handle::...`, (2) You added a
  `#[cfg(test)]` module to a file in a Fastly Compute binary crate and the tests never seem to
  run or fail to link, (3) Existing `#[cfg(test)]` modules in src/main.rs or its sibling modules
  appear dead despite being present in the source tree, (4) `cargo test --lib` works but
  `cargo test` fails.
author: Claude Code
version: 1.0.0
date: 2026-04-05
---

# Fastly Compute native test linker failure

## Problem

Fastly Compute Rust binaries link against `libfastly`, which provides FFI symbols that only
exist when targeting `wasm32-wasip1`. On a native host (macOS, Linux x86_64, Linux arm64),
the FFI symbols are absent, so linking a test binary for the Fastly Compute crate fails with
errors like:

```
"_version_set", referenced from:
    fastly::http::response::handle::ResponseHandle::set_version::h234bdb33f8878476 in libfastly-XXXX.rlib
"_body_new", referenced from:
    fastly::http::body::Body::new::hYYYY in libfastly-XXXX.rlib
ld: symbol(s) not found for architecture arm64
clang: error: linker command failed with exit code 1
error: could not compile `fastly-blossom` (bin "fastly-blossom" test)
```

The error appears during `cargo test` even if none of your tests actually call Fastly SDK
code — cargo still tries to compile and link the entire binary as a test target.

This has a nasty consequence: **any `#[cfg(test)] mod tests { ... }` block inside a file
compiled into the binary crate is effectively dead code**. It never runs via `cargo test`
because cargo can't link the test binary. Developers add tests, the compiler accepts them,
they're visible in the source tree — but they never execute. Tests that were meant to
regression-guard behavior silently become documentation that rots.

## Context / Trigger Conditions

- Fastly Compute Rust project with `fastly = "0.11.x"` (or similar) as a dependency
- The crate has both `src/main.rs` and `src/lib.rs` OR only `src/main.rs`
- `cargo test` fails at link time with `_version_set` / `_body_new` / `_req_send` undefined
- `cargo check --target wasm32-wasip1` succeeds
- `cargo check` (native) succeeds (library code compiles, just can't link the binary)
- You added tests in `src/admin.rs`, `src/blossom.rs`, `src/metadata.rs`, or any file that's
  `mod`-included from `src/main.rs` but NOT from `src/lib.rs`

## Root cause

Fastly's Rust SDK (`fastly` crate) is designed exclusively for wasm32-wasip1. Its public
API calls unsafe FFI functions (`_version_set`, `_req_send`, `_body_new`, etc.) that the
Fastly Compute runtime provides at execution time inside the POP. On a native host, the
rustc compiler still compiles the library crate, but the linker can't resolve those FFI
symbols because libfastly-native doesn't exist.

`cargo test` for a mixed lib+bin crate links **two** artifacts: the library test binary AND
the binary test binary (the `main` executable with tests enabled). The library test binary
can avoid the SDK symbols if lib.rs doesn't import them transitively. The binary test binary
can't, because main.rs wires the whole Fastly Compute runtime.

## Solution

### Structure your crate as lib + bin, and put all testable logic in lib

1. Create `src/lib.rs` if it doesn't exist:

```rust
// src/lib.rs — library target, testable natively
pub mod admin_sweep;   // pure logic, no Fastly SDK
pub mod classifiers;   // pure logic, no Fastly SDK
pub mod parsers;       // pure logic, no Fastly SDK
```

2. Put any module you want to unit-test **in a separate file that does NOT import Fastly
   SDK types**, and expose it via `pub mod` in `lib.rs`:

```rust
// src/admin_sweep.rs — pure logic, testable natively
pub enum StuckAction { SkipNotStuck, SkipTooRecent, MarkComplete, ResetPending }

pub fn classify_stuck_record(
    is_processing: bool,
    uploaded_iso: &str,
    threshold_iso: &str,
    hls_present: bool,
) -> StuckAction { /* ... */ }

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn skip_not_stuck_when_status_is_not_processing() { /* ... */ }
}
```

3. In `src/main.rs`, also declare the module so the binary can use it:

```rust
mod admin_sweep;  // same file, compiled twice — once for lib, once for bin
```

4. The handler in an admin.rs (or wherever) that DOES use Fastly SDK types extracts
   primitives from SDK types and calls the pure classifier:

```rust
// src/admin.rs (part of the bin, uses Fastly SDK types like Request/Response)
pub fn handle_sweep(req: Request) -> Result<Response> {
    let is_processing = meta.transcode_status == Some(TranscodeStatus::Processing);
    let action = crate::admin_sweep::classify_stuck_record(
        is_processing, &meta.uploaded, &threshold_iso, hls_present,
    );
    // ... match on action, make SDK-level calls ...
}
```

5. Run tests with:

```bash
cargo test --lib
```

**Not** `cargo test` (which tries to link the bin). `--lib` only builds and runs the
library test binary, which can link because none of its code touches Fastly SDK symbols.

### Do NOT depend on crate internals from the lib module

Your lib-exposed module must NOT transitively import anything that touches the Fastly SDK.
Common traps:

- `use crate::blossom::BlobMetadata;` — if `blossom.rs` is in the binary crate and uses
  `fastly::Request`, importing `BlobMetadata` drags SDK symbols into the lib build.
  Solution: pass raw primitives (Option<TranscodeStatus>, &str, etc.) across the boundary,
  not full SDK-aware structs.
- `use crate::storage::current_timestamp;` — if storage.rs calls `fastly::kv_store::*`,
  same problem. Duplicate the helper in admin_sweep.rs or extract it to a third
  SDK-free module in lib.rs.

Treat lib.rs as a clean-room: only pure Rust, no SDK types, no platform-specific I/O.

### Verify

```bash
cargo check --target wasm32-wasip1  # must still succeed (bin compiles for deploy)
cargo test --lib                     # must run and pass (tests exercise pure logic)
```

You can also add to CI:

```yaml
- run: cargo test --lib
- run: cargo check --target wasm32-wasip1
```

`cargo test` (no flags) will still fail on this project; that's expected and unavoidable.
Document it in README or CONTRIBUTING so contributors don't waste time on it.

## Verification

After applying this pattern:

- `cargo test --lib` runs your new tests and they execute (pass or fail, but they RUN)
- `cargo check --target wasm32-wasip1` still produces a deployable WASM
- Existing `#[cfg(test)] mod tests` blocks in binary-only files (admin.rs, etc.) are still
  dead; consider migrating them into lib-exposed modules or deleting them if the behavior
  they test can be moved

## Example

In the Divine Blossom repo, the Fastly Compute crate (`src/main.rs`) had `#[cfg(test)]`
modules in `src/delete_policy.rs`, `src/error.rs`, `src/auth.rs`, `src/blossom.rs`, and
`src/metadata.rs`. None of these ran via `cargo test` — `lib.rs` only exposed
`resumable_complete`. Attempting to add tests to `src/admin.rs` failed at link time.

The fix was to create `src/admin_sweep.rs` with zero dependencies on the rest of the crate
(no `use crate::blossom`, no `use crate::storage`), add `pub mod admin_sweep;` to `lib.rs`,
and have the tests live there. The handler in `src/admin.rs` (binary-only) extracts four
primitives from `BlobMetadata` before calling the pure classifier.

Result: `cargo test --lib` now runs 11 tests (7 new + 4 pre-existing from
`resumable_complete`). The wasm32-wasip1 build still produces a valid Fastly Compute
binary. The binary-only `#[cfg(test)]` modules are still dead, but the logic that matters
is now covered.

## Notes

- This is a structural constraint imposed by the Fastly SDK's FFI design, not something
  Fastly will "fix" — the SDK crate has to provide those symbols somehow, and the runtime
  is wasm.
- Fastly's own examples tend to avoid tests entirely, which is why this trap is widespread.
- The same pattern applies to any Rust crate that targets a specific platform via FFI
  symbols provided by a host runtime: Cloudflare Workers (`worker-rs`), Vercel Edge
  (`@vercel/edge`), some embedded HAL crates, etc. The "put pure logic in lib, keep SDK
  calls in bin" pattern generalizes.
- If you're starting fresh, consider making your Fastly Compute crate a library-only crate
  with a tiny `src/main.rs` that just calls `lib::run()`. Then everything is in the lib by
  default and there's no bin/lib split to worry about. This is the cleanest structure.
- `rust-analyzer` and IDE tooling will still happily analyze and type-check the
  `#[cfg(test)]` modules in binary-only files, so they *look* live. Only `cargo test`
  reveals the truth.

## References

- [Fastly Compute Rust SDK crate](https://docs.rs/fastly/) — note the target restriction in
  the documentation
- Related skill: `fastly-compute-rust-edition2024-fix` — different failure mode (build-time
  dependency incompatibility) but shares the "Fastly Compute crate has unusual constraints
  around native tooling" theme
