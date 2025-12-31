# Settings Redesign & Moderation Architecture

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (or subagent-driven-development) to implement the Sidebar Cleanup (Task 1).

**Goal:** Reorganize Settings to expose developer tools and safeguard destructive actions. Document architecture for decentralised moderation (Labelers).

**Architecture:**
*   **Settings Screen:** Central hub. Re-ordering to group "Network/Dev" together and push "Danger Zone" to bottom.
*   **Moderation (Future):** Protocol-based filtering using NIP-32/1985. Client listens to trusted pubkeys (Divine, Follows, Custom) for labels.

**Tech Stack:** Flutter, Riverpod, Nostr.

---

### Task 1: Settings Sidebar Cleanup

**Files:**
-   Modify: `mobile/lib/screens/settings_screen.dart`

**Step 1: Expose Developer Options & Move Danger Items**
Modify `build` method.
*   **Developer Options:**
    *   Remove `if (isDeveloperMode)` check.
    *   Move `_buildSettingsTile` for Developer Options into the **Network** section (after Blossom settings).
    *   Change icon color to standard (white/theme) instead of orange, or keep orange to signify "advanced".
*   **Danger Zone:**
    *   Remove "Remove Keys" and "Delete Account" from the "Account" section.
    *   Add `_buildSectionHeader('Danger Zone')` at the specific end of the list (after Support).
    *   Add the removed tiles there.

**Step 2: Clean up "Account" Section**
*   Ensure "Account" section contains ONLY "Log Out".

**Step 3: Verify Router & Compile**
Run: `flutter analyze mobile/lib/screens/settings_screen.dart`

**Step 4: Commit**
```bash
git add mobile/lib/screens/settings_screen.dart
git commit -m "ux: reorganize settings to expose dev options and isolate destructive actions"
```

---

### Design: Trust & Safety (Labeler Integration)

*This section documents the agreed design for future implementation.*

**Concept:** Stackable Labeler Subscriptions (similar to Bluesky).

**Components:**
1.  **Divine Service (Default):**
    *   The app subscribes to the Divine Labeler Pubkey by default.
    *   Consumes Kind 1985 (Labels) events.
    *   Action: Hide/Blur content based on label (e.g., `nsfw`, `scam`).

2.  **Social Graph (Web of Trust):**
    *   "Trust People I Follow".
    *   Logic: If >N people I follow report/label an event, hide it.
    *   Implementation: Fetch Kind 1984/1985 from followed pubkeys.

3.  **Custom Labelers:**
    *   User adds a pubkey (e.g., "NostrSpamBot").
    *   ContentModerationService subscribes to that pubkey's Label events.

**Data Flow:**
`Feed` -> `VideoEvent` -> `ModerationService.evaluate(event)` -> `Result(clean, warning, hide)` -> `UI`

**Status:**
*   Backend Labeler (Divine) exists.
*   Client `ContentModerationService` needs enhancement to consume arbitrary labelers (Task for next sprint).
