# Settings Information Architecture

Status: Current
Validated against: the current settings hub, support, Nostr settings, and safety/privacy screens on 2026-03-19.

This document describes the current settings structure after the monolithic settings screen was split into focused sub-screens.

## Settings Hub

Route:

- `SettingsScreen.path = /settings`

Primary destinations from the hub:

- `Creator Analytics`
- `Support Center`
- `Notifications`
- `Content Preferences`
- `Moderation Controls`
- `Nostr Settings`

Authenticated users also see an account header and any account-state prompts such as session-expired recovery or secure-account reminders.

## Sub-Screens

### Support Center

- bug reporting
- log export
- support message history
- links to FAQ, ProofMode, Privacy Policy, and Safety Standards

### Content Preferences

- language preference
- content filters
- audio reuse preference
- macOS-only audio device selection

### Moderation Controls (`Safety & Privacy`)

- age verification gate
- Divine-hosted-only filter
- moderation provider toggles
- blocked-user management

### Nostr Settings

- relays
- relay diagnostics
- Blossom media servers
- developer options when developer mode is enabled
- key management and danger-zone actions for authenticated users

## What Changed

The old monolithic settings implementation no longer exists. Current docs and implementation should reference the split structure under `mobile/lib/screens/settings/` plus the dedicated `Safety & Privacy` screen.
