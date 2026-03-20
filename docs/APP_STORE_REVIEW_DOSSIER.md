# App Store Review Dossier

Status: Launch-critical
Validated against: `mobile/lib/screens/auth/welcome_screen.dart`, current settings/support screens, `mobile/ios/Runner/Info.plist`, Android manifest, and launch docs on 2026-03-19.

Use this document when preparing App Store reviewer notes and internal release sign-off for P1.

## App Identity

- App name: `Divine`
- iOS bundle identifier: `co.openvine.app`
- Android application ID: `co.openvine.app`
- Version source: `mobile/pubspec.yaml`
- URL scheme: `divine://`

## Reviewer Walkthrough

1. Launch the app and complete the welcome flow.
2. Open the legal links for Terms, Privacy, and Safety from the welcome screen.
3. Open Settings.
4. Visit:
   - Support Center
   - Content Preferences
   - Moderation Controls
   - Nostr Settings
5. Verify that reporting, moderation controls, and policy/support links are visible without hidden gestures.

## User-Generated Content Safeguards

- Content reporting is exposed in-app and backed by current moderation flows.
- Block and mute controls are exposed through the moderation and profile flows.
- Safety configuration is visible under `Safety & Privacy`.
- Support Center links to Safety Standards and policy pages.

Reference docs:

- [mobile/docs/APPLE_REVIEW_RESPONSE.md](../mobile/docs/APPLE_REVIEW_RESPONSE.md)
- [mobile/docs/ENCRYPTION_EXPORT_COMPLIANCE.md](../mobile/docs/ENCRYPTION_EXPORT_COMPLIANCE.md)

## Permissions And Privacy Notes

iOS currently declares:

- Camera
- Microphone
- Photo library read/write
- Bluetooth usage descriptions
- Bonjour service discovery
- Location usage descriptions

Android currently declares:

- Internet and network state
- Camera and microphone
- Photo/media read permissions
- Legacy write permission for gallery save on older Android versions

The Android manifest explicitly removes Advertising ID and unused location/Bluetooth permissions added by dependencies.

## Encryption Export Notes

- `ITSAppUsesNonExemptEncryption` is set to `false`.
- Export rationale and cryptography inventory live in [mobile/docs/ENCRYPTION_EXPORT_COMPLIANCE.md](../mobile/docs/ENCRYPTION_EXPORT_COMPLIANCE.md).

## External Pages To Verify Before Submission

- `https://divine.video/terms`
- `https://divine.video/privacy`
- `https://divine.video/safety`
- `https://divine.video/faq`
- `https://divine.video/proofmode`

## Submission Packet Checklist

- [ ] Reviewer notes summarize where moderation/reporting lives.
- [ ] Support email and policy/support URLs are current.
- [ ] Screenshots reflect the current Settings and Support Center flows.
- [ ] Privacy answers match the current permissions in iOS and Android manifests.
- [ ] Export compliance answers match the iOS plist and compliance doc.
- [ ] Any unavailable or staged features are called out explicitly in reviewer notes.
