# Protected-minor DM restriction (mobile) — design

**Issue:** divinevideo/support-trust-safety#176 (part of the protected-minor epic #173; consumes the #174 seam, merged as #5708; shares #175's sticky fail-safe posture)
**Date:** 2026-07-02
**Status:** WIP — design in progress (brainstorming). Not for review yet.

## Goal

Restrict a protected minor's direct messages to **Divine HQ/Support only**:
- **Send:** block sending a DM to any npub outside the approved-recipient set.
- **Inbound:** suppress display of DMs from senders outside the approved-recipient set.

Client-side by necessity: NIP-17 DMs are kind-1059 gift-wraps authored by a one-time key, so the relay cannot attribute a DM to a real sender and cannot filter by sender.

## Open design questions (being worked)

- **Source of the approved-recipient set** (the HQ/Support npub(s)): hardcoded config, Keycast, or relay-manager. Trust model tracked in divine-mobile#4948.
- **Integration points** for the send-block and the inbound filter in the messaging stack.
- **Fail-safe:** persist last-known protected status, sticky, lift only on a positive not-a-minor signal (same as #175); matters more here since DMs default to open.

## Scope

Mobile only. Web parity is divine-web#454 (separate, blocked on divine-web#456). Parent-approved allowlist is a later follow-on (#178 / divine-web#455).

_This document is a stub; it is filled in as the design is brainstormed and approved._
