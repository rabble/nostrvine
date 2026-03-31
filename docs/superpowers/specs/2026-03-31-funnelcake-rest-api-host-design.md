# Funnelcake REST API Host Design

**Date:** 2026-03-31
**Status:** Approved

## Goal

Route Funnelcake REST requests to `https://api.divine.video` while keeping
websocket and Nostr traffic on `wss://relay.divine.video`.

## Current Behavior

- Production `EnvironmentConfig.apiBaseUrl` derives directly from
  `relayUrl`, which currently produces `https://relay.divine.video`.
- Funnelcake REST providers also resolve a base URL from configured relay URLs
  through `relay_url_utils.dart`.
- When the active relay list includes `wss://relay.divine.video`, Funnelcake
  REST traffic continues to use the relay host instead of the new Fastly-backed
  API host.

## Chosen Approach

Keep the relay websocket host unchanged and make the REST host explicit only
where Funnelcake base URLs are resolved.

- Change production `EnvironmentConfig.apiBaseUrl` to return
  `https://api.divine.video`.
- Update the Funnelcake relay-to-HTTP helper so
  `wss://relay.divine.video` resolves to `https://api.divine.video`.
- Leave generic websocket relay URLs untouched so Nostr traffic keeps using
  `wss://relay.divine.video`.

## Why This Approach

- It fixes both code paths that currently choose the REST base URL.
- It avoids broad host rewriting for unrelated websocket behavior.
- It keeps staging, test, local, and relay notification behavior aligned with
  their existing hosts.

## Testing

- Update environment config tests to assert production REST traffic uses
  `https://api.divine.video`.
- Add focused URL resolution tests for the Funnelcake helper so divine relay
  URLs map to the API host while non-divine relays still derive normally.
- Re-run the existing provider tests that exercise Funnelcake availability and
  relay notification base URL selection.
