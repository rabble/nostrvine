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
the crossposter error envelope. The repository fetches platforms,
connections, and preferences and joins them into enabled per-platform entries.
The Cubit owns loading state, action state, optimistic mode updates, refreshes,
and UI-safe error categories. The screen owns rendering, localized copy,
navigation, browser launch wiring, and lifecycle observation.

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

## OAuth and Refresh Flow

1. The Cubit asks the repository to start a connection with
   `https://divine.video/app/callback` as the return URL.
2. The server returns an authorization URL, which the app opens externally.
   `url_launcher` uses the native system-browser surface (Custom Tabs on
   Android and the appropriate external browser/authentication surface on iOS).
3. The provider and crossposter complete OAuth server-side.
4. The app refreshes connections and preferences whenever it resumes.
5. If the claimed universal link returns to the app with
   `connection=connected|failed`, the app routes to Crossposting settings,
   refreshes, and shows localized success/denial/failure feedback.

The callback parser only recognizes the expected Divine HTTPS host/path and
the `connection` discriminator, so the existing Keycast callback using the same
path is not intercepted.

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
- Deep-link/router tests: callback recognition without stealing Keycast OAuth.
- Run localization consistency, targeted Flutter tests, formatting, generated
  code checks, `flutter analyze`, and relevant golden verification if the final
  UI changes a covered golden.

## Out of Scope

- Per-video manual crossposting controls.
- Publishing videos from the app to provider APIs.
- Provider credentials or OAuth token storage in the app.
- Showing disabled/staged platforms.
- Changes to the crossposter Worker API.
