# Crossposting Settings Design

## Goal

Add a settings screen where signed-in creators can connect enabled external
platforms to Divine's crossposter service and choose an Off, Manual, or
Automatic posting mode per connected platform.

## Scope

- Fetch platform availability from `https://crossposter.divine.video` and show
  only platforms whose API response has `enabled: true`.
- Show connection state and external account name when available.
- Support Connect, Reconnect for `needs_reauth`, and Disconnect.
- Support Off (`disabled`), Manual, and Automatic modes. Hide Automatic when
  the platform reports `supportsAutomatic: false`.
- Open provider authorization in the system browser and refresh after the app
  resumes or receives the OAuth return universal link.
- Reuse the existing Divine/Keycast bearer session. There is no new app login
  flow and no provider OAuth handling inside the app.

## Architecture

Use the repository's preferred layered flow:

`CrosspostingSettingsScreen -> CrosspostingSettingsCubit -> CrosspostingRepository -> CrosspostingApiClient`

The API client owns HTTP, bearer-token retrieval, JSON parsing, timeouts, and
the crossposter error envelope. The repository fetches platforms, connections,
and preferences sequentially and joins them into enabled per-platform entries.
Sequential reads avoid racing Keycast's rotating refresh token across
concurrent authenticated calls.
The Cubit owns loading state, action state, optimistic mode updates, refreshes,
OAuth callback validation, and UI-safe outcomes/errors. The screen owns
rendering, localized copy, navigation, the native OAuth launcher wiring, and
lifecycle observation.

Dependencies are constructor-injected. Riverpod may wire existing auth-sensitive
dependencies at the Page boundary, but it does not own feature UI state.

## Screen Design

Add Crossposting under the Integrations section of General Settings. The screen
uses a compact, scannable row for each enabled platform:

- Platform name and connection/account state remain visible.
- The row exposes Connect, Reconnect, or Disconnect as appropriate.
- Connected rows expose a compact Off/Manual/Automatic selector.
- The selected non-Off mode shows its explanation beneath the selector:
  - Manual: "you choose per video"
  - Automatic: "future videos post automatically — only videos published after
    you turn this on"

Disconnected and `needs_reauth` platforms do not expose mode controls because
the service rejects enabled modes without a connected account.

If the API returns no enabled platforms, the screen shows a short localized
empty state instead of a blank page.

## OAuth and Refresh Flow

1. The Cubit asks the repository to start a connection with
   `https://divine.video/app/callback` as the return URL.
2. The server returns an HTTPS authorization URL. The app passes it to
   `flutter_web_auth_2` with callback scheme `https`, host `divine.video`, and
   path `/app/callback`. This uses `ASWebAuthenticationSession` on iOS and a
   Custom Tab on Android.
3. The provider and crossposter complete OAuth server-side.
4. The native OAuth session returns the callback URL to the existing
   Crossposting screen. The Cubit validates the exact HTTPS host/path and the
   `connection=connected|failed` discriminator, then refreshes connections and
   preferences and emits localized success/denial/failure feedback.
5. The app also refreshes when it resumes, covering a canceled browser session
   and the server-supported fallback where the user closes the browser.

Android registers an exported, auto-verified
`com.linusu.flutter_web_auth_2.CallbackActivity` for only the exact
`https://divine.video/app/callback` shape. iOS uses the existing
`applinks:divine.video` entitlement. Because the callback is captured by the
feature's native OAuth session rather than the global deep-link parser, it does
not intercept or modify Keycast's separate callback handling.

## Errors and State Consistency

- Initial load failure replaces the body with a localized Retry state.
- Browser launch and action failures surface localized snackbars.
- Crossposter errors parse `{error: {code, message}}`; `not_connected` gets
  specific user-facing handling.
- Mode changes update optimistically and roll back if the request fails.
- A disconnect is followed by a full repository refresh so connection and mode
  state stay server-authoritative.
- Refresh failure after resume keeps the last loaded state visible.
- Unknown platforms are ignored by older app builds; unknown connection status
  and mode values degrade safely to disconnected and Off.

## Verification

- API client tests: bearer auth, endpoint paths and bodies, supported-model
  parsing, malformed responses, timeout/non-2xx behavior, and error envelopes.
- Repository tests: parallel fetch/join behavior, enabled filtering,
  connection/preference association, and platform capability handling.
- Cubit tests: load/refresh, connect/reconnect, disconnect, mode success,
  optimistic rollback, and action errors.
- Widget tests: signed-out state, compact enabled-platform rows, account and
  reauth states, mode copy/capabilities, actions, and callback feedback.
- OAuth launcher tests: HTTPS callback options and cancellation behavior.
- Cubit callback tests: accept only the exact HTTPS host/path and supported
  callback values, then refresh server state.
- Native configuration guard: Android callback activity declares only
  `https://divine.video/app/callback`.
- Route-context tests: `/crossposting-settings` is modeled as its own settings
  route rather than falling back to home.
- Run localization consistency, targeted Flutter tests, formatting, generated
  code checks, `flutter analyze`, and relevant golden verification if the final
  UI changes a covered golden.

## Out of Scope

- Per-video manual crossposting controls.
- Publishing videos from the app to provider APIs.
- Provider credentials or OAuth token storage in the app.
- Showing disabled/staged platforms.
- Changes to the crossposter Worker API.
