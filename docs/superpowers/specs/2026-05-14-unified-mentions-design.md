# Unified Mentions Design

## Context

Issue #3129 asks for user mentions in video text overlays so viewers can open the mentioned account. While investigating it, we found the larger gap: mentions need one app-wide pipeline, not separate behavior for comments, video captions, overlays, and profile bios.

Today, comments already have autocomplete and selected mentions are converted from `@displayName` to `nostr:npub...` content, but the published kind 1111 comment does not include generic mention `p` tags. Video publishing emits hashtag `t` tags and collaborator-marked `p` tags, but not generic mention tags. Profile bios render Nostr profile references, but the profile editor does not canonicalize typed or selected mentions through the same resolution rules.

## Goals

- Provide one shared mention helper for mention-capable text surfaces.
- Support both selected autocomplete mentions and typed-but-unselected `@name` mentions.
- Resolve selected mentions exactly and resolve typed mentions conservatively.
- Emit generic mention `p` tags for comments and videos, without confusing them with collaborator tags.
- Store profile bio mentions as canonical NIP-27 `nostr:npub...` references in kind 0 content, without adding kind 0 `p` tags.
- Preserve full Nostr IDs in code, logs, tests, and persisted data.

## Non-Goals

- Redesign every text field in the app in one PR.
- Force comments, captions, overlays, and profile bio editing into one shared UI composer abstraction.
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

## KISS Scope Rule

The unified part of this work is the mention behavior, not a framework. Build one small shared helper and keep helper internals private until a real second public abstraction is needed. Each surface should keep its existing text-field state and suggestion UI unless a tiny adapter is enough.

## Architecture

Add one shared mention helper owned by the app layer, because it needs app repositories for profile lookup and app-level publish behavior. Keep it in one file/class unless implementation proves that is awkward.

The helper should expose the smallest API the surfaces need:

1. Resolve text mentions.
   - Accept raw text plus selected mention bindings.
   - Find typed `@name` tokens that were not explicitly selected, using the same token family as linkified text.
   - Exclude email addresses, Nostr IDs, and existing `nostr:npub...` / `nostr:nprofile...` references.
   - Resolve typed tokens through cached profiles first, then remote profile search.
   - Return canonical text, resolved pubkeys, and unresolved tokens.
   - Only resolve a typed token when exactly one plausible profile match exists.

2. Build generic mention tags.
   - Deduplicate full hex pubkeys.
   - Emit generic mention `p` tags.
   - Exclude collaborator pubkeys when asked, so video collaborator tags and generic mention tags do not duplicate each other with different roles.

Token parsing and tag construction can be private functions inside the helper. Do not split them into separate public services or packages in v1.

Selected mention bindings are simple data objects owned by each surface's existing state: display label, original token/range when available, and full hex pubkey or npub. Comments can keep their current `CommentInput` autocomplete flow, and other surfaces can add the same behavior incrementally without depending on one shared widget/controller.

## Surface Integration

### Comments

`CommentsBloc` should stop owning ad hoc `displayName -> npub` conversion logic. It should keep the current comment autocomplete UI, pass selected mention bindings into the shared resolver, then use the resolver output before optimistic insertion and before calling `CommentsRepository.postComment`.

`CommentsRepository.postComment` should accept `mentionedPubkeys`. It should append generic mention `p` tags after the required NIP-22 root/parent `p` tags, deduping against root and parent author tags. This avoids redundant tags while still notifying extra mentioned accounts.

### Video Caption And Description

`VideoMetadataFormFields` should keep its existing text-field structure for v1. It can add autocomplete through a small local adapter if that is straightforward; otherwise typed mentions are resolved at publish time. The editor state and `DivineVideoDraft` should persist selected mention bindings or resolved mention pubkeys only when autocomplete is added, so autosave/draft restore does not lose them.

`VideoPublishService` and `VideoEventPublisher` should accept mentioned pubkeys and append generic mention `p` tags in the kind 34236 publish path. Generic mentions should be kept separate from collaborator `p` tags.

### Video Text Overlays

For #3129 v1, overlay text should feed the same resolver at publish time. Do not embed autocomplete into `pro_image_editor` or add app metadata to `TextLayer` in this pass. Resolving typed overlay text at publish time is enough for published video events to contain generic mention `p` tags without turning this task into an editor integration project.

Overlay mentions should not change the rendered text. Typed unresolved or ambiguous `@name` remains visual text only.

### Profile Bio

Profile setup/edit bio should use the shared mention helper. It can keep its existing editing UI for v1. Resolved mentions should be canonicalized into `nostr:npub...` inside the `about` text before `ProfileRepository.saveProfileEvent`.

Profile bio rendering already uses linkified text. The shared linkification path should display canonical NIP-27 profile references as friendly tappable `@name` labels when profile data is available, with a full npub/hex fallback handled visually by layout.

No `p` tags should be added to profile kind 0 events.

## Typed Mention Resolution

Typed resolution should be conservative:

- Match the same plain mention token family used by linkified text, avoiding email addresses and Nostr IDs.
- Deduplicate tokens before lookup and cap remote lookups to five unique tokens per publish action.
- Search cached candidate profiles first.
- Use API search only when local candidates do not produce a unique result, with a two-second total timeout for the resolution pass.
- Resolve only exact normalized matches on username, display name, npub, or hex pubkey.
- Leave ambiguous or missing matches unchanged.
- Never silently resolve to the current user's own pubkey unless the user selected themselves explicitly.

## Error Handling

Mention resolution failure must not block publishing. If lookup fails, publish the text with selected mentions already canonicalized and skip unresolved typed mention tags.

If tag building receives invalid or empty pubkeys, it should skip them and preserve valid entries. It should not truncate or mask values.

## Testing

Add focused tests for:

- Shared mention helper behavior for selected mentions, typed mention parsing, email exclusion, Nostr reference exclusion, exact typed matches, ambiguous typed matches, lookup failure, self-match handling, dedupe, and invalid pubkey skipping.
- Comment publish events include generic mention `p` tags and preserve NIP-22 root/parent tags.
- Comments bloc passes selected and typed mention pubkeys through to the repository.
- Video publisher emits generic mention tags while preserving collaborator tags with the `collaborator` marker.
- Video drafts preserve caption mention data through autosave/restore only if caption autocomplete is included in the implementation.
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
