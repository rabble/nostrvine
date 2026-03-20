# Zendesk Support Integration

Status: Current
Validated against: `mobile/lib/services/zendesk_support_service.dart` and `mobile/lib/screens/settings/support_center_screen.dart` on 2026-03-19.

Divine integrates Zendesk Support to provide native support-message flows when credentials are configured. The app keeps working without Zendesk by falling back to in-app bug reporting and exportable logs.

## User Entry Point

Users reach support from:

- `Settings -> Support Center`

Current Support Center actions:

- contact support / report a bug
- save logs
- view support messages
- open FAQ
- open ProofMode information
- open Privacy Policy
- open Safety Standards

## Integration Shape

```
Support Center
  -> BugReportService for local bug report flows and log export
  -> ZendeskSupportService for native ticket UI and ticket history
  -> external policy/support URLs on divine.video
```

## Current Service Behavior

`ZendeskSupportService`:

- initializes from dart defines at app startup
- stores user identity details locally
- can set anonymous identity for unauthenticated users
- upgrades to JWT identity by fetching a pre-auth token through the relay-manager API
- opens the native ticket composer and ticket list when the SDK is available

If Zendesk is unavailable:

- the Support Center still supports bug reporting and log export
- ticket history is unavailable

## Configuration

Common dart defines:

- `ZENDESK_APP_ID`
- `ZENDESK_CLIENT_ID`
- `ZENDESK_URL`
- `ZENDESK_API_TOKEN`

The mobile build scripts read these from `.env` when present.

## Current Files

- `mobile/lib/services/zendesk_support_service.dart`
- `mobile/lib/screens/settings/support_center_screen.dart`
- `mobile/lib/config/zendesk_config.dart`
- native platform handlers in the iOS and Android app targets

## Notes For Launch

- Make sure Support Center copy and screenshots match the current UI, not the older drawer-based flows.
- Re-validate support contacts and external policy links before store submission.
