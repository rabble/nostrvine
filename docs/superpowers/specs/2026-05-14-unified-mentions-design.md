# Unified Mentions Design

## Context

Issue #3129 asks for user mentions in video text overlays so viewers can open the mentioned account. While investigating it, we found the larger gap: mentions need one app-wide pipeline, not separate behavior for comments, video captions, overlays, and profile bios.

Today, comments already have autocomplete and selected mentions are converted from `@displayName` to `nostr:npub...` content, but the published kind 1111 comment does not include generic mention `p` tags. Video publishing emits hashtag `t` tags and collaborator-marked `p` tags, but not generic mention tags. Profile bios render Nostr profile references, but the profile editor does not use a shared mention composer.

## Goals

- Provide one shared mention model, composer, resolver, and tag builder for mention-capable text surfaces.
- Support both selected autocomplete mentions and typed-but-unselected `@name` mentions.
- Resolve selected mentions exactly and resolve typed mentions conservatively.
- Emit generic mention `p` tags for comments and videos, without confusing them with collaborator tags.
- Store profile bio mentions as canonical NIP-27 `nostr:npub...` references in kind 0 content, without adding kind 0 `p` tags.
- Preserve full Nostr IDs in code, logs, tests, and persisted data.

## Non-Goals

- Redesign every text field in the app in one PR.
- Add `p` tags to kind 0 profile metadata events.
- Invent new Nostr tag semantics.
- Treat unresolved or ambiguous `@name` text as a mention.
- Change collaborator invite or confirmation semantics.

## Protocol Rules

Comments and video posts should include generic mention tags for resolved accounts:

```json
["p", "<64-char-pubkey>", "wss://relay.divine.video", "mention"]
```

Collaborators remain role-marked and distinct:

```json
["p", "<64-char-pubkey>", "wss://relay.divine.video", "collaborator"]
```

Profile bios should canonicalize resolved mentions inside the `about` field:

```text
nostr:npub1...
```

Kind 0 profile events should keep their current empty tag list unless another profile-specific protocol requirement is introduced later.

## Architecture

Add a shared mention module owned by the app layer, because it needs app repositories for profile lookup and UI-friendly composer state. The module has three pieces:

1. `MentionComposer`
   - Tracks the active `@` query, selected mention bindings, and suggestion list.
   - Replaces selected text with the display label shown to the user.
   - Can be embedded by comments, video metadata description, and profile bio editing.

2. `MentionResolver`
   - Accepts raw text plus selected bindings.
   - Finds typed `@name` tokens that were not explicitly selected.
   - Resolves typed tokens through cached profiles first, then remote profile search.
   - Returns canonical text, resolved pubkeys, and unresolved tokens.
   - Only resolves a typed token when exactly one plausible profile match exists.

3. `MentionTagBuilder`
   - Deduplicates full hex pubkeys.
   - Emits generic mention `p` tags.
   - Excludes collaborator pubkeys when asked, so video collaborator tags and generic mention tags do not duplicate each other with different roles.

## Surface Integration

### Comments

`CommentsBloc` should stop owning ad hoc `displayName -> npub` conversion logic. It should use the shared resolver before optimistic insertion and before calling `CommentsRepository.postComment`.

`CommentsRepository.postComment` should accept `mentionedPubkeys`. It should append generic mention `p` tags after the required NIP-22 root/parent `p` tags, deduping against root and parent author tags. This avoids redundant tags while still notifying extra mentioned accounts.

### Video Caption And Description

`VideoMetadataFormFields` should use the shared composer for the description/caption field. The editor state and `DivineVideoDraft` should persist selected mention bindings or resolved mention pubkeys so autosave/draft restore does not lose them.

`VideoPublishService` and `VideoEventPublisher` should accept mentioned pubkeys and append generic mention `p` tags in the kind 34236 publish path. Generic mentions should be kept separate from collaborator `p` tags.

### Video Text Overlays

For #3129, overlay text should feed the same resolver. If embedding the composer into `pro_image_editor` is clean, the text editor should offer autocomplete and store selected bindings alongside the layer metadata. If the underlying `TextLayer` cannot carry extra app metadata cleanly, v1 should still resolve typed overlay text at publish time through the shared resolver so published video events contain generic mention `p` tags.

Overlay mentions should not change the rendered text unless the user selected a suggestion. Typed unresolved `@name` remains visual text only.

### Profile Bio

Profile setup/edit bio should use the same mention composer and resolver. Resolved mentions should be canonicalized into `nostr:npub...` inside the `about` text before `ProfileRepository.saveProfileEvent`.

Profile bio rendering already uses linkified text. The shared linkification path should display canonical NIP-27 profile references as friendly tappable `@name` labels when profile data is available, with a full npub/hex fallback handled visually by layout.

No `p` tags should be added to profile kind 0 events.

## Typed Mention Resolution

Typed resolution should be conservative:

- Match the same plain mention token family used by linkified text, avoiding email addresses and Nostr IDs.
- Search cached candidate profiles first.
- Use API search only when local candidates do not produce a unique result.
- Resolve only exact normalized matches first, then a single high-confidence unique match.
- Leave ambiguous or missing matches unchanged.
- Never silently resolve to the current user's own pubkey unless the user selected themselves explicitly.

## Error Handling

Mention resolution failure must not block publishing. If lookup fails, publish the text with selected mentions already canonicalized and skip unresolved typed mention tags.

If tag building receives invalid or empty pubkeys, it should skip them and preserve valid entries. It should not truncate or mask values.

## Testing

Add focused tests for:

- Mention token parsing, email exclusion, Nostr reference exclusion, dedupe, and invalid pubkey skipping.
- Resolver behavior for selected mentions, exact typed matches, ambiguous typed matches, lookup failure, and self-match handling.
- Comment publish events include generic mention `p` tags and preserve NIP-22 root/parent tags.
- Comments bloc passes selected and typed mention pubkeys through to the repository.
- Video publisher emits generic mention tags while preserving collaborator tags with the `collaborator` marker.
- Video drafts preserve caption mention data through autosave/restore.
- Profile save canonicalizes resolved bio mentions into `nostr:npub...` content and does not add kind 0 tags.
- Linkified profile bio renders canonical profile references as tappable account links.

## Verification

Run targeted tests first:

```bash
cd mobile
flutter test test/blocs/comments/comments_bloc_test.dart
flutter test packages/comments_repository/test/src/comments_repository_test.dart
flutter test test/services/video_event_publisher_test.dart test/services/video_event_publisher_collaborator_tags_test.dart
flutter test test/providers/video_editor_provider_test.dart test/widgets/video_metadata/video_metadata_form_fields_test.dart
flutter test packages/profile_repository/test/src/profile_repository_test.dart test/widgets/profile/profile_header_widget_test.dart
```

Then run:

```bash
cd mobile
flutter analyze
```

Run broader widget/golden checks only if UI layout changes are substantial.
