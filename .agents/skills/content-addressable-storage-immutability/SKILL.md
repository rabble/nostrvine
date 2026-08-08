---
name: content-addressable-storage-immutability
description: |
  CRITICAL: Never modify files in content-addressable storage systems where the filename
  IS the content hash (SHA256, IPFS CID, etc.). Use when: (1) Working with Blossom protocol,
  IPFS, or any CAS system, (2) Considering "optimizing" stored files (faststart, compression),
  (3) Implementing transcoding or processing pipelines for hash-identified content,
  (4) Building on top of ProofMode or any cryptographic verification system. Modifying
  files in place breaks hash verification and content integrity.
author: Claude Code
version: 1.0.0
date: 2026-01-31
---

# Content-Addressable Storage Immutability

## Problem
In content-addressable storage (CAS) systems, files are identified by their content hash.
If you modify a file in place (even "harmless" optimizations), the content no longer
matches its identifier, breaking the entire system's integrity guarantees.

## Context / Trigger Conditions
- Working with Blossom protocol (files at `/{sha256}`)
- Working with IPFS (files at `/ipfs/{CID}`)
- Any system where filename = hash of content
- Considering file optimizations like:
  - MP4 faststart (moving moov atom)
  - Image optimization/compression
  - Metadata stripping
  - Format conversion
- Systems using ProofMode or cryptographic verification

## The Fundamental Rule

**NEVER modify a file stored at its content hash.**

The hash IS the identity. Change the content → change the hash → file is now at wrong address.

## What Goes Wrong

```
Original file: abc123... (hash) → contains bytes X
After "optimization": abc123... (hash) → contains bytes Y

Result:
- Hash abc123 no longer verifies
- ProofMode signatures invalid
- Content-addressable lookups return wrong data
- Cryptographic proofs broken
- Data integrity compromised
```

## Solution: Store Derivatives Separately

If you need optimized/processed versions, store them at separate paths:

```
/{hash}                    ← Original file (NEVER MODIFY)
/{hash}/hls/master.m3u8    ← HLS transcoded version
/{hash}/faststart.mp4      ← Faststart optimized version
/{hash}/thumb.jpg          ← Thumbnail
/{hash}/720p.mp4           ← Resolution variant
```

The original stays byte-for-byte identical. Derivatives live in subdirectories.

## Implementation Pattern

```rust
// WRONG - modifies original
async fn process_video(hash: &str) {
    let path = format!("/{}", hash);
    let video = download(&path);
    let optimized = apply_faststart(video);
    upload(&path, optimized);  // ❌ BREAKS HASH!
}

// RIGHT - creates derivative
async fn process_video(hash: &str) {
    let original_path = format!("/{}", hash);
    let derivative_path = format!("/{}/faststart.mp4", hash);

    let video = download(&original_path);
    let optimized = apply_faststart(video);
    upload(&derivative_path, optimized);  // ✓ Original untouched
}
```

## Verification
- Original file hash still verifies: `sha256sum file == filename`
- ProofMode signatures still valid
- Content lookups return expected data

## Common Mistakes

1. **"It's just moving metadata"** - Still changes bytes, still breaks hash
2. **"We'll update the hash reference"** - Now you have dangling references everywhere
3. **"No one will notice"** - Verification systems WILL notice
4. **"It's an optimization"** - Optimize derivatives, not originals

## Notes
- This applies to ANY content-addressable system, not just Blossom
- IPFS, Git objects, Docker layers all follow this principle
- If you need the optimized version as primary, the client should upload it that way
- Transcoding to new formats (HLS, DASH) is fine because they're clearly separate files

## References
- [Content-addressable storage (Wikipedia)](https://en.wikipedia.org/wiki/Content-addressable_storage)
- [Blossom Protocol (BUD-01)](https://github.com/hzrd149/blossom)
- [IPFS Content Addressing](https://docs.ipfs.tech/concepts/content-addressing/)
