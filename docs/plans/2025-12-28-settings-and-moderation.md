# Settings Redesign & Moderation Architecture

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (or subagent-driven-development) to implement **Phase 1** (Settings Sidebar) task-by-task.

**Goal:** Clean up Settings UX and implement decentralized, stackable moderation (Labelers/NIP-1985).

**Architecture:**
*   **Settings Screen:** Central hub. Re-ordering to group "Network/Dev" together and push "Danger Zone" to bottom.
*   **Moderation:** Protocol-based filtering using NIP-32/1985. Client listens to trusted pubkeys (Divine, Follows, Custom) for labels.

**Tech Stack:** Flutter, Riverpod, Nostr.

---

### Phase 1: Settings Sidebar Cleanup

**Task 1.1: Reorganize Settings Screen**

**Files:**
-   Modify: `mobile/lib/screens/settings_screen.dart`

**Step 1: Expose Developer Options**
*   Remove `if (isDeveloperMode)` check around the Developer Options tile.
*   Move tile into the "Network" section (after Blossom settings).

**Step 2: Isolate Danger Zone**
*   Remove "Remove Keys from Device" and "Delete Account" from the "Account" section.
*   Add `_buildSectionHeader('Danger Zone')` at the very bottom of the list (below "Support" section).
*   Add the removed tiles there. Ensure they keep their red/orange iconography.

**Step 3: Verification**
Run: `flutter analyze mobile/lib/screens/settings_screen.dart`

**Step 4: Commit**
```bash
git add mobile/lib/screens/settings_screen.dart
git commit -m "ux: reorganize settings to expose dev options and isolate danger zone"
```

---

### Phase 2: Moderation UI (Design Specification)

*This phase adapts the Bluesky model ("Stackable Moderation") to Nostr/Divine.*

**Concept:**
User selects *providers* (Labelers). Each provider emits Labels (Kind 1985) or Mute Lists (Kind 10000). The app aggregates these to filter content.

**1. Platform Layer (Divine)**
*   **Status:** Backend service exists.
*   **UI:** "Divine Moderation" toggle in Safety Settings.
*   **Action:** Subscribes to Divine's official labeler pubkey.

**2. Social Layer (Web of Trust)**
*   **Status:** Basic mute list logic exists. Needs expansion.
*   **UI:** "Trust People I Follow" toggle.
*   **Logic:** If >N followed users mute/report an event, apply warning/hide.

**3. Labeler Marketplace (Advanced)**
*   **Status:** Needs implementation.
*   **UI:** "Advanced Labelers" list.
*   **Features:**
    *   **Add Labeler:** Input Npub/NIP-05.
    *   **Subscribe/Unsubscribe:** Managed via `ContentModerationService`.
    *   **Details:** Show name/description fetched from Kind 0 (Metadata).

**4. Filtering Granularity (Content Categories)**
*   **Bluesky:** Adult, Suggestive, Graphic, Spam.
*   **Divine Adaptation:**
    *   Map NIP-1985 labels (`l`) to internal enums.
    *   Examples: `nsfw` -> Adult, `spam` -> Spam, `scam` -> Fraud.
    *   **UI:** "Content Filters" section in Safety Settings (Show/Warn/Hide per category).

**Next Steps for Phase 2:**
1.  Update `ContentModerationService` to manage multiple Labeler subscriptions.
2.  Implement `LabelerSubscriptionScreen`.
3.  Enhance `SafetySettingsScreen` to link to subscription management.
