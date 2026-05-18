# Home Dropdown Followed Lists Design

## Context

The Home feed currently exposes `For You`, `New`, and `Following` through the feed-mode dropdown. The Figma frames for the refreshed Home surface show the same centered dropdown treatment, but the list-menu variant adds followed list entries beneath the core feed rows. Rabble confirmed the selector should remain a dropdown and approved removing `New` from Home.

Related Figma nodes inspected:

- `5670:54089`: Home video surface with centered dropdown title.
- `5670:52524`: Existing menu state with `For you`, `New`, `Following`.
- `6059:124039`: `Following` video state.
- `7710:10759`: `Following` empty state with "Gloriously empty" and `Go explore`.
- `6059:46365`: Menu state with followed list rows after the core feed rows.

Company/project context supports this direction: prior GitHub history removed `Popular` from Home and defaulted Home to `For You`; recent product review feedback says Home should not keep discovery-style tabs such as `New`.

## Approved Product Shape

Home keeps a centered title dropdown. The dropdown options are:

1. `For you`
2. `Following`
3. One row per followed/subscribed list

`New` is removed from the Home dropdown. New/discovery-style browsing remains outside the Home mode selector.

## Feed Semantics

`For you` continues to use the recommendation feed.

`Following` shows videos from followed creators only. It should no longer silently merge videos from followed lists, because followed lists now have explicit dropdown rows.

Each followed list row shows videos from that specific list. The selected title becomes the list name. If a list has no playable videos, the screen uses the refreshed empty-state pattern rather than falling back to unrelated content.

If a user has persisted `New` as the selected Home mode, the app migrates that saved value to `For you` on restore.

## UI Details

The header keeps the Figma-style centered dropdown label with a caret. It uses existing `VineTheme`, `DivineIcon`, and bottom-sheet components rather than one-off raw colors or custom icon drawing.

The dropdown remains a bottom sheet selection menu. Rows keep the current selection checkmark affordance. Dynamic list names must fit narrow devices without changing row height unexpectedly.

The `Following` empty state adopts the Figma copy and action:

- Title: `Gloriously empty`
- Body: `No ads. No AI slop. No one telling you what to watch. Fix that last part yourself.`
- Primary action: `Go explore`

The action routes to Explore using the existing router pattern.

## Architecture

Keep the existing `UI -> BLoC -> Repository` flow.

The feed state uses a typed selection model that can represent either a core mode (`forYou`, `following`) or a specific followed list. This keeps list identity out of the core enum and makes persistence explicit.

The BLoC remains responsible for loading followed lists, deciding which feed source to request, restoring persisted selection, and refreshing the current feed when follows or followed-list subscriptions change. UI widgets should render options from state and dispatch selection events; they should not fetch videos directly.

## Testing

Update focused widget and BLoC tests to cover:

- The Home dropdown no longer shows `New`.
- `For you` and `Following` still appear.
- Followed list rows appear after the core rows.
- Selecting `Following` fetches followed creators only.
- Selecting a followed list fetches that list's videos only.
- Persisted `latest`/`New` values restore to `For you`.
- The refreshed empty state and `Go explore` action render for empty `Following`.

Run the smallest relevant tests first, then broaden to `flutter analyze` and any affected golden/l10n checks if the implementation touches localized copy or visual goldens.
