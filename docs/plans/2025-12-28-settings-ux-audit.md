# Settings Menu UX Analysis & Improvement Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (or subagent-driven-development) to implement this plan task-by-task.

**Goal:** Analyze the current settings menu organization/UX and implement targeted improvements to fix incomplete sections and improve logical grouping.

**Architecture:**
The app uses a unified `SettingsScreen` as the hub, linking to sub-screens (`SafetySettingsScreen`, `RelaySettingsScreen`, etc.). We will refine this hierarchy and clean up "Coming Soon" placeholders.

**Tech Stack:** Flutter, GoRouter, Riverpod.

---

### Analysis: Current State

**1. Hierarchy Structure**
-   **Profile:** Edit Profile, Key Management
-   **Account:** Log Out, Remove Keys, Delete Account
-   **Network:** Relays, Diagnostics, Media Servers
-   **Preferences:** Notifications, Safety & Privacy
-   **About:** Version (Dev mode trigger)
-   **Support:** ProofMode, Contact, Logs

**2. UX Issues Identified**
-   **`SafetySettingsScreen` has dead UI:** "Blocked Users", "Muted Content", and "Report History" are displayed as section headers with *no content* underneath. "People I follow" and "Custom labelers" are visible but are just non-functional placeholders ("Coming soon" snackbars). This creates a broken user experience.
-   **"Actions" in Notifications:** The `NotificationSettingsScreen` mixes configuration (toggles) with one-off actions (Mark all read). While functional, these actions might be better placed in the AppBar or a distinct "Data" section to separate configuration from operation.
-   **Redundant/Split Auth Sections:** "Profile" and "Account" are separate. Key Management is under "Profile" but technically is an account/security function.

---

### Task 1: Clean up Safety Settings Screen

**Files:**
-   Modify: `mobile/lib/screens/safety_settings_screen.dart`

**Step 1: Hide "Coming Soon" / Empty Sections**
Modify `build` method.
-   Current state: Shows headers for Blocked/Muted/Report History with no content.
-   Action: Comment out or wrap these headers in a visibility check (`if (false)`) until implemented. It is better to hide them than show broken UI.
-   Action: Convert "People I follow" and "Custom labelers" into specific "Coming Soon" disabled tiles or hide them to reduce clutter. Recommend hiding them for production readiness.

**Step 2: Run generic settings test (if any) or verify manual compile**
Run: `flutter analyze mobile/lib/screens/safety_settings_screen.dart`

**Step 3: Commit**
```bash
git add mobile/lib/screens/safety_settings_screen.dart
git commit -m "ux: hide unimplemented safety settings (blocked/muted lists) to avoid broken UI"
```

### Task 2: Polish Settings Main Hub

**Files:**
-   Modify: `mobile/lib/screens/settings_screen.dart`

**Step 1: Consolidate Profile/Account (Optional but recommended)**
*Current:*
- Profile: Edit, Keys
- Account: Logout, Remove, Delete
*Proposal behavior:* Keep them separate for now as "Account" implies "Session/Data" actions vs "Profile" (Public Identity).
*Action:* Add clearer subtitles or icons if possible. (Skipping major structural change to avoid router breakage, sticking to polish).

**Step 2: Add "App Info" functionality**
The "Version" tile taps 7 times for dev mode.
*Action:* Add a subtitle to "Version" explicitly stating build number (it does this already: `${packageInfo.version}+${packageInfo.buildNumber}`).
*Refinement:* Ensure the "Support" section is clearly distinct.

**Step 3: Verify Router paths**
Ensure all `context.push` paths exist in router. (Visual check or simple test).

**Step 4: Commit**
```bash
git commit --allow-empty -m "chore: verified settings hub integrity"
```

### Task 3: Refine Notification Settings Actions

**Files:**
-   Modify: `mobile/lib/screens/notification_settings_screen.dart`

**Step 1: Move Actions to AppBar or Bottom**
The "Actions" section (Mark All Read, Clear Old) is aggressive in the middle of lists.
*Action:* Move "Actions" section to the very bottom of the list, after "Push Notifications" and "Info". This effectively separates "Configuration" (top) from "Maintenance" (bottom).

**Step 2: Verify compile**
Run: `flutter analyze mobile/lib/screens/notification_settings_screen.dart`

**Step 3: Commit**
```bash
git add mobile/lib/screens/notification_settings_screen.dart
git commit -m "ux: move notification maintenance actions to bottom of screen"
```

---

### Execution

**Recommended Approach:** Subagent-driven to quickly apply the Safety Settings cleanup (Task 1) and Notification reordering (Task 3).
