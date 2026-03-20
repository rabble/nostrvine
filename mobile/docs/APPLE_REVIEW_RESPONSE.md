# Apple Review Response Reference

Status: Launch-critical
Validated against: current settings/support flows, `mobile/ios/Runner/Info.plist`, and launch docs on 2026-03-19.

This document captures the current reviewer-response posture for Divine. It is not a transcript to paste blindly into App Store Connect; it is the maintained source used to prepare reviewer notes and follow-up responses.

## App Identity

- App name: `Divine`
- Bundle identifier: `co.openvine.app`
- Current legal/support links:
  - `https://divine.video/terms`
  - `https://divine.video/privacy`
  - `https://divine.video/safety`
  - `https://divine.video/faq`
  - `https://divine.video/proofmode`

## Current Reviewer Talking Points

### 1. User-Generated Content Safeguards

Divine includes visible, in-app safeguards for user-generated content:

- users can report content
- users can block and mute abusive accounts
- users can manage moderation providers and safety preferences under `Safety & Privacy`
- policy and safety links are reachable from the welcome flow and Support Center

Primary in-app surfaces:

- `Settings -> Support Center`
- `Settings -> Moderation Controls`

### 2. Support And Escalation

The Support Center gives reviewers a visible route to:

- contact support or report a bug
- export logs
- view support messages when Zendesk is configured
- open FAQ, ProofMode, Privacy Policy, and Safety Standards

### 3. Permissions Clarification

Current iOS permission strings cover:

- camera
- microphone
- photo library access
- Bluetooth usage descriptions
- Bonjour service discovery
- location usage descriptions

These must stay aligned with the actual app behavior and the submission answers in App Store Connect.

### 4. Export Compliance

Divine sets `ITSAppUsesNonExemptEncryption` to `false`.

Reference:

- [mobile/docs/ENCRYPTION_EXPORT_COMPLIANCE.md](/Users/lizsw/divine-mobile/mobile/docs/ENCRYPTION_EXPORT_COMPLIANCE.md)

## Reviewer Notes Template Inputs

Use these facts when writing reviewer notes:

- where moderation/reporting/blocking live in the UI
- where legal/policy pages are linked in the app
- any staged or disabled features that could confuse review
- support contacts and escalation routes

## Do Not Use

Do not reuse older wording that references removed screens, old domains, or unsupported background modes without rechecking current code first.
