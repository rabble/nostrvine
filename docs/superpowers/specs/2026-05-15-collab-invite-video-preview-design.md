# Collaborator Invite Video Preview Design

## Goal

Make collaborator invites understandable at the moment of decision. A recipient
should be able to see the invited video and understand that accepting will
co-post that video to their own timeline as a collaboration.

The current card exposes the mechanics of an invite but hides the object being
accepted. That makes "Accept" ambiguous and pushes users to decide from title
text alone, often "Untitled video".

## Decision

Use an inline video preview card in the DM thread and message-request preview.
The video preview is the primary visual element, with the collaboration decision
attached directly below it.

Approved direction: **Inline Video Card**.

## Product Semantics

This is a collaboration, not a repost. The card copy must describe the action
as co-posting the creator's video as a collaboration:

- Primary action: `Co-post`
- Secondary action: `Not mine`
- Context line: `Co-post invite from @displayName`
- Consequence line: `Co-posting adds this video to your timeline as a collaboration.`

The exact display name should use the best available sender/profile name from
the surrounding conversation context. If the card cannot resolve a name, it may
fall back to the existing generic invite label, but it must not truncate Nostr
IDs in logs, tests, or debug output.

## UX Shape

The recipient-side card contains:

1. A large portrait thumbnail/preview area when
   `CollaboratorInvite.thumbnailUrl` is present. Use a stable aspect ratio
   close to the existing video-card proportions so the card does not resize
   after image load.
2. A play affordance over the thumbnail. Tapping the preview opens the existing
   video detail route so the user can watch the video before deciding.
3. Overlay text on the preview: invite context, video title, and the consequence
   line.
4. Inline actions below the preview: `Co-post` and `Not mine`.
5. Existing status states after action: accepted, ignored, accepting, failed.

If `thumbnailUrl` is missing, the card must keep a compact fallback that still
shows the title or "Untitled video", the consequence line, and the same action
labels. Missing thumbnails must not block invite handling.

Sender-side cards remain static. They should not expose recipient actions.

## Architecture

Keep the change in the existing collaborator invite surface:

- `CollaboratorInviteParser` remains the source for structured invite metadata.
- `CollaboratorInviteCard` remains the reusable widget for conversation and
  message-request surfaces.
- `CollaboratorInviteActionsCubit` remains the owner of accept/ignore local
  state.
- `CollaboratorResponseService` remains the publish path for accepting.
- `VideoDetailScreen.pathForId(invite.videoAddress)` remains the review route.

No new flow, modal, or full-screen review gate is needed. Inline acceptance is
allowed because the card itself provides enough video context and still supports
tap-through review.

## Data Flow

1. NIP-17 DM arrives with structured collaborator invite tags.
2. `CollaboratorInviteParser.parse` extracts `title`, `thumbnailUrl`,
   `videoAddress`, `creatorPubkey`, `role`, and relay metadata.
3. Conversation and request-preview surfaces render `CollaboratorInviteCard`.
4. The card renders thumbnail-first UI when `thumbnailUrl` is non-empty.
5. `Co-post` calls the existing accept action.
6. `Not mine` calls the existing ignore action.
7. Accepted/ignored/failed states render in place.

## Error Handling And Fallbacks

- Thumbnail loading failure: show the non-thumbnail card content and keep the
  actions available.
- Missing title: show the existing localized "Untitled video" fallback.
- Accept failure: preserve the current failed state and retry affordance.
- Accept in progress: disable both actions and show loading on the primary
  action as the current card does.
- Sender-side invite: show sent/static state, no `Co-post` or `Not mine`.

## Copy And Localization

Add or update localized strings for the new English source copy, then regenerate
localizations as the repo normally requires:

- `Co-post`
- `Not mine`
- `Co-post invite`
- `Co-post invite from {name}`
- `Co-posting adds this video to your timeline as a collaboration.`

Existing translations may initially mirror English where the repo's current l10n
workflow does that, but generated localization outputs must be committed if
source ARB changes require it.

## Testing

Focused tests should cover:

- Recipient card renders a large thumbnail preview when invite tags include
  `thumb`.
- Recipient card falls back cleanly when `thumb` is absent.
- Primary action still calls `acceptInvite`.
- Secondary action still calls `ignoreInvite`.
- Sender-side card does not render recipient actions.
- Message-request preview reuses the same card behavior.
- Tapping the preview/card still opens the video detail route.

Widget tests should assert user-visible behavior rather than internal layout
details, but they should verify that the thumbnail path is present in the widget
tree when available.

## Out Of Scope

- New protocol tags.
- A full-screen mandatory review gate.
- Playback inside the card beyond a thumbnail/play affordance.
- Changes to collaborator acceptance semantics.
- Feed/profile read-model changes.
